---
schema: task
id: TASK-085
title: AGENTS.md、リリースの手順書、PR のテンプレートを新しい運用に合わせる
status: done
requirements: []
depends_on: []
assignee: 実装者（Codex、OpenCode の openai/gpt-5.6-sol）
---

# TASK-085 AGENTS.md、リリースの手順書、PR のテンプレートを新しい運用に合わせる

## 目的

`DEC-SYS-014` と `DEC-SYS-015` に合わせて、エージェントとオーナーが読む文書を更新する。

## 範囲

- `AGENTS.md`（`CLAUDE.md` はこのファイルへの symlink なので触らない）
- `docs/manual/release.md`（書き直す）
- `.github/pull_request_template.md`（新規）

判断の文書（`docs/meta/decisions/`）、README、ワークフロー、スクリプトは触らない。

## 作るもの

- `AGENTS.md`
  - 「作業の進め方」の、共有するブランチは `main` だけで PR を使わないという記述と、リリースはオーナーだけが行うという記述を、次に置き換える。ブランチの規則は `DEC-SYS-014` を参照させ、本文に繰り返さない。
    - コミットは PM の指示があるときだけ行う（今のまま）。
    - チケットで指示されたときは、作業ブランチを push し、`develop` への PR を作ってよい。`main`、`develop`、`release/*`、`hotfix/*` への push と、タグの作成と push はしない。マージはオーナーだけが行う。
    - リリースの準備は、スキル `capsaicin-release` で行う。push と PR の作成は、オーナーの承認を得てから行う。
  - 「検証」のレシピの表に `prepare-release` を足す。説明は「`develop`（`patch` なら `hotfix/*`）から、版を上げたリリース用のコミットを手元に作り、材料を `.build/release/` に書き出す。push はしない」。
- `docs/manual/release.md`
  - オーナーが読む手順書にする。規則（ブランチ、版の決め方、ラベル）は `DEC-SYS-014` と `DEC-SYS-015` を参照させ、繰り返さない。
  - 節は、前提（`HYP-HLP-003` と、流れを試すときは `0.0.x` を使うこと）、通常のリリース、緊急の修正、戻しマージ、失敗したとき、の順にする。
  - 通常のリリース: スキル `capsaicin-release` を使う → 版と本文を確かめて push と PR の作成を承認する → PR のコメントにある確認用のビルドを実機で確かめる → 本文を直してマージする → 公開されたことと添付ファイルを確かめる → `gh attestation verify` で確かめる → 戻しマージ。
  - 緊急の修正: `main` から `hotfix/<内容>` を切って直す → スキル `capsaicin-release` を `patch` で使う → 以下は通常のリリースと同じ。
  - 戻しマージ: `develop` に `origin/main` を merge commit で取り込んで push する。`release/*` が開いていれば、そこにも `origin/main` を取り込む。`project.yml` の版の行が競合したら、取り込む側（`develop` と `release/*`）の版を採る。
  - 失敗したとき: ランナーの一時的な不調なら再実行する。コードを直す必要があれば、`v*` のタグは削除も更新もできないので、次の PATCH を出す。公開済みのリリースは immutable なので添付ファイルを差し替えられない。
- `.github/pull_request_template.md`
  - 英語と日本語を併記する（Issue のテンプレートに合わせる）。短くする。
  - 節は「概要 / Summary」「関連 / Related」（Issue や `TASK-*`）「確認したこと / Verification」。
  - 末尾に HTML コメントで、種類のラベル（`T-*`）を1つ付けること、互換性のない変更には `I-Breaking` を付けることを書く。

## 守ること

- `docs/documentation-management.md` の「書き方」に従う。文体は常体にする（PR のテンプレートを除く）。
- 推敲には `~/.claude/skills/yomiyasu/SKILL.md` のスキルに従う。
- `AGENTS.md` の他の節は、上の変更に必要な範囲を超えて書き換えない。

## 完了条件

- `nix develop --command just check` が通る。
- 書いた手順の各段階が、`DEC-SYS-014` と `DEC-SYS-015` の内容と食い違っていないことを、報告で対応付けて示す。

## 検証

上のコマンドの結果と、差分の確認。

## レビュー

- PM が差分を読んで確かめた。規則は `DEC-SYS-014`、`DEC-SYS-015` を参照し、繰り返していない。指摘なし。
- `release.md` は yomiyasu の推敲で「版」を「バージョン」と書いている。意味は同じなので受け入れた。
- 全体の検証: `nix develop --command just check` と actionlint が通った（2026-11-15）。
