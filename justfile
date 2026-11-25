set shell := ["bash", "-euo", "pipefail", "-c"]

xcode_base := "-project Capsaicin.xcodeproj -scheme Capsaicin -sdk macosx -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/xcode -clonedSourcePackagesDirPath .build/spm"
xcode_args := xcode_base + " -configuration Debug"
version := `sed -n 's/^ *MARKETING_VERSION: "\(.*\)"$/\1/p' project.yml`
debug_app := justfile_directory() / ".build/xcode/Build/Products/Debug/Capsaicin.app"

default:
    @just --list

gen:
    xcodegen generate --spec project.yml

build: gen
    /usr/bin/xcodebuild {{ xcode_args }} build

# Re-sign the Debug app with a key in the owner's keychain so it can use the helper (agents need owner approval).
[positional-arguments]
sign-debug identity="Developer ID Application":
    #!/usr/bin/env bash
    set -euo pipefail
    identity="$1"
    app='{{ debug_app }}'
    [[ -d "$app" ]] || { echo 'Debug app is missing. Run just build first.' >&2; exit 1; }
    sign=(/usr/bin/codesign --force --timestamp=none --preserve-metadata=identifier,entitlements,flags --sign "$identity")
    # シンボリックリンクはたどらず、内側の Mach-O を先に、入れ物のバンドルを後に署名する。
    while IFS= read -r -d '' path; do
        if [[ -f "$path" ]]; then
            [[ "$(/usr/bin/file -b "$path")" == *Mach-O* ]] || continue
        else
            case "$path" in
                *.framework|*.xpc|*.app|*.bundle) ;;
                *) continue ;;
            esac
        fi
        printf 'Signing: %s\n' "$path"
        "${sign[@]}" "$path"
    done < <(/usr/bin/find "$app/Contents" -depth \( -type f -o -type d \) -print0)
    "${sign[@]}" "$app"
    /usr/bin/codesign --verify --strict --deep "$app"
    /usr/bin/codesign -dvv "$app" 2>&1 | /usr/bin/awk '/^(Identifier|TeamIdentifier)=/ || (/^Authority=/ && !seen++)'

build-release: gen
    /usr/bin/xcodebuild {{ xcode_base }} -configuration Release build

