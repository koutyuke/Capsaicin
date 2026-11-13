---
schema: task
id: TASK-075
title: ソースを MIT ライセンスで公開する準備をする
status: done
requirements: ["REQ-SYS-007"]
depends_on: []
assignee: PM（Claude）
---

# TASK-075 ソースを MIT ライセンスで公開する準備をする

## 目的

`DEC-SYS-009` を、リポジトリのライセンス表示と入口の文書に反映し、公開してよい状態かを確かめる。GitHub のリポジトリ作成と push は、オーナーの承認を得てから別に行う。

## 範囲

- `docs/meta/decisions/DEC-SYS-009-open-source-under-mit.md`、`docs/product/overview.md`（利用者の節）
- リポジトリ直下の `LICENSE`、`THIRD_PARTY_NOTICES.md`、`README.md`、`README.ja.md`
- `.agents/skills/` と `skills-lock.json` は読むだけで変えない。

## 作るもの

- MIT ライセンスの `LICENSE`。著作権者は `koutyuke`。
- `.agents/skills/` に含める外部のスキル（emilkowalski/skills、MIT）の著作権表示とライセンス文を載せた `THIRD_PARTY_NOTICES.md`。
- アプリの概要、動作環境、root で動く部分、ビルドの方法、文書の場所、貢献の受け付け、ライセンスを書いた `README.md`（英語）と `README.ja.md`（日本語）。構成と見た目は、オーナーの koutyuke/agent-instructions-nix の README に合わせる。

## 公開前の確認

`main` の履歴（2026-11-13 時点）を次の観点で調べた。

- コミットの作者とコミッターは GitHub の noreply アドレスだけである。
- 認証情報や鍵の形の文字列はない。`NOPASSWD` は sudoers のルールの生成コードである。
- 開発機の絶対パスは `TASK-047` の添付ファイルのパス2行だけで、含まれるのは GitHub のアカウント名と同じユーザー名である。
- `buildServer.json`（開発機の絶対パスを含む）は `main` の履歴になく、ツールのチェックポイントの参照にだけある。公開時は `main` だけを push し、`--all` や `--mirror` を使わない。

## 完了条件

- `nix develop --command just check` が通る。
- README の記述が `docs/specs/helper.md`、`AGENTS.md`、要件に合っている。

## 検証

上のコマンドの結果と、README を仕様と照らして読むこと。

## レビュー

独立したレビュー（Claude、読み取りのみ）の指摘と対応は次のとおりである。

- README が「root で動くのはヘルパーだけ」と書いていたが、設置と削除の処理も管理者認証の後に root で動く。設置と削除を除くと書き直した。
- README が「切り替えはすべて HUD で知らせる」と書いていたが、CLI での切り替えでは表示しない（`SPEC-HUD-001`）。メニューバーとホットキーに限った。
- LED の独自シンボルは SF Symbols のテンプレートから作っている。Apple のグリフから形を取っていないかは、オーナーが確かめる。
