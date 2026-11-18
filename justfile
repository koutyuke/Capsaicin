set shell := ["bash", "-euo", "pipefail", "-c"]

xcode_base := "-project Capsaicin.xcodeproj -scheme Capsaicin -sdk macosx -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/xcode -clonedSourcePackagesDirPath .build/spm"
xcode_args := xcode_base + " -configuration Debug"
version := `sed -n 's/^ *MARKETING_VERSION: "\(.*\)"$/\1/p' project.yml`
debug_id := "io.github.koutyuke.capsaicin.debug"
debug_app := justfile_directory() / ".build/xcode/Build/Products/Debug/Capsaicin.app"
# どのチェックアウトの Debug ビルドにも一致する、実行ファイルのコマンドライン。
debug_process := "/Build/Products/Debug/Capsaicin[.]app/Contents/MacOS/Capsaicin$"

default:
    @just --list

gen:
    xcodegen generate --spec project.yml

build: gen
    /usr/bin/xcodebuild {{ xcode_args }} build

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
    exe='{{ debug_app }}/Contents/MacOS/Capsaicin'
    echo '--- LaunchAgent job'
    if job="$(/bin/launchctl print "gui/$UID/{{ debug_id }}" 2>/dev/null)"; then
        /usr/bin/grep -E '^[[:space:]]*(state|pid|program) =' <<< "$job" || true
        program="$(/usr/bin/awk -F ' = ' '/^[[:space:]]*program = / {print $2; exit}' <<< "$job")"
        [[ "$program" == "$exe" ]] && echo 'Job matches this checkout: yes' || echo 'Job matches this checkout: no'
    else
        echo 'Job is not loaded or could not be read.'
    fi
    printf 'This checkout: %s\n' "$exe"
    echo '--- All Debug processes: PID, start time, executable path'
    pids="$(/usr/bin/pgrep -f '{{ debug_process }}' | /usr/bin/paste -sd, -)" || pids=''
    /bin/ps -ww -o pid=,lstart=,args= -p "$pids" 2>/dev/null || echo 'No Debug processes.'
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
    pids() { /usr/bin/pgrep -f '{{ debug_process }}' || true; }
    wait_stopped() {
        for ((i = 0; i < $1; i++)); do
            [[ -z "$(pids)" ]] && return 0
            /bin/sleep 1
        done
        [[ -z "$(pids)" ]]
    }
    [[ -n "$(pids)" ]] || { echo 'No Debug apps are running.'; exit 0; }
    /usr/bin/osascript -e 'tell application id "{{ debug_id }}" to quit' >/dev/null 2>&1 || true
    if wait_stopped 10; then echo 'Debug apps stopped.'; exit 0; fi
    remaining="$(pids)"
    if [[ -n "$remaining" ]]; then
        printf 'Sending SIGTERM to remaining Debug PIDs:\n%s\n' "$remaining"
        /usr/bin/xargs /bin/kill -TERM <<< "$remaining" || true
    fi
    if wait_stopped 5; then echo 'Debug apps stopped.'; exit 0; fi
    printf 'Debug PIDs still running:\n%s\n' "$(pids)" >&2
    exit 1

# Open this checkout's Debug app after unloading its job (agents need owner approval).
[group('app')]
start:
    #!/usr/bin/env bash
    set -euo pipefail
    exe='{{ debug_app }}/Contents/MacOS/Capsaicin'
    ! /usr/bin/pgrep -f '{{ debug_process }}' >/dev/null || { echo 'Debug apps are running. Run just stop first.' >&2; exit 1; }
    [[ -d '{{ debug_app }}' ]] || { echo 'Debug app is missing. Run just build first.' >&2; exit 1; }
    if /bin/launchctl print "gui/$UID/{{ debug_id }}" >/dev/null 2>&1; then
        /bin/launchctl bootout "gui/$UID/{{ debug_id }}"
    fi
    /usr/bin/open '{{ debug_app }}'
    # SMAppService の登録はアプリに任せ、引き渡し後のジョブが動かす実行ファイルで判定する。
    for ((i = 0; i < 10; i++)); do
        /bin/sleep 1
        job="$(/bin/launchctl print "gui/$UID/{{ debug_id }}" 2>/dev/null)" || continue
        pid="$(/usr/bin/awk -F ' = ' '/^[[:space:]]*pid = / {print $2; exit}' <<< "$job")"
        [[ -n "$pid" ]] || continue
        program="$(/usr/bin/awk -F ' = ' '/^[[:space:]]*program = / {print $2; exit}' <<< "$job")"
        [[ "$program" == "$exe" ]] || { printf 'The Debug job runs another executable: %s\n' "$program" >&2; exit 1; }
        printf 'Started Debug PID %s: %s\n' "$pid" "$program"
        exit 0
    done
    echo 'The Debug job did not start within 10 seconds.' >&2
    exit 1

# Build, stop, and start this checkout's Debug app, in that order (agents need owner approval).
[group('app')]
restart: build stop start
