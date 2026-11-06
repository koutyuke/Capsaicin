---
schema: task
id: TASK-020
title: 設定ウインドウの上端を Xcode と同じ高さのツールバーにする
status: done
requirements: ["REQ-SET-002"]
depends_on: ["TASK-019"]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-020 設定ウインドウの上端を Xcode と同じ高さのツールバーにする

## 目的

`TASK-019` の後、オーナーから2つの指摘があった。上端の行（32 pt）が詰まっていて、閉じるボタンなどとセクション名の見出しの周りにゆとりがない。Xcode 27 の設定ウインドウのように、戻る・進むのボタンがない形にしたい。

Xcode の設定ウインドウでは、上端に通常のツールバー（`.unified`）があり、閉じるボタンなどはその縦の中央にある（上端から約 26 pt）。セクション名は、ツールバーのタイトル（15 pt の太字）として出る。

PM が確かめたことは次のとおりである（`.build/settings/` の描画、テストの中での寸法の書き出し、オーナーの実機の画像による）。

1. `SettingsWindowController.makeWindow` で `window.toolbar = NSToolbar()` と `window.toolbarStyle = .unified` を設定し、`titleVisibility` を既定（表示）に戻すと、次の見た目になる。
   - 閉じるボタンの縦の中心: 上端から 26 pt
   - タイトルの左端: 218 pt（項目のグループの左端は 220 pt）
   - タイトルの文字: `SFNS-Semibold 15 pt`
   - オーナーの実機の画像でも、見出しが閉じるボタンと同じ高さで、項目の左端に揃っていた。
2. ただしこのとき、サイドバーの `List` が崩れる。
   - 安全領域の上端は 66 pt、`NSScrollView.contentInsets.top` も 66 pt になる。行は文書の 0 から並ぶ。
   - SwiftUI の `onScrollGeometryChange` が返す `contentSize.height` は、空きの行を除くと「行の合計 224 + 42」になる。このため、今の下端寄せは空きの高さを 42 pt 少なく見積もる。
   - その結果、「このアプリについて」の下端と表示領域の下端の間が 42 pt 空く（ツールバーなしでは 10 pt）。オーナーの実機の画像でも 42 pt 浮いていた。
   - `.contentMargins(..., for: .scrollContent)` を `List` と `Form` に付けても、寸法は変わらなかった。
3. `host.sceneBridgingOptions = [.toolbars]` だけでは、ツールバーは作られなかった（安全領域の上端は 32 pt のまま）。

## 範囲

書いてよい:

- `Sources/Capsaicin/Settings/SettingsView.swift`
- `Sources/Capsaicin/Settings/SettingsWindowController.swift`
- `Tests/CapsaicinTests/Settings/SettingsTests.swift`

触らない: ほかのすべてのファイル（`docs/`、`project.yml`、String Catalog を含む）。

## 作るもの

1. 上端を通常のツールバー（`.unified`）にし、セクション名をツールバーの標準のタイトルとして出す。
   - `TASK-019` でアプリが描いた見出し（`SettingsView` の `overlay` と `titlebarHeight`）と、`titleVisibility = .hidden` は外す。
   - 戻る・進むのボタンなどの項目は置かない。サイドバーの開閉ボタンも出さない。
2. 「ヘルパー」と「このアプリについて」を、ツールバーがある状態でサイドバーの下端に寄せる。
   - 最後の行の下端と表示領域の下端の間は 10 pt にする。ツールバーなしのときに `List` が上端に取っていた既定の余白と同じ値である。
   - 行の高さはシステム設定（サイドバーのアイコンのサイズ）で変わる。固定の行の高さを見積もらない。
   - 7 項目は1つの `List` のままにし、選択の表示と ↑↓ での移動を 7 項目を通して連続させる。
   - 方法は任せる。ただし、なぜその値になるかを説明できる素直な方法を選ぶ。SwiftUI 側で測れずに AppKit の `NSTableView` の行の高さを読む場合は、その理由をコメントに1〜2行で書く。`DispatchQueue.main.async` の重ね掛けや `.id` による作り直しのような、更新の順序に頼る仕掛けは避ける。
3. テストを今の挙動に合わせる。
   - ウインドウの設定のテストで、`toolbarStyle == .unified` を確かめる。
   - `checkSidebar` の下端の余白の期待値を 10 pt（±1）にする。高さを変えたときも同じ。
   - タイトルの位置のテスト（閉じるボタンと同じ高さで、左端が 200 pt より右）を、ツールバーのタイトルに対して戻す。`TASK-019` の前は `NSTextField` を `window.title` で探していた。

## 守ること

- 短く素直に書く（`TASK-010` を参照）。上の 1〜3 以外を変えない。右側の `Form` の余白はシステム既定のままにする。
- テストで ScreenCaptureKit や `screencapture` を使わない。画面収録の許可がなく、ロック中にも落ちるため。描画の確認は、今の `cacheDisplay` の PNG と、テストの中での寸法で行う。
  - `cacheDisplay` はツールバーがあるときのサイドバーのガラスを描けず、サイドバーが白く抜ける。見た目の最終確認はオーナーが実機で行う。
- テストでアプリを起動しない。`scripts/manual/` を実行しない。`launchctl`・`sudo`・`pmset` の設定変更を実行しない。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。`git commit` をしない。

## 完了条件

- 上の 1〜3 がある。
- テストの中で、ツールバーがある状態の最後の行の下端の余白が 10 pt（±1）である。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`

## レビュー

PM が差分を読んでレビューした。

- 上端は、空の `NSToolbar` と `.unified` で作っている。`TASK-019` でアプリが描いた見出しは外した。
- 下端寄せの空きの高さは、「表示領域 − 空き以外の7行の実際の高さ − 10 pt」である。実際の高さは、空きの行に置いた `NSView` が `NSTableView` から読む。
  - 表示領域の高さは `onScrollGeometryChange` で受け取る。
  - 空きの高さは、`layout()` と更新のたびに求め直す。値が変わったときだけ `intrinsicContentSize` を無効にするので、繰り返し更新されることはない。
  - SwiftUI の `contentSize` を使わない理由は、コメントに書いてある。
- テストで確かめていること:
  - 閉じるボタンの中心が上端から 26 pt にあり、タイトルが同じ高さに 15 pt で出ること。
  - 最後の行の下の余白が 10 pt であること（高さ 500 pt と 560 pt の両方）。
  - 行の高さ 24・32・40 pt のときの空きの計算。
  - ↑↓ で7項目を続けて移動できること。
- 空きの行の位置を表す `5` は、`SettingsView` の `prefix(5)` と対応する。2か所の値は同じ理由で変わるので、そのままにした。

`just check` と `just build` が通った。`cacheDisplay` は、ツールバーがあるときのサイドバーのガラスを描けない。そのため、見た目はオーナーが実機で確かめる（`docs/manual/verification.md` の 8.2）。

### 実機での確認の後

オーナーが実機で見たところ、サイドバーの最初の行と右側の最初のグループが、Xcode より約 14 pt 下にあった。PM が調べたところ、ウインドウの `contentLayoutRect` の上端が 66 pt だった。原因は、空のツールバーの表示方式が既定（アイコンとラベル）で、ラベルの行の分だけ高くなっていたことである。PM が `displayMode = .iconOnly` に直し、上端が 52 pt になることを確かめた。上端の高さを確かめるテストを足した。`just check` と `just build` が通った。
