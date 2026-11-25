---
schema: task
id: TASK-130
title: Homebrew の tap koutyuke/homebrew-tap と Cask capsaicin を作る
status: in_review
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

- `brew style` と `brew audit --cask --online --strict` が、tap の CI で通る。
- 更新のワークフローが、版が最新のときは何も変えず、新しい版が出たときは最新の版と正しい `sha256` に書き換えて `main` に push する。
- オーナーが承認した後、`koutyuke/homebrew-tap` が公開され、tap の CI が通る。

## 検証

- オーナーの判断で、手元の Homebrew に tap を登録する確認はせず、公開した後に tap の CI で `brew style` と `brew audit` を確かめる。
- `brew install --cask` による実際のインストールは、アプリとヘルパーの状態を変えるので、エージェントは行わない。`TASK-131` でオーナーが確かめる。

## レビュー

2026-11-26 の結果（PM の自己確認。オーナーのレビューはまだ）:

- オーナーの承認を得て `koutyuke/homebrew-tap` を公開した。`main` は 4bc317d（Cask、ワークフロー、README、LICENSE）と c8cfce3（更新を `main` だけで動かし、push 先を `HEAD:main` にする）である。
- CI は 4bc317d（run 45655906728）でも c8cfce3（run 45656354099）でも成功した。`brew style koutyuke/tap` に指摘はなく、`brew audit --cask --online --strict koutyuke/tap/capsaicin` は DMG をダウンロードして展開したうえでエラーなく終わった。`--new` は公式 Cask への新規掲載の検査なので使っていない。
- Update cask を手動で実行した（run 45656366085）。`brew livecheck` は appcast から `current 0.2.0`、`latest 0.2.0`、`outdated false` を返し、DMG の確認と書き換えの手順は動かなかった。
- 書き換えの手順の `sed` は、手元の一時コピーで版を 0.1.0、`sha256` を 0 にした Cask を、0.2.0 の版と `sha256` に戻し、元の Cask と一致した。`gh attestation verify --signer-workflow koutyuke/Capsaicin/.github/workflows/release.yml` は v0.2.0 の DMG で通った（`EVID-SYS-010`）。ワークフローは actionlint（ShellCheck を含む）を通った。
- 確かめていないこと: 新しい版が出たときに、ワークフローが書き換え、`brew style` と `brew audit` を通し、`gh auth setup-git` で `main` に push するまでの一連の流れ。次のリリースの後に、Update cask の実行で確かめる。
