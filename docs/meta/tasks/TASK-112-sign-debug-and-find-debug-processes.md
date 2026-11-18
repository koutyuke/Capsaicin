---
schema: task
id: TASK-112
title: 手元の Debug ビルドを署名し直すレシピを足し、app グループのレシピが Debug のプロセスを実行ファイルの絶対パスで見つけるようにする
status: in_review
requirements: []
depends_on: []
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-112 手元の Debug ビルドを署名し直すレシピを足し、app グループのレシピが Debug のプロセスを実行ファイルの絶対パスで見つけるようにする

## 目的

手元の `just start` が動かない（`EVID-LCY-004`）。原因は2つある。

1. ad-hoc 署名の手元のビルドの agent は、PR の公証したビルドが作った BTM の項目が残る間、launchd が起動の制約で止める。同じ Team ID で署名し直すと起動する。
2. agent の定義は `BundleProgram` なので、agent から起動したアプリのコマンドラインは相対パスの `Contents/MacOS/Capsaicin` になる。`justfile` の `debug_process` はコマンドラインを `pgrep -f` で照らすので、動いているアプリを見つけられない。`start` は `launchctl print` の `program` で照らしていて、空のパスで失敗する。

`DEC-SYS-025` に従って直す。必ず読む: `DEC-SYS-025`、`EVID-LCY-004`、`DEC-SYS-024`、`docs/manual/verification/README.md` の「手順書を書くときの決まり」。

## 範囲

変更してよいもの: `justfile`、`AGENTS.md`（レシピの表と、その直前の段落）、`docs/manual/verification/README.md`、`docs/manual/verification/prepare.md`、`docs/manual/verification/debug-agent-worktree-switch.md`。`just status` の出力の形を変えた場合は、その出力を期待に書いている `docs/manual/verification/` のほかのファイルも直してよい。

触らないもの: `Sources/`、`Packages/`、`project.yml`、`.github/`、ほかの `docs/`。

## やること

