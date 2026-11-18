---
schema: task
id: TASK-105
title: 文字サイズを変えたときに、設定のサイドバーの下の2項目を下端に寄せ直す
status: in_review
requirements: []
depends_on: []
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-105 文字サイズを変えたときに、設定のサイドバーの下の2項目を下端に寄せ直す

## 目的

GitHub の Issue #7 を直す。設定ウインドウを開いたまま、システム設定で文字サイズ（またはサイドバーのアイコンのサイズ）を変えると、サイドバーの「ヘルパー」と「このアプリについて」が下端に寄り直らず、下に余白が残る。`SPEC-SET-001` では、下の2項目をサイドバーの下端に寄せる。ウインドウを開き直すと直る。

原因の見当（未確認）: `Sources/Capsaicin/Settings/SettingsControls.swift` の `SettingsSidebarSpacer` は、上の4行と下の2行の高さを `NSTableView` から読み、見える高さとの差をスペーサーの高さにしている。文字サイズが変わると行の高さは変わるが、`availableHeight` は変わらないので `updateNSView` が呼ばれない。スペーサー自身のフレームも変わらなければ `layout()` も走らず、古い高さが残る。サイドバーの既定の余白（`padding`）を、表がはみ出したときにしか測り直さない点も影響しうる。

## 範囲

変更してよいもの: `Sources/Capsaicin/Settings/SettingsControls.swift`、必要なら `Sources/Capsaicin/Settings/SettingsView.swift`、テストを足すなら `Tests/CapsaicinTests/Settings/` の下。

触らないもの: 右側の本文の文字サイズへの追従（Issue の対象外）、ほかの画面、`docs/`（このチケットを除く）。

## やること

1. 文字サイズやサイドバーのアイコンのサイズが変わったときに、行の高さの変化を確実に拾って `updateHeight()` を呼び直す方法を、AppKit の仕組みから選ぶ。候補は、表やクリップビューのフレームの変化の通知、行の高さが変わったときに AppKit が送る通知や呼び出しなど。どれが実際に送られるかを、AppKit のヘッダーやドキュメントで確かめてから選ぶ。推測で複数の通知を重ねて購読しない。
2. 余白（`padding`）が古い値のまま残らないようにする。測り直せない状況で古い値を使い続けるなら、その理由をコメントに書く。
3. 高さの計算を純粋な関数に切り出せるなら切り出し、行の高さと見える高さを変えたときの結果を Swift Testing で確かめる。切り出しがコードを増やすだけなら、しなくてよい。その判断を報告に書く。

## 守ること

- アプリを起動しない（`DEC-SYS-024` の承認がない）。実機での確認は、オーナーが PR の Debug ビルドで行う。
- 既存の振る舞い（ウインドウの高さを変えたときの追従、はみ出したときにスクロールしないこと）を壊さない。
- `git commit` と `git push` をしない。

## 完了条件

- 文字サイズの変更の後に `updateHeight()` が呼ばれる経路があり、その経路が AppKit の文書で裏付けられている。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just check`
- 実機（オーナー）: 設定ウインドウを開いたまま、「アクセシビリティ > ディスプレイ > 文字サイズ」と、「外観 > サイドバーのアイコンのサイズ」を変え、下の2項目が下端に寄ったままであることを見る。ウインドウの高さを変えても寄ったままであることも見る。

## レビュー

PM がレビューした。空き行の `NSTableRowView` のフレーム変更通知だけを購読し（`NSView.h` の `postsFrameChangedNotifications`、`NSTableView.h` の `noteHeightOfRowsWithIndexesChanged:` による再配置）、行の高さが変わったら余白の記録を捨てて測り直す。回帰テスト（`SidebarTextSizeTests`）は修正前に失敗し、修正後に通る。指摘なし。残りはオーナーの実機での確認だけである。
