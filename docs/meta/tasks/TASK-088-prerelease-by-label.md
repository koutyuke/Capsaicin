---
schema: task
id: TASK-088
title: プレリリースを S-Prerelease のラベルで決める
status: done
requirements: []
depends_on: ["TASK-084", "TASK-086"]
assignee: PM（Claude）
---

# TASK-088 プレリリースを S-Prerelease のラベルで決める

## 目的

`DEC-SYS-016` を、Release ワークフロー、スキル、リリースの手順書に反映する。

## 範囲

- `.github/workflows/release.yml`（Publish のジョブのプレリリースの判定）
- `.agents/skills/capsaicin-release/SKILL.md`（手順 5 と 6）
- `docs/manual/release.md`（前提と通常のリリースの手順 2）
- `docs/meta/decisions/DEC-SYS-014-*.md`、`DEC-SYS-015-*.md`（プレリリースの記述を `DEC-SYS-016` への参照に置き換える）
- GitHub のラベル `S-Prerelease` の作成

## 完了条件

- `nix develop --command just check` と actionlint が通る。
- `release.yml` が版を見ず、イベントの PR のラベルに `S-Prerelease` があるときだけ `--prerelease` を付ける。

## 検証

上のコマンドの結果と、差分の確認。実際の動作は、次のリリースで確かめる。

## レビュー

- `DEC-SYS-014` と `DEC-SYS-015` の結論の一部を、同じ ID のまま `DEC-SYS-016` への参照に書き換えた。文書の運用規則は、結論を変えるときに新しい判断で全体を置き換えるよう定めているが、1行の変更のために2つの判断を丸ごと写すと読み手の負担が大きいので、参照の付け替えにとどめた（2026-11-15）。
