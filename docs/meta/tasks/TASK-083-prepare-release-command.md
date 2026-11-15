---
schema: task
id: TASK-083
title: リリースの準備を手元で行う just prepare-release を作る
status: done
requirements: []
depends_on: []
assignee: 実装者（Codex、OpenCode の openai/gpt-5.6-sol）
---

# TASK-083 リリースの準備を手元で行う just prepare-release を作る

## 目的

`DEC-SYS-014` の「リリースの流れ」の1を実装する。版の決定と材料の収集を、毎回同じ結果になるスクリプトにする。

## 範囲

- `scripts/prepare_release.py`（新規）、`scripts/tests/test_prepare_release.py`（新規）
- `justfile`（`prepare-release` のレシピを足す。`lint-build-tools` のコメントの判断の参照を `DEC-SYS-015` に付け替える）
- `flake.nix`（devShell に `gh` を足す）

`AGENTS.md` のレシピの表は `TASK-085` が更新するので触らない。

## 作るもの

`just prepare-release` と `just prepare-release patch` の2つの使い方を持つ。どちらも手元だけで完結し、push、PR の作成、タグの作成をしない。GitHub への問い合わせは `gh pr view` の読み取りだけにする。

### 共通

1. 作業ツリーに変更（未追跡のファイルを含む）があれば止める。
2. `git fetch origin --tags` で、リモートのブランチとタグを最新にする。
3. 最新のリリースのタグを、`v{MAJOR}.{MINOR}.{PATCH}` の形のタグのうち版が最大のものとする。そのタグと `origin/main` が HEAD の祖先でなければ、「`main` を戻しマージしていない」として止める。
4. `project.yml` の `MARKETING_VERSION` が最新のタグの版と一致しなければ止める。
5. 新しい版のタグが既にあれば止める。
6. 新しい版にしたら、`project.yml` の `MARKETING_VERSION` を新しい版にし、`CURRENT_PROJECT_VERSION` を1増やして、`project.yml` だけを `Release v{版}` のメッセージでコミットする。
7. 材料を `.build/release/v{版}.json` に書き出し、版とパスを表示する。

### 通常のリリース（引数なし）

- 現在のブランチが `develop` で、HEAD が `origin/develop` と一致していなければ止める。
- 手元かリモートに `release/` で始まるブランチがあれば止める。
- 最新のタグから HEAD までの first-parent の merge commit のうち、件名が `Merge pull request #<番号> from ` で始まるものから PR の番号を集める。
- 各 PR の番号、タイトル、URL、ラベルを `gh pr view` で読む。`S-Release` の PR は除く。種類のラベル（`T-` で始まるもの）がちょうど1つでない PR があれば、全件を並べて止める。
- PR が1件もなければ止める。
- 版は MINOR を上げる。`I-Breaking` の PR があれば MAJOR を上げるが、最新のタグの MAJOR が 0 なら MINOR を上げる。
- HEAD から `release/v{版}` を作って切り替えてから、6 のコミットをする。

### 緊急の修正（`patch`）

- 現在のブランチ名が `hotfix/` で始まらなければ止める。
- `origin/main` から HEAD までにコミットがなければ止める。
- 版は PATCH を上げる。ブランチは作らず、今のブランチに 6 のコミットをする。
- 材料には PR の代わりに、`origin/main` から HEAD までの merge でないコミット（SHA と件名）を入れる。

### 材料の形

```json
{
  "version": "0.4.0",
  "previous_tag": "v0.3.0",
  "kind": "minor",
  "branch": "release/v0.4.0",
  "pull_requests": [
    {"number": 12, "title": "…", "url": "…", "type": "T-Feature", "breaking": false, "labels": ["T-Feature", "A-App"]}
  ],
  "commits": []
}
```

`kind` は `minor`、`major`、`patch` のどれか。`patch` では `pull_requests` を空にし、`commits` に `{"sha": "…", "subject": "…"}` を入れる。

## 守ること

- スクリプトは標準ライブラリだけで書く。外部のコマンドは `git` と `gh` だけを使う。
- 判定（版の計算、件名からの番号の取り出し、ラベルの検査、`project.yml` の書き換え）は、副作用のない関数に分けてテストする。加えて、一時ディレクトリの Git リポジトリで、通常のリリースと緊急の修正の流れを1つずつ通すテストを書く。`gh` はテストで差し替える。テストのリポジトリでは `commit.gpgsign` を `false` にする（開発機の署名の設定に依存しないため）。
- `project.yml` の書き換えは、該当する行がちょうど1行ずつあることを確かめてから行う。
- 止めるときは、理由と次にすることを日本語で1〜2行で示し、終了コード 1 で終える。
- 起こりにくい場面への防御を重ねない。目安は本体 200 行前後。
- `git commit` はスクリプトの機能としてだけ行う。開発用のリポジトリそのものにはコミットしない。

## 完了条件

- `nix develop --command just check` が通る（新しいテストを含む）。
- `nix develop --command gh --version` が動く。
- 報告に、止める条件の一覧と、テストで確かめたことを書く。

## 検証

上のコマンドの結果と、差分の確認。

## レビュー

- PM が `fetch` を、ブランチは `--prune` 付き、タグは prune なしの2回に分けた。マージ後に消えた `release/*` の追跡ブランチが残り、誤って止まるのを防ぐため。
- 現在の版を読むために書き換え用の関数を仮の版で呼んでいる箇所に、理由のコメントを足した。
- それ以外は仕様どおりで指摘なし。`just test-scripts` が通る。
- 全体の検証: `nix develop --command just check` と actionlint が通った（2026-11-15）。
