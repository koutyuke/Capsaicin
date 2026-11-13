---
schema: task
id: TASK-079
title: CI のテストとリリースのビルドから Nix を外し、Release ビルドを CI と並列にする
status: done
requirements: []
depends_on: ["TASK-078"]
assignee: PM（Claude）
---

# TASK-079 CI のテストとリリースのビルドから Nix を外し、Release ビルドを CI と並列にする

## 目的

`DEC-SYS-013` を CI とリリースのワークフローに反映し、CI とリリースの所要時間を縮める。

## 範囲

- `.github/workflows/ci.yml`、`.github/workflows/release.yml`、`.github/actions/build-tools/action.yml`、`.github/build-tools.env`
- `justfile`（`lint-build-tools`）、`AGENTS.md`（レシピの表）
- `docs/meta/decisions/DEC-SYS-011-github-actions-ci-and-release.md`、`DEC-SYS-012-parallel-ci-jobs-with-gate.md`（置き換えの記録）、`DEC-SYS-013-ci-and-release-workflows.md`、`DEC-SYS-010-trunk-based-without-pull-requests.md` と `docs/manual/release.md`（参照の付け替え）

## 作るもの

- テストのジョブ（Package tests、App tests）と、リリースの Package のジョブは、`.github/actions/build-tools` で `just` と XcodeGen の配布バイナリを入れて動かす。
- Build のジョブをやめる。
- リリースは CI と Package を並列に走らせ、両方が通ってから Publish のジョブが attestation と GitHub Release の作成を行う。
- `just lint-build-tools` で、`.github/build-tools.env` の版と `flake.lock` の版の一致を確かめる。

## 完了条件

- `nix develop --command just check` と actionlint が通る。
- Nix を通らない環境（配布バイナリの `just` と XcodeGen、macOS の標準のコマンドだけ）で、`just test-package`、`just test-app`、`just --evaluate version`、`just dist` が通る。
- push の後、CI のすべてのジョブが成功する。

## 検証

上のコマンドの結果と、push の後の CI の所要時間。
