---
schema: task
id: TASK-082
title: CI を develop と main への PR で動かし、PR の規則を検査する
status: done
requirements: []
depends_on: []
assignee: 実装者（Codex、OpenCode の openai/gpt-5.6-sol）
---

# TASK-082 CI を develop と main への PR で動かし、PR の規則を検査する

## 目的

`DEC-SYS-015` の「CI」と「PR の規則」を、ワークフローに反映する。

## 範囲

- `.github/workflows/ci.yml`
- `.github/workflows/pr-policy.yml`（新規）
- `.github/build-tools.env`、`.github/actions/build-tools/action.yml`（判断の参照を `DEC-SYS-013` から `DEC-SYS-015` に付け替えるだけ）

`.github/workflows/release.yml` は `TASK-084` が書き直すので触らない。

## 作るもの

- `ci.yml`
  - トリガーを、`develop` と `main` への push、`develop` と `main` への `pull_request`、`workflow_dispatch` にする。`workflow_call` は使わなくなるので消す。
  - 同じ PR の古い実行は取り消し、push の実行は取り消さない。
  - ジョブの中身（Format and lint、Package tests、App tests、All checks passed）は変えない。
- `pr-policy.yml`
  - `develop` と `main` への `pull_request`（`opened`、`reopened`、`synchronize`、`labeled`、`unlabeled`）で、Ubuntu のジョブ「PR policy」を1つ動かす。権限は `contents: read` だけにする。
  - 規則は `DEC-SYS-015` の「PR の規則」のとおり。加えて、`main` への PR は、head が同じリポジトリのブランチであることも確かめる。
  - ラベルは、イベントの `pull_request.labels` から読む。
  - 失敗したときは、何が足りないかを `::error::` で示す。

## 守ること

- ブランチ名、ラベル名、PR のタイトルなど、PR の作り手が決められる値を、`run:` の中に `${{ }}` で直接埋め込まない。`env:` で渡してから使う（スクリプトの注入を防ぐため）。
- 外部の Action を足すなら、既存と同じくコミットの SHA で固定し、版をコメントで添える。足さずに済むならシェルと `jq`（Ubuntu のランナーに入っている）で書く。
- 起こりにくい場面への防御を重ねない。規則は `DEC-SYS-015` にあるものだけを確かめる。

## 完了条件

- `nix develop --command just check` が通る。
- actionlint が通る（devShell にないので `nix shell nixpkgs#actionlint --command actionlint` で実行する）。
- `pr-policy.yml` の判定を、`develop` への PR、`release/v*` からの PR、`hotfix/*` からの PR、それ以外からの `main` への PR について、どう判定されるかを報告に書く。

## 検証

上のコマンドの結果と、差分の確認。

## レビュー

- PM が差分を読んで確かめた。`DEC-SYS-015` の規則どおりで、PR の作り手が決められる値は `env:` かイベントの JSON を経由している。権限は読み取りだけ。指摘なし。
- 版の比較は PR のマージ結果の `project.yml` を使う。`main` は前回リリースした版なので、`release/*` の版と比べられる。
- 全体の検証: `nix develop --command just check` と actionlint が通った（2026-11-15）。
