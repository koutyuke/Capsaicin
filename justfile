set shell := ["bash", "-euo", "pipefail", "-c"]

xcode_base := "-project Capsaicin.xcodeproj -scheme Capsaicin -sdk macosx -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/xcode -clonedSourcePackagesDirPath .build/spm"
xcode_args := xcode_base + " -configuration Debug"
version := `sed -n 's/^ *MARKETING_VERSION: "\(.*\)"$/\1/p' project.yml`
debug_id := "io.github.koutyuke.capsaicin.debug"
debug_app := justfile_directory() / ".build/xcode/Build/Products/Debug/Capsaicin.app"

default:
    @just --list

gen:
    xcodegen generate --spec project.yml

build: gen
    /usr/bin/xcodebuild {{ xcode_args }} build

# オーナーのキーチェーンの鍵で、このチェックアウトの Debug アプリを署名し直す（エージェントは承認が必要）。
[positional-arguments]
sign-debug identity="Apple Development":
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
    /usr/bin/codesign -dv "$app" 2>&1 | /usr/bin/grep -E '^(Identifier|TeamIdentifier)='

build-release: gen
    /usr/bin/xcodebuild {{ xcode_base }} -configuration Release build

# 確認用 Debug の追加 dylib を作らず、PR とコミットを名前に含む zip を作る。
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
    (cd .build/debug-dist && shasum -a 256 "$zip_name" > SHA256SUMS.txt)

# Create a distribution zip and SHA-256 checksum in .build/dist/.
dist: build-release
    mkdir -p .build/dist
    # Exclude extended attributes and resource forks; ad-hoc signatures are in the executables.
    ditto -c -k --norsrc --noextattr --noacl --keepParent .build/xcode/Build/Products/Release/Capsaicin.app .build/dist/Capsaicin-{{ version }}.zip
    cd .build/dist && shasum -a 256 Capsaicin-{{ version }}.zip > SHA256SUMS.txt

prepare-release mode="":
    python3 scripts/prepare_release.py {{ mode }}

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

# Show the Debug job, paths, processes, and sleep state (agents need owner approval).
[group('app')]
status:
    #!/usr/bin/env bash
    set -euo pipefail
    source '{{ justfile_directory() }}/scripts/debug-app.sh'
    exe='{{ debug_app }}/Contents/MacOS/Capsaicin'
    echo '--- LaunchAgent job'
    if job="$(/bin/launchctl print "gui/$UID/{{ debug_id }}" 2>/dev/null)"; then
        /usr/bin/grep -E '^[[:space:]]*(state|pid) =' <<< "$job" || true
        pid="$(/usr/bin/awk -F ' = ' '/^[[:space:]]*pid = / {print $2; exit}' <<< "$job")"
        if [[ -n "$pid" ]]; then
            path="$(executable_path "$pid")" || path=''
            printf 'Job executable: %s\n' "${path:-unknown (could not read executable)}"
            if [[ -z "$path" ]]; then
                echo 'Job matches this checkout: unknown (could not read executable)'
            else
                [[ "$path" == "$exe" ]] && echo 'Job matches this checkout: yes' || echo 'Job matches this checkout: no'
            fi
        else
            echo 'Job matches this checkout: unknown (job is not running)'
        fi
    else
        echo 'Job is not loaded or could not be read.'
        echo 'Job matches this checkout: unknown (job is not loaded or could not be read)'
    fi
    printf 'This checkout: %s\n' "$exe"
    echo '--- All Debug processes: PID, start time, PPID, executable path'
    pids="$(debug_pids)"
    if [[ -z "$pids" ]]; then
        echo 'No Debug processes.'
    else
        for pid in $pids; do
            path="$(executable_path "$pid")" || continue
            details="$(/bin/ps -ww -o pid=,lstart=,ppid= -p "$pid" 2>/dev/null)" || continue
            printf '%s %s\n' "$details" "$path"
        done
    fi
    echo '--- SleepDisabled'
    /usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" {print $2}' || echo 'Could not read SleepDisabled.'
    echo '--- Capsaicin assertions'
    /usr/bin/pmset -g assertions | /usr/bin/grep -i capsaicin || echo 'No Capsaicin assertions, or could not read them.'
    exit 0

