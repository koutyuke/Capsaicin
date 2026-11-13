---
schema: task
id: TASK-076
title: GitHub の運用、CI、リリースのワークフローを用意する
status: done
requirements: ["REQ-SYS-005", "REQ-SYS-006"]
depends_on: ["TASK-075"]
assignee: PM（Claude）
---

# TASK-076 GitHub の運用、CI、リリースのワークフローを用意する

## 目的

`DEC-SYS-010` と `DEC-SYS-011` を、ワークフロー、Issue のテンプレート、`justfile`、手順書に反映する。リポジトリの設定（Pull Request の無効化、ルールセット、immutable なリリース）と push は、オーナーの承認を得てから行う。

## 範囲

- `docs/meta/decisions/DEC-SYS-010-trunk-based-without-pull-requests.md`、`docs/meta/decisions/DEC-SYS-011-github-actions-ci-and-release.md`、`docs/manual/release.md`
- `.github/workflows/ci.yml`、`.github/workflows/release.yml`、`.github/ISSUE_TEMPLATE/`、`.github/actionlint.yaml`
- `justfile`（`build-release`、`dist`、`version`）、`AGENTS.md`（作業の進め方、レシピの表）
- `README.md`、`README.ja.md`（CI のバッジ、clone の手順、貢献の節）

## 完了条件

- `nix develop --command just check` が通る。
- `nix develop --command just dist` が `.build/dist/` に zip と `SHA256SUMS.txt` を作り、zip のアプリに `Contents/Helpers/` の2つの実行ファイルが入っている。
- actionlint がワークフローに指摘を出さない。

## 検証

上のコマンドの結果。CI とリリースのワークフローが GitHub 上で動くことは、push の後に確かめる。

## レビュー

独立したレビュー（Claude、読み取りのみ）の指摘と対応は次のとおりである。

- actionlint が `xcode-27` を未知のラベルとして報告する。GitHub のホストランナーのラベルだが、actionlint の一覧に含まれていない。`.github/actionlint.yaml` に登録した。
- CI の `cancel-in-progress: true` だと、続けて push したときに前のコミットの CI が止まる。リリースするコミットには CI の成功が必要なので、`false` にした。
- リリースのワークフローは、タグが `main` 上のコミットを指すかを確かめない。タグを push できるのはオーナーだけなので、手順書の前提で足りるとして対応しない。
- 固定した Action の SHA と版、`--notes-from-tag` と immutable なリリースの組み合わせ、権限、入力の受け渡しには問題がなかった。

`zip` に拡張属性の `._*` が入っていたため、`ditto` に `--norsrc --noextattr --noacl` を付けた。展開したアプリが `codesign --verify --deep --strict` を通ることを確かめた。
