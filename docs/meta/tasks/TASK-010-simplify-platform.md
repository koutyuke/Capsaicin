---
schema: task
id: TASK-010
title: Platform・通信路・保存の実装を簡素にする
status: done
requirements: []
depends_on: [TASK-004, TASK-005, TASK-007, TASK-008]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-010 Platform・通信路・保存の実装を簡素にする

## 目的

TASK-004・005・007・008 の実装は動くが、起こりにくい競合への防御を重ねすぎていて、読み手が一度で理解できない。仕様が求める振る舞いを保ったまま、標準の手段で書き直す。

判断の基準は `CLAUDE.md` と同じで、KISS と YAGNI を優先する。

- 同じ UID の悪意あるプロセスは脅威の対象にしない。利用者の領域に書けるプロセスは、どのみち何でもできるためである。
- PID の再利用、アサーション ID の再利用、FIFO の差し替えなどへの防御は入れない。
- 守るのは、信頼境界での検証（IPC の相手の uid、受け取る大きさの上限、JSON の検証）と、期限（タイムアウト）である。

## 範囲と作業の分け方

3つの作業は、変更するファイルが重ならないので並行で進める。各担当は自分の範囲の外を変更しない。

### A. 電源・LED（`Packages/CapsaicinKit/Sources/CapsaicinPlatform/Power/`、`LED/`、新設の `Process/` と、それぞれのテスト）

1. `Process/CommandRunner.swift` を新設する。Foundation の `Process` を使い、次を満たす。
   - 実行ファイルの固定パス、固定の引数、空の環境変数で動かす。標準入力と標準エラー出力は捨てる。標準出力は、上限つきで返せるようにする（`pmset -g` の読み取りに使う）。
   - `run(timeout:)` は、終了まで同期で待つ。期限を過ぎたら throw する。期限を過ぎても子プロセスは止めず、終わるまでの間に来た `run` は、子プロセスを起動せずに throw する（`SPEC-HLP-005` の期限と見届けの規則）。
   - 状態はロックで守り、どのスレッドから呼んでもよい。
2. `DisplaySleep.swift` と `DisplaySleepProcess.swift` を消し、`CommandRunner` で `/usr/bin/pmset displaysleepnow` を 2 秒の期限で実行する小さな型に置き換える。`posix_spawn`、`waitpid`、シグナルの送信、SIGCHLD の検査は使わない。
3. `PowerAssertions` は `[AssertionKind: IOPMAssertionID]` だけを持つ。作成と解放は冪等にする（作ってある種類の作成と、作っていない種類の解放は何もせずに成功）。解放に失敗したら辞書に残して throw する。アサーションの名前は固定の文字列にする。プロパティを読み直しての照合はしない。
4. `KarabinerElementsMonitor` は、`proc_listpids` と `proc_pidpath` で既知の実行ファイルのパスを探すだけにする。状態は `Bool`（起動している／していない）にし、検出に失敗したら起動していないとみなしてログに残す。uid の照合や PID の再利用の確認はしない。5 秒ごとの確認と、変化したときの通知は残す。
5. ほかのファイル（`LidSleepControl`、`LidStateMonitor`、`PowerStateMonitor`、`PowerSnapshot`、`BootTimeProvider`、`CapsLockLEDController`、`HIDKeyboardMonitor`）は、同じ基準で明らかに過剰なところがあれば削る。なければ触らない。

### B. 通信路と CLI（`Packages/CapsaicinKit/Sources/CapsaicinIPC/Transport/`、`Sources/capsaicin-cli/`、それぞれのテスト）

1. 通信路を、ブロッキングのソケットと短い期限で書き直す。1つの接続で、要求1つと応答1つをやりとりする。
   - サーバーは、`0700` のディレクトリにソケットを置き、バックグラウンドのスレッドで `accept` する。前のプロセスの古いソケットが残っていたら、接続できないことを確かめてから消す。
   - 接続ごとに `getpeereid` で uid を照合し、違えば何も返さずに閉じる。`SO_RCVTIMEO` と `SO_SNDTIMEO` で期限を付け、相手が書き込みを閉じるまで、上限（64 KiB）まで読む。
   - 要求を検証して、メインスレッドの処理に渡し、応答を書いて閉じる。
   - クライアントは、接続し、書き、書き込みを閉じ、期限つきで応答を読む。
   - `DispatchSource` による状態機械、自前のフレームの形式、`flock` は使わない。
   - 既存の `IPCCoding`（バージョンの検証を含む）はそのまま使う。
2. CLI（`CLIRunner`、`CLIOutput`、`CLIApplication`、`CLISystem`）は、新しい通信路に合わせる。同じ基準で明らかに過剰なところがあれば削る。
3. CLI のテストは、アプリのテストのターゲットにある（`Tests/CapsaicinTests/CLI/`）。合わせて直す。

### C. 記録の保存（`Packages/CapsaicinKit/Sources/CapsaicinPlatform/Lifecycle/FileResumeRecordStore.swift` とそのテスト）

1. 書くときは `Data.write(to:options: .atomic)` で書き、ファイルの権限を `0600` にする。ディレクトリは `FileManager` で作る。
2. 読むときは `Data(contentsOf:)` で読んで decode する。ファイルがなければ nil を返し、ログには残さない。それ以外の失敗は、ログに残して nil を返す（ポートのコメントのとおり）。
3. `openat`、`fstat`、`O_NOFOLLOW` による検証と、bundle ID の文字の検査は消す。

## 守ること

- `AGENTS.md` の「破ってはいけないもの」を守る。テストで、アサーションの作成、`pmset` の実行、LED への書き込み、`launchctl` を行わない。`CommandRunner` のテストは `/bin/sleep` や `/bin/echo` のような無害なコマンドで行う。
- 消した防御を確かめていたテストは消す。残す振る舞い（冪等性、期限、uid の照合、大きさの上限、バージョンの検証、古いソケットの扱い、記録の往復と権限）には、テストを残すか書く。テスト名には仕様の ID を含める。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。
- `git commit` などの git の状態変更をしない。

## 完了条件

- 上の各項目を満たし、各担当が自分の範囲のテストを通している。
- PM が `nix develop --command just check` と `nix develop --command just build` を通す。

## 検証

- A・C: `nix develop --command just test-package`
- B: `nix develop --command just test-package` と `nix develop --command just test-app`
- 同じ作業ツリーで並行して動くので、SwiftPM のロック待ちが起きることがある。待てばよい。

## レビュー

PM が差分を読んでレビューした。

- A: 画面を消す処理 327 行を `CommandRunner`（72 行）と 19 行の型に、`PowerAssertions` を 48 行に、Karabiner-Elements の検出を 118 行（2ファイル）にした。`CommandRunner` が見届けに GCD の共有スレッドを使い、同期で待つ呼び出しが重なるとスレッドが尽きて期限切れになる不具合があったので、PM が専用のスレッドに直した。
- B: 通信路を約 1000 行から 363 行のブロッキングの実装にした。目安の 300 行は超えたが、期限と停止の扱いが読める形なので受け入れた。期限どおりにサーバーが閉じると EPIPE になるテストの競合を、PM が直した。
- C: 記録の保存を 209 行から 51 行にした。
- 文書: Codex が PM だった間に足した、操作結果が不明なアサーションの扱い（判断と根拠、受け入れ例）を、安全ゲートと同じ理由で取り下げた。
- `just check` と `just build` が通り、パッケージのテストを続けて2回実行して安定していることを確かめた。
