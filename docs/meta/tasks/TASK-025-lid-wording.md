---
schema: task
id: TASK-025
title: ノートブックを閉じる操作の文言を「蓋」から改める
status: done
requirements: ["REQ-SET-003", "REQ-SET-005"]
depends_on: []
assignee: 文章担当（Gemini 3.8 Flash）、PM が修正
---

# TASK-025 ノートブックを閉じる操作の文言を「蓋」から改める

## 目的

オーナーが、設定画面の「スリープの種類」で、ラップトップの画面を閉じる操作を「蓋」と呼ぶのは合わないと指摘した。

Apple の日本語のサポート文書は、この操作を主に「ディスプレイを閉じる」と書く。画面に出る文言をこの呼び方にそろえ、「蓋閉じスリープ」のような造語もやめる。

仕様書の項目名は項目を指す呼び名で、文言の正本は String Catalog にある（`SPEC-UI-011`）。そのため、変えるのは String Catalog の日本語だけにする。仕様書、コードのコメント、テスト名の「蓋閉じスリープ」は内部の呼び名として残す。

## 範囲

書いてよい（`ja` の `value` だけ）:

- `Sources/Capsaicin/Settings/SettingsSleep.xcstrings`
- `Sources/Capsaicin/Settings/SettingsHelper.xcstrings`（`helperInstall.manualAndLid.title`）
- `Sources/Capsaicin/CLI/CLI.xcstrings`（`mechanism.lidSleepControl`）

触らない: キー、Swift のコード、テスト、`docs/`。`Sources/Capsaicin/Settings/SettingsWindowController.swift` と `docs/manual/verification.md` にはオーナーの未コミットの変更がある。

## 完了条件

- 画面と CLI に出る文言に「蓋」が残っていない。
- 閉じる操作を同じ呼び方で統一し、ほかの行（「自動スリープ」「手動スリープ」「画面の自動消灯」）と並べても長さと調子がそろっている。
- 「手動」と閉じる操作をまとめた行の名前・説明・含意の理由・ヘルパーの確認ダイアログが、同じ呼び方を使っている。
- 説明（help）の伝える内容は変えない（`SPEC-SET-002` の「(i) で伝えること」）。項目名だけで内容が伝わるようにする（`SPEC-SET-003`）。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 設定画面での見え方は、オーナーが実機で確かめる。

## レビュー

Gemini が「ディスプレイを閉じたときのスリープ」にそろえて書き換えた。PM が次の2点を直した。

- まとめた行の「手動とディスプレイを閉じたときのスリープ」は「手動とディスプレイ」を閉じるとも読めるため、説明文と同じ「手動スリープとディスプレイを閉じたときのスリープ」にした。含意の理由とヘルパーの確認ダイアログも合わせた。
- 子の行の「画面を消灯」は、いつ消灯するかが項目名だけでは分からず（`SPEC-SET-003`）、上の「画面の自動消灯」とも紛らわしいため、「閉じたときに画面を消灯」にした。

設定ウインドウの幅は 720pt で、最も長い項目名（25文字）も1行に収まる見込みである。`nix develop --command just check` と `nix develop --command just build` が通ることを確かめた。見え方はオーナーが実機で確かめる。
