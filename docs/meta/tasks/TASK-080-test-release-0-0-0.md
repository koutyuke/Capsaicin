---
schema: task
id: TASK-080
title: 0.0.0 のテスト版でリリースの流れを確かめる
status: in_progress
requirements: []
depends_on: ["TASK-079"]
assignee: PM（Claude）
---

# TASK-080 0.0.0 のテスト版でリリースの流れを確かめる

## 目的

`DEC-SYS-013` のリリースの流れ（CI と Release ビルドの並列、attestation、immutable なリリース、タグの本文からのリリースノート）が動くことを、0.0.0 のテスト版で確かめる。オーナーの指示で、タグの作成と push もエージェントが行う。

## 範囲

- `project.yml`（`MARKETING_VERSION` を `0.0.0` にする）
- `docs/manual/release.md`（0.0.0 を `HYP-HLP-003` の前提の対象外にすること、最初のリリースの `CURRENT_PROJECT_VERSION`）
- タグ `v0.0.0` の作成と push

## 完了条件

- Release ワークフローが成功し、GitHub Release `v0.0.0` がプレリリースとして作られ、`Capsaicin-0.0.0.zip` と `SHA256SUMS.txt` が添付されている。
- リリースノートに、タグの署名が混ざっていない。
- ダウンロードした zip が `gh attestation verify` を通り、`SHA256SUMS.txt` と一致する。

## 検証

上の完了条件を、ワークフローの結果と GitHub Release の内容で確かめる。
