---
schema: evidence
id: EVID-BLK-002
title: pmset の man ページに displaysleepnow はあるが disablesleep はない
observed_on: 2026-11-06
environment: macOS 27.0.1（ビルド 26A434）、Mac16,8（Apple M4 Pro）、Xcode の MacOSX27.2.sdk
sources: ["/usr/share/man/man1/pmset.1", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk/System/Library/Frameworks/IOKit.framework/Versions/A/Headers/pwr_mgt/IOPMLibDefs.h"]
---

# EVID-BLK-002 pmset の man ページに displaysleepnow はあるが disablesleep はない

## 確かめた事実

- `pmset` の man ページは、`displaysleepnow` を「画面をすぐにスリープさせる」、`sleepnow` を「システムをすぐにスリープさせる」と説明している。
- 同じ man ページに `disablesleep` の記載はない。
- `kPMSetClamshellSleepState` は、SDK のヘッダー `IOPMLibDefs.h` に値 `12` の定数として定義されているだけで、使い方の説明はない。

## 確かめ方

```sh
man pmset | col -b | grep -n -iE 'displaysleepnow|disablesleep|sleepnow'
grep -n ClamshellSleepState "$(xcrun --sdk macosx --show-sdk-path)/System/Library/Frameworks/IOKit.framework/Versions/A/Headers/pwr_mgt/IOPMLibDefs.h"
```

## 適用範囲

`displaysleepnow` が文書化された操作であること、`disablesleep` と `kPMSetClamshellSleepState` が文書化されていない仕組みであることの根拠に使ってよい。

## 未確認のこと

- `displaysleepnow` に root が要るか（`HYP-BLK-001`）。man ページに権限の記載はない。
- `disablesleep` と `kPMSetClamshellSleepState` の実際の挙動。`disablesleep` の手動・蓋閉じスリープへの効果は `HYP-BLK-006` で確かめる。
