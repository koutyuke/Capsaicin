set shell := ["bash", "-euo", "pipefail", "-c"]

xcode_args := "-project Capsaicin.xcodeproj -scheme Capsaicin -configuration Debug -sdk macosx -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/xcode -clonedSourcePackagesDirPath .build/spm"

default:
    @just --list

gen:
    xcodegen generate --spec project.yml

build: gen
    /usr/bin/xcodebuild {{ xcode_args }} build

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
    markdownlint-cli2
    shellcheck --shell=bash .envrc
    find scripts -name '*.sh' -exec shellcheck {} +
    ruff check scripts
    statix check flake.nix
    statix check treefmt.nix
    deadnix --fail flake.nix treefmt.nix

lint: lint-code lint-docs

check: fmt-check lint test
