---
schema: task
id: TASK-101
title: リリースの準備で、版のどの部分を上げるかを指定する
status: in_review
requirements: []
depends_on: []
assignee: Claude Opus 5.5（PM が直接実装）
---

# TASK-101 リリースの準備で、版のどの部分を上げるかを指定する

## 目的

`DEC-SYS-022` に従い、`just prepare-release` が `major`、`minor`、`patch` のどれかを必ず受け取り、指定した部分の版を上げるようにする。PATCH に `I-Breaking` を含めないことと、`develop` の PATCH と `hotfix/*` の版の衝突を、準備の時点で止める。

## 範囲

- `scripts/prepare_release.py`、`scripts/tests/test_prepare_release.py`
- `justfile` の `prepare-release`
- `.github/workflows/pr-policy.yml` の `hotfix/*` の検査
- `.agents/skills/capsaicin-release/SKILL.md`
- `AGENTS.md` のレシピの表
- `docs/meta/decisions/DEC-SYS-022-release-kind-chosen-by-owner.md`（新規）、`DEC-SYS-014` の「版」と「リリースの流れ」

`release.yml` と、戻しマージの手順は変えない。

## 完了条件

- 引数がない、または `major`、`minor`、`patch` 以外なら、使い方を表示して終了コード 1 で止まる。
- `develop` では3種類のどれでも、指定した部分を上げた `release/vX.Y.Z` を作る。`patch` で前回のタグ以降の PR に `I-Breaking` があれば止まる。`hotfix/*` があれば `patch` の準備を止める。
- `hotfix/*` では `patch` だけを受け付け、同じ版の `release/v*` があれば止まる。
- PR policy が、`hotfix/*` から `main` への PR に `I-Breaking` があれば失敗する。
- 1.0.0 未満の特例がなくなり、`0.x` から `major` で `1.0.0` にできる。

## 検証

- `nix develop --command just check`
- `test_prepare_release.py` が、上の完了条件をそれぞれ一時 Git リポジトリで確かめる。

## レビュー

- 規則の案を Codex（GPT-6 Astra）に助言として求めた。「Semantic Versioning ではないと明記する」「PATCH の互換性はラベル検査で保証できるわけではない」「`develop` の PATCH と `hotfix/*` の版の衝突は、タグの検査では公開前に止まらない」の指摘を `DEC-SYS-022` と準備時の検査に反映した。
