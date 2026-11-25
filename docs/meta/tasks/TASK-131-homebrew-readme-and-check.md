---
schema: task
id: TASK-131
title: README に Homebrew の入れ方と消し方を書き、オーナーの Mac で brew install を確かめる
status: todo
requirements: ["REQ-SYS-001", "REQ-SYS-002", "REQ-SYS-008"]
depends_on: ["TASK-130"]
assignee: Claude（Claude Code、Opus 5.5）
---

# TASK-131 README に Homebrew の入れ方と消し方を書き、オーナーの Mac で brew install を確かめる

## 目的

公開した tap（`TASK-130`）を利用者が使えるようにし、Homebrew で入れたアプリが Gatekeeper の検査に通ること（`EVID-SYS-010` の未確認のこと）を確かめる。

## 範囲

- `README.md` と `README.ja.md` の「Homebrew」の節: `brew install --cask koutyuke/tap/capsaicin`、`capsaicin` のコマンドが PATH に入ること（`DEC-CLI-004`）、更新は Sparkle が行うこと（`DEC-SYS-031`）。
- 同じ2つのファイルの「アンインストール」の節: Homebrew で入れた場合も、先に設定の「ヘルパー」の「削除…」でヘルパーを外してから `brew uninstall --cask capsaicin` を実行すること。設定と記録まで消すなら `--zap` を付けること。
- 確かめた結果を書く新しい根拠（ID は作業を始めるときに PM が割り当てる）と、`EVID-SYS-010` の「未確認のこと」の更新。

## 完了条件

- オーナーが、手順書に沿って、GitHub Release から入れた Capsaicin を外してから `brew install --cask koutyuke/tap/capsaicin` を実行し、次を確かめる: インストール中に Gatekeeper のエラーが出ない。アプリが起動する。`capsaicin status` が動く。`brew uninstall --cask capsaicin` でアプリとリンクが消える。tap を `brew trust` で信頼していなくても、入れる・消すの手順が通るか（通らなければ README の手順に `brew trust --tap koutyuke/tap` を入れる）。
- README の2つの言語の内容が一致し、名前が実装と一致する。
- `nix develop --command just check` が通る。

## 検証

- オーナーは `docs/manual/verification/homebrew-install.md` の手順で確かめる。エージェントは `brew install` と `brew uninstall` を行わない。確かめた結果を根拠に移したら、その手順書と一覧の行を削除する。
- `nix develop --command just check`。

## レビュー

まだない。
