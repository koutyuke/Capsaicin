---
schema: task
id: TASK-125
title: 「ヘルパー」の説明のカードと許可の手順の文言を書く
status: in_progress
requirements: ["REQ-HLP-005", "REQ-SET-003"]
depends_on: []
assignee: Codex（OpenCode openai/gpt-6.2-sol）
---

# TASK-125 「ヘルパー」の説明のカードと許可の手順の文言を書く

## 目的

`DEC-SET-010` で足す2つの文の英語と日本語を書く。

- `intro.message`: 「ヘルパー」の先頭の説明のカードの説明文。
- `status.requiresApproval.help`: 承認待ちのときだけ「状態」の行に出す、許可の手順。

伝える内容は `SPEC-HLP-004` にある。見出しは既存の `title`（「ヘルパー」/「Helper」）を使うので書かない。

## 範囲

ファイルを変更しない。文は報告で返し、PM が String Catalog に入れる。

## 完了条件

- 2つのキーの英語と日本語の値が、PM が渡した部品の名前と事実だけで書かれている。
- 日本語は yomiyasu スキルの基準で推敲してある。
- 部品が足りなければ、`<<不足: 何が要るか>>` と書いて報告している。

## 検証

PM が部品と突き合わせ、名前・パス・事実の書き換えや追加がないことを確かめる。

## レビュー

（PM が記入する）
