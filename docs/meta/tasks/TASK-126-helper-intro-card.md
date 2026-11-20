---
schema: task
id: TASK-126
title: 「ヘルパー」に説明のカードを置き、許可の手順を承認待ちのときだけ出す
status: in_progress
requirements: ["REQ-HLP-005", "REQ-SET-003"]
depends_on: []
assignee: Codex（OpenCode openai/gpt-6.2-sol）
---

# TASK-126 「ヘルパー」に説明のカードを置き、許可の手順を承認待ちのときだけ出す

## 目的

`DEC-SET-010` のとおり、設定の「ヘルパー」セクションを、先頭の説明のカードと、状態と管理の2行のカードに分ける。「状態」の行の説明文は、承認待ちのときだけ許可の手順を出す。振る舞いは `SPEC-HLP-004` と `SPEC-SET-002` の「ヘルパー」の表にある。

## 範囲

変更してよいファイル:

- `Sources/Capsaicin/Settings/SettingsView.swift`（`helper` の中だけ）
- `Sources/Capsaicin/Settings/SettingsControls.swift`（説明のカードの部品を足す）
- `Sources/Capsaicin/Settings/SettingsHelper.xcstrings`（`intro.message` と `status.requiresApproval.help` を足し、使わなくなる `status.help` を消す）
- `Tests/CapsaicinTests/Settings/SettingsRendering.swift`

触らないもの: `docs/`、ほかのセクション、`SettingsFeedbackBanner`、ヘルパーの状態の判定と管理の操作（`SettingsModel`）。

## 完了条件

- 「ヘルパー」の先頭に説明のカードがあり、`SPEC-HLP-004` のアイコン・見出し・説明文の決まりを満たす。
- 「状態」と「ヘルパーの管理」は、説明のカードの下の1枚のカードに、この順で並ぶ。
- 「状態」の行の説明文は、承認待ちのときだけ `status.requiresApproval.help`、ほかの状態では空である。
- 4状態それぞれで、行の数、状態の値、ボタンがこれまでどおりであることをテストで確かめる。テスト名は `SPEC-HLP-004` で始める。
- `nix develop --command just check` が通る。

## 検証

`nix develop --command just check` と `nix develop --command just build`。見た目は PM が確かめる。

## レビュー

（PM が記入する）
