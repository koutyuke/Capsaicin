---
schema: evidence
id: EVID-SET-002
title: 設定ウインドウを開いたまま文字サイズやサイドバーのアイコンのサイズを変えても、サイドバーの下の2項目は下端に寄ったままだった
observed_on: 2026-11-18
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、Debug 構成、ダークモード
sources: ["Sources/Capsaicin/Settings/SettingsControls.swift", "Sources/Capsaicin/Settings/SettingsWindowController.swift", "Tests/CapsaicinTests/Settings/SidebarTextSizeTests.swift", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSView.h", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSTableView.h"]
---

# EVID-SET-002 設定ウインドウを開いたまま文字サイズやサイドバーのアイコンのサイズを変えても、サイドバーの下の2項目は下端に寄ったままだった

## 確かめた事実

ブランチ `feature/sidebar-text-size` の `9574fc7` のコードでビルドした Debug アプリで確かめた。設定ウインドウを開いたまま、システム設定で次の変更をした。どの変更の後も、サイドバーの「ヘルパー」と「このアプリについて」は下端に寄ったままで、下に余白は残らず、サイドバーはスクロールしなかった（`SPEC-SET-001`）。

- 「アクセシビリティ > ディスプレイ > 文字サイズ」を大きくした。サイドバーの行の間隔は、画面写真上で約 64 px から約 80 px に広がった。「このアプリについて」の行の下端は、変更前の約 979 px に対して約 980 px で、ほぼ同じ位置にあった。
- 文字サイズを元に戻した。配置は変更前の画面写真と同じになった。
- 文字サイズを元より小さくした（オーナーの目視と画面写真）。
- 「外観 > サイドバーのアイコンのサイズ」を「小」と「大」にした（オーナーの画面写真）。行の間隔は「小」で約 50 px、「大」で約 80 px だった。「このアプリについて」の行の下端は、どちらも約 1056 px だった。

px の値は、Retina の画面写真上の値である。

設定ウインドウは大きさを変えられない。`SettingsWindowController` は、ウインドウの `styleMask` に `.resizable` を含めていない。そのため、ウインドウの高さを変えたときの追従は、実機では確かめられなかった。

修正では、サイドバーの空き行の `NSTableRowView` で `postsFrameChangedNotifications` を有効にし、そのフレーム変更の通知を購読する（`NSView.h`）。行の高さが変わると、AppKit は行を並べ直す（`NSTableView.h` の `noteHeightOfRowsWithIndexesChanged:`）。空き行の位置もこのときに動くので、通知を受けて高さを測り直す。行の高さが変わったときは、記録していたサイドバーの既定の余白を捨てて測り直す。回帰テスト `SidebarTextSizeTests` は、修正前に失敗し、修正後に通った。

## 確かめ方

1. `nix develop --command just build` で Debug アプリをビルドする。
2. オーナーの承認を得て、エージェントが `just stop`、`just start`、`just status` を実行し、このチェックアウトのビルドが動いていることを確かめた（`DEC-SYS-024`）。
3. オーナーが設定ウインドウを開き、システム設定で文字サイズとサイドバーのアイコンのサイズを変えた。
4. エージェントは、各変更の後に `screencapture -x -o -l <ウインドウ番号>` で設定ウインドウの画面写真を撮った。ウインドウ番号は `CGWindowListCopyWindowInfo` で Debug アプリの PID から引いた。オーナーも、自分で画面写真を撮った。
5. 画面写真の行の位置を比べた。

## 適用範囲

- 使ってよい: 設定ウインドウのサイドバーが、行の高さの変化に追従するかを判断するとき。
- 使ってはいけない: 右側の本文の文字サイズへの追従、ライトモードでの見た目。

## 未確認のこと

- ウインドウの高さを変えたときの追従。設定ウインドウは大きさを変えられないので、実機では起こらない。
- 設定ウインドウを開いたまま、表示する画面を解像度や倍率の違う画面へ移したときの配置。
