set shell := ["bash", "-euo", "pipefail", "-c"]

xcode_base := "-project Capsaicin.xcodeproj -scheme Capsaicin -sdk macosx -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/xcode -clonedSourcePackagesDirPath .build/spm"
xcode_args := xcode_base + " -configuration Debug"
version := `sed -n 's/^ *MARKETING_VERSION: "\(.*\)"$/\1/p' project.yml`

default:
    @just --list

gen:
    xcodegen generate --spec project.yml

build: gen
    /usr/bin/xcodebuild {{ xcode_args }} build

build-release: gen
    /usr/bin/xcodebuild {{ xcode_base }} -configuration Release build

# 配布用の zip と SHA-256 を .build/dist/ に作る。
dist: build-release
    mkdir -p .build/dist
    # 拡張属性やリソースフォークを ._* として zip に入れない。ad-hoc 署名は実行ファイルの中にある。
    ditto -c -k --norsrc --noextattr --noacl --keepParent .build/xcode/Build/Products/Release/Capsaicin.app .build/dist/Capsaicin-{{ version }}.zip
    cd .build/dist && shasum -a 256 Capsaicin-{{ version }}.zip > SHA256SUMS.txt

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
    # SwiftLint が Nix の Swift ではなく Xcode の SourceKit を読み込むための指定。
    TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault XCODE_DEFAULT_TOOLCHAIN_OVERRIDE="$(/usr/bin/xcode-select -p)/Toolchains/XcodeDefault.xctoolchain" swiftlint lint --strict --no-cache
    # Git が無視するファイル（グローバルの除外設定を含む）は検査しない。
    git ls-files -z --cached --others --exclude-standard -- '*.md' | xargs -0 markdownlint-cli2
    shellcheck --shell=bash .envrc
    find scripts -name '*.sh' -exec shellcheck {} +
    ruff check scripts
    statix check flake.nix
    statix check treefmt.nix
    deadnix --fail flake.nix treefmt.nix

# CI が Nix を使わずに入れる just と XcodeGen の版が、flake.lock の版と一致するかを確かめる（DEC-SYS-013）。
lint-build-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    source .github/build-tools.env
    [[ "$(just --version)" == "just $JUST_VERSION" ]] || { echo "just: flake.lock と .github/build-tools.env の版が違う" >&2; exit 1; }
    [[ "$(xcodegen --version)" == "Version: $XCODEGEN_VERSION" ]] || { echo "xcodegen: flake.lock と .github/build-tools.env の版が違う" >&2; exit 1; }

lint: lint-code lint-docs lint-build-tools

check: fmt-check lint test
