---
schema: task
id: TASK-122
title: justfile の app レシピと debug-app.sh を、agent のない前提に合わせる
status: in_progress
requirements: []
depends_on: []
assignee: OpenCode openai/gpt-6.2-sol（high）
---

# TASK-122 justfile の app レシピと debug-app.sh を、agent のない前提に合わせる

## 目的

`DEC-LCY-010` で agent をやめ、`DEC-LCY-011` で同じ bundle ID のアプリを1つだけ動かすことにした。開発用の `just` の `app` グループ（`status`、`stop`、`start`、`restart`）と `scripts/debug-app.sh` は、agent のジョブを前提にしている。不要になったものを消し、必要なものを新しい前提で直す。

## 範囲

変更してよいもの: `justfile`、`scripts/debug-app.sh`（不要なら削除してよい）、`scripts/tests/`（テストを足す場合）、`docs/manual/verification/README.md` の `just` の app レシピの説明と、`docs/manual/verification/prepare.md`・`cleanup.md` のうちこれらのレシピの振る舞いを説明している箇所。

変更してはいけないもの: アプリ・CLI・ヘルパーのコード、`project.yml`、`AGENTS.md`、`docs/meta/`（判断の `DEC-SYS-024`、`DEC-SYS-026` と `AGENTS.md` の表は PM が直す）。直すべき箇所があれば報告する。

## 新しい前提

- アプリは agent から起動されない。直接開いたプロセスがそのまま動く。launchd の `gui/<uid>/io.github.koutyuke.capsaicin.debug` のジョブは使わない（開発機に古い登録が残っていても、レシピから `bootout` しない。片付けは `prepare.md` の手作業）。
- 同じ bundle ID のアプリがすでに動いていると、後から開いた方は動いている方を開き直して終了する（`SPEC-LCY-009`）。そのため、手元のビルドを `start` で開く前に、どこにあるコピーでも Debug の bundle ID（`io.github.koutyuke.capsaicin.debug`）のアプリが動いていないことを確かめる必要がある。PR の Debug ビルド（`/Applications` などに置いたもの）も同じ bundle ID なので対象に含める。Release（`io.github.koutyuke.capsaicin`）は含めない。
- ヘルパーのデーモンは引き続き Team ID のある署名が要るので、`sign-debug` は残す。コメントや説明に agent への言及があれば直す。

## やること

1. `status`: agent のジョブの節をなくす。Debug の bundle ID のすべてのプロセス（PID、開始時刻、実行ファイルの絶対パス、このチェックアウトのものか）と、`SleepDisabled`、Capsaicin のアサーションを読む。読み取りだけにする。
2. `stop`: Debug の bundle ID のすべてのプロセスを対象に、まず quit を送り、残ったものだけに `SIGTERM` を送る。同じ bundle ID のコピーが複数あっても、すべて止める。
3. `start`: Debug の bundle ID のプロセスが1つでも動いていたら、止めるよう促して失敗する。動いていなければ、このチェックアウトのビルドを開き、このチェックアウトの実行ファイルのプロセスが動き出したことを確かめて成功とする。`launchctl` は使わない。
4. `restart`: ビルドに成功してから `stop`、`start` の順に実行する、を保つ。
5. `scripts/debug-app.sh`: 上に必要な関数だけを残す（bundle ID でプロセスを見つける方法は、実行ファイルの絶対パスからバンドルの `Info.plist` の `CFBundleIdentifier` を読むなど、単純で確実な方法を選ぶ）。不要なら削除し、justfile に入れる。
6. レシピのメッセージは英語、コメントは日本語（`AGENTS.md`）。
7. `docs/manual/verification/README.md` の「`just` の app レシピ」の説明と、`prepare.md`・`cleanup.md` の該当箇所を、新しい振る舞いに合わせる。

## 完了条件

- 上の振る舞いになり、agent のジョブへの参照が justfile と `scripts/` に残っていない。
- `nix develop --command just check` が通る（ShellCheck と shfmt を含む）。
- 報告に、消したもの、残したもの、bundle ID でプロセスを見つける方法とその理由を書く。

## 検証

- `nix develop --command just check`
- `just --list` で `app` グループのレシピと説明を確かめる。
- `status`、`stop`、`start`、`restart` は実行しない（オーナーの承認が要る。`DEC-SYS-024`）。`sudo`、`launchctl`、`pmset` の設定変更をしない。

## レビュー

（PM が書く）
