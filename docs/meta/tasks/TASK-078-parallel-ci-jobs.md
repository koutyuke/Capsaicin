---
schema: task
id: TASK-078
title: CI を並列のジョブと集約のジョブに分ける
status: done
requirements: []
depends_on: ["TASK-076", "TASK-077"]
assignee: PM（Claude）
---

# TASK-078 CI を並列のジョブと集約のジョブに分ける

## 目的

`DEC-SYS-012` を CI とリリースのワークフローに反映し、CI の結果が出るまでの時間を縮める。

## 範囲

- `.github/workflows/ci.yml`、`.github/workflows/release.yml`
- `docs/meta/decisions/DEC-SYS-012-parallel-ci-jobs-with-gate.md`

## 作るもの

- `ci.yml` を、4つのジョブの `matrix` と、その結果を集める「All checks passed」のジョブにする。`workflow_call` で呼び出せるようにする。
- `release.yml` は `ci.yml` を呼び出し、その成功の後に配布物を作る。リリースのジョブの中の `just check` はやめる。

## 完了条件

- actionlint がワークフローに指摘を出さない。
- push の後、CI の4つのジョブと集約のジョブが成功する。

## 検証

actionlint の結果と、push の後の CI の結果。
