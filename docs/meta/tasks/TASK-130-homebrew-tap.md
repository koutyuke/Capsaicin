---
schema: task
id: TASK-130
title: Homebrew の tap koutyuke/homebrew-tap と Cask capsaicin を作る
status: in_progress
requirements: ["REQ-SYS-001", "REQ-SYS-002", "REQ-SYS-008"]
depends_on: []
assignee: Claude（Claude Code、Opus 5.5）
---

# TASK-130 Homebrew の tap koutyuke/homebrew-tap と Cask capsaicin を作る

## 目的

`DEC-SYS-031` と `DEC-CLI-004` のとおりに、`brew install --cask koutyuke/tap/capsaicin` で Capsaicin を入れられるようにする。

## 範囲

作るもの（Capsaicin のリポジトリの外、`../homebrew-tap` に作り、オーナーの承認を得てから GitHub に公開する）:

- `Casks/capsaicin.rb`: `DEC-SYS-031` の「Cask には次を書く」のすべて。版は公開中の最新の安定版（v0.2.0）にする。
- `.github/workflows/`: push と PR で `brew style` と `brew audit` を実行するワークフローと、定期実行と手動実行で Cask を更新するワークフロー。更新では `gh attestation verify --repo koutyuke/Capsaicin` で DMG の来歴を確かめてから書き換える。ワークフローに Python を直書きしない。
- `README.md`（英語）と `LICENSE`（MIT、著作権者 `koutyuke`）。

Capsaicin のリポジトリでは、このチケットのファイルだけを変える。README の更新は `TASK-131` が行う。

してはいけないこと: `koutyuke/Capsaicin` のワークフローや秘密情報の変更、tap に Capsaicin へ書き込む権限を渡すこと、オーナーの承認なしの GitHub リポジトリの作成と push。

## 完了条件

- `brew style` と `brew audit --cask --online --strict`（新規の Cask として `--new` も）が、手元の tap で通る。
- 更新のワークフローが、版が最新のときは何も変えず、古い版から始めたときは最新の版と正しい `sha256` に書き換えることを、手元か GitHub Actions で確かめる。
- オーナーが承認した後、`koutyuke/homebrew-tap` が公開され、tap の CI が通る。

## 検証

- 手元: `brew tap` で `../homebrew-tap` を一時的に tap し、`brew style koutyuke/tap/capsaicin` と `brew audit --cask --online --strict --new koutyuke/tap/capsaicin` を実行する。終わったら `brew untap` する。tap とその取り消しは、オーナーの承認を得てから行う。
- `brew install --cask` による実際のインストールは、アプリとヘルパーの状態を変えるので、エージェントは行わない。`TASK-131` でオーナーが確かめる。

## レビュー

まだない。
