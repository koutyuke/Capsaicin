<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

  <h1>🌶️ Capsaicin</h1>

  <p><i>Keep your Mac awake, and let the Caps Lock LED tell you it is.</i></p>
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

**Capsaicin** is a menu bar app that prevents your Mac from sleeping, one kind of sleep at a time, and lights the Caps Lock LED while it does. You can tell whether sleep prevention is on without looking at the screen. Only the LED changes; the Caps Lock input state stays as it is.

```text
            ┌──→ Sleep prevented (idle / display / manual / closed display)
Turn on ────┤
            └──→ Caps Lock LED on

Turn off, timer, time of day, or low battery ──→ sleep settings and LED restored
```

- **Choose What Stays Awake**: Prevent idle sleep, display sleep and the screen saver, manual sleep, and sleep when the display is closed. When the display is closed, the Mac can keep running with the display off or its brightness at 0.
- **An LED You Can See Without Looking**: Lights the Caps Lock LED on built-in and external keyboards. It does not change the Caps Lock input state and does not ask for Input Monitoring permission.
- **Turns Itself Off**: Ends after a timer, at a time of day, or when the battery runs low, and restores the sleep settings. It also cleans up after a quit, a crash, or a restart.
- **Menu Bar, Hotkey, and CLI**: Turn it on and off from the menu bar, a global hotkey you assign, or the `capsaicin` command. A HUD shows changes made from the menu bar or the hotkey.
- **A Minimal Root Helper**: Apart from the install and removal steps you approve with administrator authentication, the only code that runs as root is a small helper that accepts two subcommands.

The UI is in Japanese only. Capsaicin is under development and has no prebuilt releases yet; build it from source.

## Requirements

- A Mac with Apple Silicon
- macOS 26 or later

## Privileged Helper

Preventing manual sleep and sleep when the display is closed requires root. When you choose a setting that needs it, Capsaicin asks for administrator authentication once and installs three items.

| Item         | Location                          | Role                                                                                                |
| ------------ | --------------------------------- | --------------------------------------------------------------------------------------------------- |
| Helper       | `/Library/PrivilegedHelperTools/` | Accepts only `on` (same as `pmset -a disablesleep 1`) and `off` (same as `pmset -a disablesleep 0`) |
| sudoers rule | `/etc/sudoers.d/`                 | Lets the installing user run only the helper's `on` and `off` without a password                    |
| LaunchDaemon | `/Library/LaunchDaemons/`         | Runs the helper's `off` at startup so sleep is never left disabled                                  |

You can remove all three from the Helper section in Settings. See [`docs/specs/helper.md`](./docs/specs/helper.md) for the behavior and [`DEC-HLP-001`](./docs/meta/decisions/DEC-HLP-001-minimal-helper-via-sudoers.md) for why this design was chosen (both in Japanese).

## Build from Source

You need Xcode 27.2 and Nix with flakes enabled. Run this from the repository root:

```bash
git clone https://github.com/koutyuke/Capsaicin.git
cd Capsaicin
nix develop --command just build
```

The app is built at `.build/xcode/Build/Products/Debug/Capsaicin.app`. It is ad-hoc signed and not notarized by Apple ([`DEC-SYS-004`](./docs/meta/decisions/DEC-SYS-004-no-developer-program-distribution.md) explains why).

## Development & Testing

```bash
nix develop --command just check  # Format check, lint, and all tests
nix develop --command just test   # Script, package, and app tests
nix develop --command just fmt    # Format all files with treefmt
```

See [`AGENTS.md`](./AGENTS.md) for the development environment and every recipe.

## Documentation

The documents are written in Japanese.

- 🧭 [Documentation index](./docs/README.md) — how to find requirements, specifications, and decisions
- 🎯 [Product overview](./docs/product/overview.md) — purpose, users, goals, and non-goals
- 📐 [Specifications](./docs/specs/) — how each feature behaves
- 🧱 [Decisions](./docs/meta/decisions/) — what was chosen, why, and when to revisit it

## Contributing

Bug reports and feature requests are welcome in [Issues](https://github.com/koutyuke/Capsaicin/issues), in English or Japanese. Pull requests are not accepted.

## License

Copyright 2026 koutyuke

Licensed under the [MIT License](./LICENSE). Third-party works included in this repository are listed in [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md).
