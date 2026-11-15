<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

  <img src="./.github/assets/capsaicin-icon.png" alt="Capsaicin" width="128" height="128">

  <h1>🌶️ Capsaicin 🌶️</h1>

  <p><i>A spicy kick to keep your Mac awake.</i></p>
  <p>
    <a href="https://github.com/koutyuke/Capsaicin/actions/workflows/ci.yml"><img src="https://github.com/koutyuke/Capsaicin/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
    <img src="https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&amp;logoColor=white" alt="macOS 26+">
    <img src="https://img.shields.io/badge/Apple_Silicon-arm64-000000" alt="Apple Silicon">
    <img src="https://img.shields.io/badge/Swift-6.4-F05138?logo=swift&amp;logoColor=white" alt="Swift 6.4">
    <img src="https://img.shields.io/badge/License-MIT-64748B" alt="MIT License">
  </p>

  <p>
    <b>🇬🇧 English</b> | <a href="./README.ja.md">🇯🇵 日本語</a>
  </p>

  <p><sub>✦ ✦ ✦</sub></p>
</div>
<!-- markdownlint-enable MD033 -->

## Overview

**Capsaicin** is a macOS utility app designed to prevent your Mac from sleeping according to your needs.

- **Sleep Prevention**: Prevent idle sleep, display sleep, manual sleep, and more—all within a single app.
- **Keep Awake with Display Closed**: Control behavior when closing your MacBook's display. In addition to default system sleep, you can choose display sleep, keep the screen on, or set screen brightness to 0 when closed.
- **Automatic Deactivation**: Automatically restore normal sleep settings via timers, a scheduled time of day, or when the battery level drops low.
- **Multiple Ways to Control**: Start and end sleep prevention from the menu bar, configurable hotkeys, or the command line (CLI).
- **HUD Notifications**: Receive on-screen notifications for status toggles and app warnings.
- **Status via Caps Lock LED**: The Caps Lock LED lights up while sleep prevention is active, allowing you to check the status without looking at the screen. The actual Caps Lock typing state is not modified, and Input Monitoring permissions are not required.
- **Minimal Root Privileges**: Privileged operations requiring root are isolated into a small helper tool; root access is never requested for anything else.

## Inspiration

Capsaicin was inspired by the following two applications. We express our sincere gratitude and respect to their creators.

- [Capsomnia](https://github.com/fuji-mak/Capsomnia): A macOS app that turns Caps Lock into a sleep prevention switch and indicates state via its LED. Capsaicin adopts Capsomnia's idea of indicating state through the Caps Lock LED and delegating only root-required tasks to a minimal helper tool.
- [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704): A Mac keep-awake app. Capsaicin references its approach of preventing idle sleep first while allowing users to optionally suppress other sleep types, as well as its menu-based configuration structure.

Capsaicin is developed independently as a separate application and is not affiliated with either developer or project. Please do not contact the creators of those applications regarding bugs or inquiries about Capsaicin.

## Installation

### Supported Environments

- Apple Silicon Mac (Intel Macs are not supported)
- macOS 26 or later

### GitHub Releases

1. Download `Capsaicin-{version}.zip` from [Releases](https://github.com/koutyuke/Capsaicin/releases).
2. Unpack the zip archive and move `Capsaicin.app` to your Applications folder.
3. Open `Capsaicin.app`.

Because Capsaicin is not notarized by Apple, macOS may block it on first launch. If this occurs, open **System Settings** > **Privacy & Security**, scroll to **Security**, and click **Open Anyway**.

To verify that the downloaded zip archive has not been tampered with, compare it against `SHA256SUMS.txt` from the release or verify it using the [GitHub CLI](https://cli.github.com/):

```bash
shasum -a 256 -c SHA256SUMS.txt
gh attestation verify Capsaicin-{version}.zip --repo koutyuke/Capsaicin
```

### Homebrew

Distribution via a dedicated Homebrew tap is planned (coming soon).

## Building from Source

Requires Xcode 27.2 and Nix with flakes enabled.

```bash
git clone https://github.com/koutyuke/Capsaicin.git
cd Capsaicin
nix develop --command just build
```

The app will be generated at `.build/xcode/Build/Products/Debug/Capsaicin.app`.

## Development & Testing

```bash
nix develop --command just check  # Format check, linting, and all tests
nix develop --command just test   # Script, package, and app tests
nix develop --command just fmt    # Format all files with treefmt
```

For more details, please refer to the documentation.

## Documentation

The documentation is written in Japanese.

- 🧭 [Documentation Index](./docs/README.md) — How to find requirements, specifications, and design decisions
- 🎯 [Product Overview](./docs/product/overview.md) — Purpose, target users, goals, and non-goals
- 📐 [Specifications](./docs/specs/) — Behavioral specifications for each feature
- 🧱 [Decisions](./docs/meta/decisions/) — Architectural decisions: choices, rationale, and revisit triggers

## Contributing

Bug reports and feature requests are welcome in [Issues](https://github.com/koutyuke/Capsaicin/issues), in English or Japanese.

## License

Copyright 2026 koutyuke

Licensed under the [MIT License](./LICENSE). Third-party notices are listed in [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md).
