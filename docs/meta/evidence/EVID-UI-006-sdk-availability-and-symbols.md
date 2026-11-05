---
schema: evidence
id: EVID-UI-006
title: NSMenuItem の見出しと副題、NSGlassEffectView の対応 OS と、使う SF Symbols の存在
observed_on: 2026-11-06
environment: Xcode の MacOSX27.2.sdk、macOS 27.0.1（ビルド 26A434）、Mac16,8（Apple M4 Pro）
sources: ["/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSMenuItem.h", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSGlassEffectView.h", "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist"]
---

# EVID-UI-006 NSMenuItem の見出しと副題、NSGlassEffectView の対応 OS と、使う SF Symbols の存在

## 確かめた事実

- `NSMenuItem.h`: `+sectionHeaderWithTitle:` は `API_AVAILABLE(macos(14.0))`、`subtitle` は `API_AVAILABLE(macos(14.4))`。注記に、macOS 14 では属性付きのタイトルを持つ項目は副題を表示せず、macOS 15 以降は表示するとある。
- `NSGlassEffectView.h`: `NSGlassEffectView` は `API_AVAILABLE(macos(26.0))`。
- 開発用の Mac の `name_availability.plist` の `symbols` に、`gearshape`、`moon.zzz`、`timer`、`capslock`、`capslock.fill`、`keyboard`、`lock.shield`、`info.circle`、`exclamationmark.triangle.fill`、`checkmark.circle.fill`、`doc.on.doc`、`checkmark`、`xmark.circle.fill`、`chevron.up.chevron.down` がある。各名前の値（登場した年）は 2019 か 2020 である。

## 確かめ方

ヘッダーの該当する宣言を `grep` で読んだ。SF Symbols は、Python の `plistlib` で `name_availability.plist` を読み、各名前が `symbols` にあることを確かめた。

## 適用範囲

対応環境（macOS 26 以降）で、メニューの見出しと副題、`NSGlassEffectView` を使えること、仕様で使う SF Symbols の名前が存在することの根拠に使ってよい。

## 未確認のこと

- macOS 26 の Mac にも、同じ SF Symbols があるか（確かめたのは macOS 27.0.1 の Mac である）。
