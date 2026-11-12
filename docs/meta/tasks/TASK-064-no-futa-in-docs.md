---
schema: task
id: TASK-064
title: 文書から「蓋」をなくし、「MacBook」「ディスプレイを閉じる」に書き換える
status: done
requirements: []
depends_on: ["TASK-063"]
assignee: Codex（OpenCode、openai/gpt-6.1-sol、variant high）
---

# TASK-064 文書から「蓋」をなくし、「MacBook」「ディスプレイを閉じる」に書き換える

## 目的

`docs/documentation-management.md` の「書き方」に、「蓋」を書かない規則を加えた。既存の文書をこの規則に合わせる。

## 範囲

書いてよい: `docs/` の Markdown と TOML のうち、次を除くすべて。

触らないもの:

- `docs/meta/tasks/`（作業の記録。リリースで削除する）
- `docs/documentation-management.md` と `DEC-UI-012` の、「蓋」を書かない規則そのものの文
- `docs/` 以外のすべて（本番コード、テスト、`AGENTS.md`）。`git add`、`git stash`、`git commit` をしない。

## 作るもの

規則に従って書き換える。

| 今の書き方 | 書き換え |
| --- | --- |
| 蓋のある Mac | MacBook |
| 蓋のない Mac | MacBook 以外の Mac |
| 蓋を閉じる、蓋を開ける、蓋の開閉 | ディスプレイを閉じる、ディスプレイを開く、ディスプレイの開閉 |
| 蓋閉じスリープ | ディスプレイを閉じたときのスリープ |
| 閉じた蓋の中 | 閉じたディスプレイの中 |

表にない言い回しは、文脈に合わせて同じ規則で書き換える。API や設定の名前（`AppleClamshellState`、`kPMSetClamshellSleepState`、clamshell など）は変えない。

## 守ること

- 言い換えだけにし、判断・仮説・根拠の結論や事実を変えない。根拠に引用した資料の文言（英語の原文など）は変えない。
- ID、Front Matter、ファイル名を変えない。
- サブエージェントを起動しない。言い換えると意味が変わりそうな箇所は、変えずに報告する。

## 完了条件

- `rg -n "蓋" docs --glob '!docs/meta/tasks/**'` の結果が、規則そのものの文（`docs/documentation-management.md` と `DEC-UI-012`）だけになる。
- `nix develop --command just lint-docs` が通る。

## 検証

上の2つのコマンドの結果と、変えずに残した箇所とその理由を報告する。

## レビュー

- 44 ファイルを言い換え、ID、結論、事実は変わっていない。
- チケットが Front Matter を変えないとしていたため、記録のタイトルに「蓋」が残り、本文の見出しと食い違っていた。タイトルは ID と違って書き換えてよいので、PM が見出しに合わせて直した。根拠の `environment` の「蓋」も PM が直した。
- 以前の設定の項目名を引用した3か所（`DEC-BLK-002`、`DEC-BLK-003`、`EVID-LED-004`）は、当時の名前の引用なので残した。
- PM が `just lint-docs` を流し、通った。
