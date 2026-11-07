---
schema: evidence
id: EVID-SET-001
title: 常駐アプリの有効化の API と、公開されている常駐アプリの設定画面の開き方
observed_on: 2026-11-07
environment: Xcode の MacOSX27.2.sdk、macOS 27.0.1（ビルド 26A434）。GitHub の各リポジトリの既定のブランチ
sources: ["/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSApplication.h", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSRunningApplication.h", "https://developer.apple.com/documentation/appkit/nsapplication/activate()", "https://developer.apple.com/documentation/appkit/passing-control-from-one-app-to-another-with-cooperative-activation", "https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct", "https://developer.apple.com/forums/thread/836619", "https://developer.apple.com/forums/thread/832795", "https://github.com/rxhanson/Rectangle/blob/main/Rectangle/AppDelegate.swift", "https://github.com/jordanbaird/Ice/blob/main/Ice/Main/AppState.swift", "https://github.com/p0deje/Maccy", "https://github.com/MonitorControl/MonitorControl", "https://github.com/lwouis/alt-tab-macos"]
---

# EVID-SET-001 常駐アプリの有効化の API と、公開されている常駐アプリの設定画面の開き方

## 確かめた事実

- `NSApplication.h`: `-activate` は「有効化を保証しない。協調的な有効化では、相手のアプリが先に `-yieldActivationToApplication:` を呼ぶ」と注記されている。`-activateIgnoringOtherApps:` は `API_DEPRECATED("This method will be deprecated in a future release. Use NSApp.activate instead.", macos(10.0, API_TO_BE_DEPRECATED))` で、将来の廃止予定であり、この SDK では廃止の版が決まっていない。
- `NSRunningApplication.h`: `-activateFromApplication:options:`（macOS 14 以降）も、相手のアプリが先に譲ることを前提にしている。
- Apple のドキュメントは、`NSWorkspace` で URL やアプリを開くと譲り渡しを自動で扱う、と書いている。
- `NSWindow.CollectionBehavior` の `.moveToActiveSpace` は「有効になったとき、Space を切り替えずにウインドウを現在の Space に移す」。通常のレベルのウインドウの既定は `.managed`（Mission Control と Spaces に参加する）。
- Apple Developer Forums の 836619（2026年7月）: `LSUIElement` の常駐アプリがメニューから画面を開くと、`NSApp.activate()` では前面のアプリの裏に出て、`activate(ignoringOtherApps: true)` では前面に出る、と報告されている。Apple の DTS は、厳しくしたのはフォーカスを奪わせないための意図的な変更で、`activate()` を使うよう答えた。修正や代わりの API は示していない。832795 では、`.regular` に切り替えてから `activate()` しても約2割で前面に出ないと報告され、Apple の回答はフィードバックの依頼だけだった。
- 公開されている常駐アプリのうち、Rectangle は設定画面を `NSApp.activate(ignoringOtherApps: true)` の後に `showWindow` で開く。Maccy、MonitorControl、AltTab も、画面を開くときに `activate(ignoringOtherApps: true)` を使う。Ice は設定画面を開く間だけ `.regular` にし、`NSRunningApplication.current.activate(from:)` を使い、初回は Dock を経由して 0.2 秒待つ。
- Rectangle、Maccy、Ice が `collectionBehavior` を設定しているのは、オーバーレイやパネルだけで、設定画面には設定していない。

## 確かめ方

ヘッダーは該当する宣言を `grep` で読んだ。Apple のドキュメントは Context7 経由で読んだ。フォーラムの2件は Web で読んだ。各アプリのソースは `gh search code` で `activate` と `collectionBehavior` を探し、Rectangle の `AppDelegate.swift` と Ice の `AppState.swift` は該当箇所を読んだ。

## 適用範囲

どの有効化の API を選ぶか、他のアプリと比べてどの書き方が一般的か、の判断に使ってよい。

## 未確認のこと

- この Mac で、Capsaicin の設定画面が `activate()` で前面に出ない事象の再現と、`activate(ignoringOtherApps: true)` で前面に出ることは確かめていない（`HYP-SET-003`）。
- 前面に出たときに、別の Space にある設定画面へ macOS が移るかは確かめていない（`HYP-SET-003`）。
- Stats と AltTab の `collectionBehavior` は、GitHub の API の利用上限で検索できなかった。Maccy、MonitorControl、AltTab、Stats で `activate(ignoringOtherApps: true)` を使っている箇所が設定画面そのものかは確かめていない。
- ソースが公開されていない常駐アプリ（Dropover など）の実装は確かめていない。
