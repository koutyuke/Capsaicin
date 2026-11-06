---
schema: task
id: TASK-016
title: アプリの日本語の文言を仕上げる
status: done
requirements: []
depends_on: [TASK-013, TASK-014]
assignee: OpenCode / GPT-6.1 Sol（Gemini の利用上限のため、利用者の指示で交代）
---

# TASK-016 アプリの日本語の文言を仕上げる

## 目的

実装の担当が仮に入れた日本語を、落ち着いていて品があり、何の設定か一目で分かる文言にそろえる。

## 範囲

書いてよい: `Sources/Capsaicin/**/*.xcstrings` の日本語の値と、`.t3-code/drafts/copy/copy-deck.md`。

触らない: キー、Swift のコード、`docs/`、`project.yml`。キーやコードの変更が必要なら、変更せずに報告する。

## 作るもの

- すべてのカタログの値を、仕様（`docs/specs/`）と文言の定義書（`.t3-code/drafts/copy/copy-deck.md`）に照らして見直す。用語、敬体・常体、句読点、和文と英字の間の空白（GUI は詰め、CLI のコマンドの書式の前後は空ける）を、定義書の方針にそろえる。
- 書式指定子（`%@`、`%d`、`%1$@` など）の数・順序・種類は変えない。
- HUD の解除の条件・理由は、カプセルに収まる短さにする（`SPEC-HUD-004`）。
- 定義書にない文言を足したら、定義書にも足す。

## 完了条件

- すべてのカタログの日本語が、定義書の方針にそろっている。
- `nix develop --command just check` が通る（カタログの JSON の形式を壊さない）。

## レビュー

Gemini の利用上限のため、利用者の指示で Codex が `yomiyasu` の手順に従って推敲した。10 カタログ 201 キーのうち 55 キーを変えた。PM が全変更を読み、用語（スリープ防止のオン・オフ）、手動スリープの説明が `SPEC-BLK-001` と合うこと、HUD の理由の短さを確かめた。HUD のテストの期待値は文字列だけを合わせた。`just check` が通った。実画面での収まりと VoiceOver の読み上げは未確認である。
