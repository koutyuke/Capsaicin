---
schema: task
id: TASK-084
title: main へのリリース用の PR で確認用のビルドを配り、マージで公開する
status: done
requirements: []
depends_on: []
assignee: 実装者（Codex、OpenCode の openai/gpt-5.6-sol）
---

# TASK-084 main へのリリース用の PR で確認用のビルドを配り、マージで公開する

## 目的

`DEC-SYS-015` の「リリース」を、`.github/workflows/release.yml` に反映する。タグの push で動く今の形をやめる。

## 範囲

- `.github/workflows/release.yml`（書き直す）

`ci.yml` と `pr-policy.yml` は `TASK-082` が書くので触らない。`release.yml` は `ci.yml` を呼ばなくなる。

## 作るもの

トリガーは `main` への `pull_request`（`opened`、`reopened`、`synchronize`、`closed`）にする。どのジョブも、head が同じリポジトリの `release/v*` か `hotfix/*` のときだけ動かす。トップレベルの権限は `{}` にし、ジョブごとに必要なものだけを与える。

- **確認用のビルド**（`closed` 以外）: `xcode-27` で、既存の `.github/actions/build-tools` を使い、Xcode 27.2 を選び、`just --evaluate version` で版を読み、`just dist` を実行する。zip と `SHA256SUMS.txt` を artifact としてアップロードする（保持は7日）。同じ PR の古い実行は取り消す。
- **確認用のビルドのコメント**: Ubuntu のジョブで、`pull-requests: write` だけを持つ。PR に、artifact のダウンロード先、ビルドしたコミット、ad-hoc 署名であることを書いたコメントを1つだけ置く。目印の HTML コメントで既存のコメントを探し、あれば書き換える。
- **公開**（`closed` かつマージ済み）:
  1. `xcode-27` で、マージのコミット（`pull_request.merge_commit_sha`）をチェックアウトし、版を読み、`v{版}` のタグがまだないことを確かめ、`just dist` を実行して artifact に上げる。
  2. Ubuntu のジョブで、artifact を取り、zip に `actions/attest-build-provenance` で attestation を付ける。PR の本文をファイルに書き出してリリースノートにし、`gh release create v{版}` でマージのコミットを指して作る。タイトルは `Capsaicin {版}`、版が 1.0.0 未満なら `--prerelease` を付ける。zip と `SHA256SUMS.txt` を添付する。権限は `contents: write`、`id-token: write`、`attestations: write`。PR の本文が空なら止める。
  3. 公開のジョブは取り消さない。

ファイルの先頭のコメントの参照は、`DEC-SYS-015` と `docs/manual/release.md` にする。

## 守ること

- PR のタイトル、本文、ブランチ名など、PR の作り手が決められる値を、`run:` の中に `${{ }}` で直接埋め込まない。`env:` で渡してから使う。本文は環境変数からファイルに書く。
- 既存の Action（checkout、upload-artifact、download-artifact、attest-build-provenance）は、今の `release.yml` と同じ SHA を使う。新しい Action を足すなら SHA で固定し、版をコメントで添える。コメントの作成と更新は `gh api` で書けるなら Action を足さない。
- GitHub のリリースは immutable である。添付ファイルは公開の前にそろえる（`gh release create` に添付ファイルを渡せば、下書きにアップロードしてから公開する。今の `release.yml` でも動いている）。
- 起こりにくい場面への防御を重ねない。

## 完了条件

- `nix develop --command just check` が通る。
- actionlint が通る（`nix shell nixpkgs#actionlint --command actionlint`）。
- 報告に、イベントごとに動くジョブと、各ジョブの権限を書く。`pull_request` の `closed` のイベントで `GITHUB_SHA` と `merge_commit_sha` のどちらを使うべきかを、GitHub の公式ドキュメントで確かめた結果と URL も書く。

## 検証

上のコマンドの結果と、差分の確認。実際の動作は、切り替えの後に `0.0.x` の版で確かめる（`DEC-SYS-014`）。

## レビュー

- PM が差分を読んで確かめた。公開は `merge_commit_sha` を対象にし、PR の本文は環境変数からファイルに書いている。書き込みの権限は必要なジョブだけにある。指摘なし。
- 実際の動作は、切り替えの後に `0.0.x` の版で確かめる。
- 全体の検証: `nix develop --command just check` と actionlint が通った（2026-11-15）。