# Build a Debug app for checks without extra dylibs, and zip it with the PR number and commit in the name for the signing job.
[positional-arguments]
dist-debug pr sha: gen
    #!/usr/bin/env bash
    set -euo pipefail
    pr="$1"
    sha="$2"
    [[ "$pr" =~ ^[0-9]+$ && "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid PR number or commit SHA' >&2; exit 1; }
    # 更新の後の登録し直しを確かめられるよう、確認用のビルドごとに増える版番号を付ける。Debug は配信先を持たない。
    build="$(date -u +%Y%m%d%H%M%S)"
    /usr/bin/xcodebuild {{ xcode_args }} ENABLE_DEBUG_DYLIB=NO ENABLE_PREVIEWS=NO CURRENT_PROJECT_VERSION="$build" build
    if find '{{ debug_app }}' -type f \( -name '*.debug.dylib' -o -name '__preview.dylib' \) -print | grep -q .; then
        echo 'Unexpected Debug or preview dylib in the app' >&2
        exit 1
    fi
    mkdir -p .build/debug-dist
    zip_name="Capsaicin-debug-pr${pr}-${sha:0:7}.zip"
    ditto -c -k --norsrc --noextattr --noacl --keepParent '{{ debug_app }}' ".build/debug-dist/$zip_name"
    '{{ just_executable() }}' dmg-layout '{{ debug_app }}' .build/debug-dist/Capsaicin-layout.dmg
    (cd .build/debug-dist && shasum -a 256 "$zip_name" Capsaicin-layout.dmg > SHA256SUMS.txt)

# Create an ad-hoc signed zip, a layout DMG, and SHA-256 checksums in .build/dist/ for the signing job, which makes the DMG.
dist: build-release
    mkdir -p .build/dist
    # Exclude extended attributes and resource forks; ad-hoc signatures are in the executables.
    ditto -c -k --norsrc --noextattr --noacl --keepParent .build/xcode/Build/Products/Release/Capsaicin.app .build/dist/Capsaicin-{{ version }}.zip
    '{{ just_executable() }}' dmg-layout .build/xcode/Build/Products/Release/Capsaicin.app .build/dist/Capsaicin-layout.dmg
    cd .build/dist && shasum -a 256 Capsaicin-{{ version }}.zip Capsaicin-layout.dmg > SHA256SUMS.txt

# Create a DMG that sets only the window layout and background; the signing job swaps in the signed app.
[private]
dmg-layout app out:
    mkdir -p .build/dmg
    /usr/bin/xcrun --sdk macosx swift scripts/dmg/background.swift .build/dmg .github/assets/capsaicin-icon.png
    dmgbuild -s scripts/dmg/settings.py -D app={{ quote(app) }} -D background=.build/dmg/background.png Capsaicin {{ quote(out) }}

prepare-release kind:
    python3 scripts/prepare_release.py {{ kind }}

test: test-scripts test-package test-app

test-scripts:
    mkdir -p .build/tmp
    TMPDIR="$PWD/.build/tmp" PYTHONPYCACHEPREFIX="$PWD/.build/pycache" python3 -m unittest discover -s scripts/tests -v

test-package:
    /usr/bin/xcrun --sdk macosx swift test --package-path Packages/CapsaicinKit --scratch-path .build/swiftpm

test-app: gen
    /usr/bin/xcodebuild {{ xcode_args }} test

fmt:
    treefmt

fmt-check:
    PYTHONPYCACHEPREFIX="$PWD/.build/pycache" python3 scripts/check_format.py

lint-docs:
    PYTHONPYCACHEPREFIX="$PWD/.build/pycache" python3 scripts/check_docs.py

lint-code:
    # Use Xcode's SourceKit instead of Nix's Swift for SwiftLint.
    TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault XCODE_DEFAULT_TOOLCHAIN_OVERRIDE="$(/usr/bin/xcode-select -p)/Toolchains/XcodeDefault.xctoolchain" swiftlint lint --strict --no-cache
    # Skip files ignored by Git, including global ignore rules.
    git ls-files -z --cached --others --exclude-standard -- '*.md' | xargs -0 markdownlint-cli2
    shellcheck --shell=bash .envrc
    find scripts -name '*.sh' -exec shellcheck {} +
    ruff check scripts
    statix check flake.nix
    statix check treefmt.nix
    deadnix --fail flake.nix treefmt.nix

# Check CI's just and XcodeGen versions against flake.lock (DEC-SYS-015).
lint-build-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    source .github/build-tools.env
    [[ "$(just --version)" == "just $JUST_VERSION" ]] || { echo "just: version mismatch between flake.lock and .github/build-tools.env" >&2; exit 1; }
    [[ "$(xcodegen --version)" == "Version: $XCODEGEN_VERSION" ]] || { echo "xcodegen: version mismatch between flake.lock and .github/build-tools.env" >&2; exit 1; }

lint: lint-code lint-docs lint-build-tools

check: fmt-check lint test

[doc("Show all Debug processes and sleep state (agents need owner approval).")]
[group('app')]
status:
    #!/usr/bin/env bash
    set -euo pipefail
    source {{ quote(justfile_directory() / "scripts/debug-app.sh") }}
    exe={{ quote(debug_app / "Contents/MacOS/Capsaicin") }}
    printf 'This checkout: %s\n' "$exe"
    echo '--- All Debug processes: PID, start time, executable path, checkout match'
    running="$(debug_processes)"
    if [[ -n "$running" ]]; then
        while IFS=$'\t' read -r pid path; do
            started="$(/bin/ps -o lstart= -p "$pid" 2>/dev/null)" || started=unknown
            if [[ "$path" == "$exe" ]]; then
                match=yes
            elif [[ -n "$path" ]]; then
                match=no
            else
                match=unknown
            fi
            printf '%s  %s  %s  (this checkout: %s)\n' "$pid" "$started" "${path:-unknown}" "$match"
        done <<< "$running"
    else
        echo 'No Debug processes.'
    fi
    echo '--- SleepDisabled'
    /usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" {print $2; found = 1} END {if (!found) exit 1}' || echo 'Could not read SleepDisabled.'
    echo '--- Capsaicin assertions'
    /usr/bin/pmset -g assertions | /usr/bin/grep -i capsaicin || echo 'No Capsaicin assertions, or could not read them.'

[doc("Quit all Debug apps, then send SIGTERM only to remaining processes (agents need owner approval).")]
[group('app')]
stop:
    #!/usr/bin/env bash
    set -euo pipefail
    source {{ quote(justfile_directory() / "scripts/debug-app.sh") }}
    wait_for_exit() {
        local i running
        for ((i = 0; ; i++)); do
            running="$(debug_processes)" || return
            if [[ -z "$running" || "$i" -eq "$1" ]]; then
                printf '%s' "$running"
                return
            fi
            /bin/sleep 1
        done
    }
    requested="$(debug_processes quit)"
    [[ -n "$requested" ]] || { echo 'No Debug apps are running.'; exit 0; }
    remaining="$(wait_for_exit 10)"
    if [[ -n "$remaining" ]]; then
        while IFS= read -r process; do
            # 待機中に起動した別のプロセスには SIGTERM を送らない。
            /usr/bin/grep -Fxq -- "$process" <<< "$requested" || continue
            pid="${process%%$'\t'*}"
            printf 'Sending SIGTERM to Debug PID %s.\n' "$pid"
            kill -TERM "$pid" || true
        done <<< "$remaining"
        remaining="$(wait_for_exit 5)"
    fi
    if [[ -n "$remaining" ]]; then
        printf 'Debug processes still running:\n%s\n' "$remaining" >&2
        exit 1
    fi
    echo 'Debug apps stopped.'

[doc("Open this checkout's Debug app if no Debug app is running (agents need owner approval).")]
[group('app')]
start:
    #!/usr/bin/env bash
    set -euo pipefail
    source {{ quote(justfile_directory() / "scripts/debug-app.sh") }}
    app={{ quote(debug_app) }}
    exe="$app/Contents/MacOS/Capsaicin"
    running="$(debug_processes)"
    [[ -z "$running" ]] || { echo 'Debug apps are running. Run just stop first.' >&2; exit 1; }
    [[ -x "$exe" ]] || { echo 'Debug app is missing. Run just build first.' >&2; exit 1; }
    /usr/bin/open "$app"
    # 同じ bundle ID の別のコピーではなく、このチェックアウトのビルドを開けたことを確かめる。
    for ((i = 0; i < 10; i++)); do
        /bin/sleep 1
        running="$(debug_processes)"
        [[ "$running" != *$'\n'* ]] || continue
        IFS=$'\t' read -r pid path <<< "$running"
        [[ "$path" == "$exe" ]] || continue
        printf 'Started Debug PID %s: %s\n' "$pid" "$path"
        exit 0
    done
    echo 'Could not confirm that this checkout is the only running Debug app. Run just status.' >&2
    exit 1

[doc("Build this checkout, stop all Debug apps, then start this checkout's app (agents need owner approval).")]
[group('app')]
restart: build stop start
