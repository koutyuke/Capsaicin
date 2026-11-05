---
schema: evidence
id: EVID-BLK-001
title: 電源管理アサーションは自動スリープと画面の自動消灯だけを止め、蓋閉じや手動のスリープは止めない
observed_on: 2026-11-06
environment: Xcode の MacOSX27.2.sdk（開発用 Mac は macOS 27.0.1、Mac16,8）
sources: ["/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk/System/Library/Frameworks/IOKit.framework/Versions/A/Headers/pwr_mgt/IOPMLib.h"]
---

# EVID-BLK-001 電源管理アサーションは自動スリープと画面の自動消灯だけを止め、蓋閉じや手動のスリープは止めない

## 確かめた事実

SDK のヘッダー `IOPMLib.h` は、次のように説明している。

- `kIOPMAssertPreventUserIdleSystemSleep`（値は `"PreventUserIdleSystemSleep"`）は、操作がないことによるシステムのスリープを止める。画面は暗くなったり消えたりしうる。システムは、蓋を閉じたとき、Apple メニュー、低バッテリー、そのほかの理由ではスリープしうる。
- `kIOPMAssertPreventUserIdleDisplaySleep`（値は `"PreventUserIdleDisplaySleep"`）は、操作がないことによる画面の消灯を止める。画面は、蓋を閉じたときやシステムのスリープなど、ほかの理由では消えうる。画面の消灯を止めている間は、システムも操作がないことによるスリープに入らない。
- どちらも `IOPMAssertionCreateWithName` か `IOPMAssertionCreateWithDescription` で作る。Dark Wake の間は効かない。

## 確かめ方

`xcrun --sdk macosx --show-sdk-path` で SDK の場所を求め、`pwr_mgt/IOPMLib.h` の該当する定義の上にあるコメントを読んだ。

## 適用範囲

アサーションで止められるスリープの種類と、止められない種類の根拠に使ってよい。

## 未確認のこと

- アサーションの作成に root が要らないこと（ヘッダーには権限の記載がない）。
- 実機での挙動。