1. `sign-debug` のレシピを足す。引数で証明書の名前を受け取り、既定は `Apple Development` にする。このチェックアウトの `.build/xcode/Build/Products/Debug/Capsaicin.app` がなければ失敗する。内側の実行コード（`Contents/Helpers` の実行ファイル、`Contents/MacOS` の dylib、`Contents/Frameworks` のフレームワークとその中の XPC サービス・アプリ・実行ファイル、そのほかバンドル内の Mach-O）から順に、最後にアプリ本体を `codesign --force --timestamp=none --preserve-metadata=identifier,entitlements,flags --sign "$identity"` で署名し直す。`--deep` は使わない。最後に `codesign --verify --strict --deep` で確かめ、`codesign -dv` の `Identifier` と `TeamIdentifier` を表示する。リリースのワークフロー（`.github/workflows/sign-and-notarize.yml`）の順序を参考にしてよい。コメントは日本語、出力は英語。`[group('app')]` には入れない。説明の行で、オーナーのキーチェーンの鍵を使うことを示す。
2. `debug_process` によるコマンドラインの照合をやめる。Debug のプロセスは、PID から実行ファイルの絶対パスを引いて照らす（例: `pgrep -x Capsaicin` で候補を出し、`/usr/sbin/lsof -a -p <PID> -d txt -Fn` の最初の `n` 行を読む。ほかに確実な方法があってもよい）。対象は、これまでと同じく、どのチェックアウトの `.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/MacOS/Capsaicin` にも一致する絶対パスとする。`/Applications` の PR のビルドと Release は対象にしない。`start`、`stop`、`status` で同じ関数か同じ書き方を使う。
3. `status`: ジョブの `state` と `pid` を表示し、ジョブの `pid` のプロセスの実行ファイルの絶対パスを表示する。`Job matches this checkout:` は、その絶対パスとこのチェックアウトの実行ファイルが一致するかで `yes`、`no` を出す。ジョブが動いていないときは、どのチェックアウトか判断できないことを示す（例: `Job matches this checkout: unknown (job is not running)`）。プロセスの一覧は、PID、開始時刻、PPID、実行ファイルの絶対パスを出す。
4. `start`: 事前の確認を 2 の方法にする。アプリを開いた後は、このチェックアウトの実行ファイルで動き、PPID が 1 のプロセスを最大 10 秒待つ。`launchctl print` の `program` には頼らない。見つかったら `Started Debug PID <PID>: <絶対パス>` を出す。見つからなければ失敗し、ad-hoc 署名のビルドは同じ bundle ID の Team ID 付きのビルドが登録した agent を起動できないこと、`just sign-debug` で署名し直すこと、`/usr/bin/log show --last 5m --predicate 'process == "launchd"' | grep 'Launch Constraint Violation'` のような確かめ方を、英語の短い文で示す。アプリが agent の起動を確かめられずに直接動き続けている場合（`DEC-LCY-009` を実装した後の振る舞い）も、失敗として扱い、そのことを示す。
5. `stop`: 2 の方法で見つけたプロセスを対象にする。ほかは変えない。
6. `AGENTS.md`: レシピの表に `sign-debug` を足し、`start` と `status` の説明を直す。表の直前の段落の「ad-hoc 署名のビルドではヘルパーを使えない。ヘルパーとログイン時の起動の実機での確認は、PR の Debug ビルド…で行う」を、`DEC-SYS-025` に合わせて直す（手元では `just sign-debug` で署名し直せば確かめられる）。表の列幅は既存の整形に合わせる。
7. 手順書:
   - `prepare.md`: 手元のビルドで agent やヘルパーを確かめるときは、`just build` の後に `just sign-debug` を行うこと。`/Applications` の PR のビルドと手元のビルドは bundle ID が同じで、BTM の agent の項目を共有すること。手元のビルドを使う前に PR のビルドを止めること。
   - `debug-agent-worktree-switch.md`: 2つの worktree のビルドの両方を `just sign-debug` で署名し直す手順を足す。判定を `program` から、`just status` が出すジョブのプロセスの絶対パスに変える。手順 2 の「`program` は1つ目のパスのまま」のように、ジョブが止まっている間の起動先を読む期待は、読めないものとして直す。`just start` が失敗したときの切り分け（`Launch Constraint Violation` をログで探す）を書く。「ad-hoc 署名のビルドを使ってよい」は削る。
   - `README.md`: `just status` の説明、「つまずいたときの切り分け」の表に、`just start` の失敗と `Launch Constraint Violation` の行を足す。
   - 書き方は README の決まりに従う（1つのファイルで完結、名前は実装から引く、コマンドを省略しない）。

## 守ること

- `AGENTS.md` を読んでから始める。`just start`、`just stop`、`just status`、`just restart`、`just sign-debug`、`launchctl`、`codesign` の署名を実行しない（オーナーのアプリが動いている）。読み取りのための `codesign -dv` と `lsof`、`ps` は実行してよい。
- 日本語は `~/.claude/skills/yomiyasu/SKILL.md` に従って推敲する。「蓋」という語は使わない。
- `git commit` と `git push` をしない。

## 完了条件

- 1〜7 を満たす。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just check`
- `just --list` で `sign-debug` が表示され、`app` グループには入っていないこと。
- `bash -n` 相当の確認として、`just --show start`、`just --show status`、`just --show stop`、`just --show sign-debug` の本文をレビューに貼る。
- PID 17649 など、いま動いている Debug アプリについて、2 の方法が絶対パスを返すことを、`lsof` の読み取りだけで確かめて報告する（レシピは実行しない）。
- 実機（オーナー）: `just build`、`just sign-debug`、`just stop`、`just start`、`just status`。

## レビュー

PM がレビューした。`sign-debug` は内側の Mach-O とバンドルを深い順に署名し、最後にアプリを署名して検査する。`start`、`stop`、`status` は `pgrep -x` の候補を `lsof` の実行ファイルの絶対パスで絞る。`start` はジョブの PID の実行ファイルと PPID 1 を待ち、失敗時に署名し直しとログの確かめ方を示す。PM が2点を直した。3つのレシピに複製されていたプロセスを探す関数を `scripts/debug-app.sh` にまとめ、`sign-debug` の対象に `*.bundle` を加えた。手順書は README の決まりに沿う。`just check` は通る。レシピは実機で一度も実行していない。