# Quit all Debug apps, then send SIGTERM only to remaining processes (agents need owner approval).
[group('app')]
stop:
    #!/usr/bin/env bash
    set -euo pipefail
    source '{{ justfile_directory() }}/scripts/debug-app.sh'
    wait_stopped() {
        for ((i = 0; i < $1; i++)); do
            [[ -z "$(debug_pids)" ]] && return 0
            /bin/sleep 1
        done
        [[ -z "$(debug_pids)" ]]
    }
    [[ -n "$(debug_pids)" ]] || { echo 'No Debug apps are running.'; exit 0; }
    /usr/bin/osascript -e 'tell application id "{{ debug_id }}" to quit' >/dev/null 2>&1 || true
    if wait_stopped 10; then echo 'Debug apps stopped.'; exit 0; fi
    remaining="$(debug_pids)"
    if [[ -n "$remaining" ]]; then
        printf 'Sending SIGTERM to remaining Debug PIDs:\n%s\n' "$remaining"
        /usr/bin/xargs /bin/kill -TERM <<< "$remaining" || true
    fi
    if wait_stopped 5; then echo 'Debug apps stopped.'; exit 0; fi
    printf 'Debug PIDs still running:\n%s\n' "$(debug_pids)" >&2
    exit 1

# Open this checkout's Debug app after unloading its job (agents need owner approval).
[group('app')]
start:
    #!/usr/bin/env bash
    set -euo pipefail
    source '{{ justfile_directory() }}/scripts/debug-app.sh'
    exe='{{ debug_app }}/Contents/MacOS/Capsaicin'
    [[ -z "$(debug_pids)" ]] || { echo 'Debug apps are running. Run just stop first.' >&2; exit 1; }
    [[ -d '{{ debug_app }}' ]] || { echo 'Debug app is missing. Run just build first.' >&2; exit 1; }
    if /bin/launchctl print "gui/$UID/{{ debug_id }}" >/dev/null 2>&1; then
        /bin/launchctl bootout "gui/$UID/{{ debug_id }}"
    fi
    /usr/bin/open '{{ debug_app }}'
    # SMAppService の登録はアプリに任せ、ジョブの PID と実行ファイル、親プロセスで引き渡しを確かめる。
    for ((i = 0; i < 10; i++)); do
        /bin/sleep 1
        job="$(/bin/launchctl print "gui/$UID/{{ debug_id }}" 2>/dev/null)" || continue
        pid="$(/usr/bin/awk -F ' = ' '/^[[:space:]]*pid = / {print $2; exit}' <<< "$job")"
        [[ -n "$pid" ]] || continue
        path="$(executable_path "$pid")" || continue
        [[ "$path" == "$exe" ]] || continue
        ppid="$(/bin/ps -o ppid= -p "$pid" 2>/dev/null)" || continue
        [[ "$ppid" -eq 1 ]] || continue
        printf 'Started Debug PID %s: %s\n' "$pid" "$path"
        exit 0
    done
    echo 'The Debug job did not start within 10 seconds.' >&2
    echo 'A directly opened app may still be running without a confirmed agent handoff; this is not a successful start.' >&2
    echo 'An ad-hoc build cannot launch an agent registered by a build with the same bundle ID and a Team ID.' >&2
    echo 'Re-sign this build with the same Team ID using just sign-debug.' >&2
    echo "Check launch constraints: /usr/bin/log show --last 5m --predicate 'process == \"launchd\"' | grep 'Launch Constraint Violation'" >&2
    exit 1

# Build, stop, and start this checkout's Debug app, in that order (agents need owner approval).
[group('app')]
restart: build stop start
