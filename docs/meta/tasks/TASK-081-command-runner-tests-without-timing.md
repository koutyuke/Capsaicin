---
schema: task
id: TASK-081
title: CommandRunner を使うテストを、時間の差に頼らない形にする
status: done
requirements: ["REQ-HLP-002", "REQ-BLK-003"]
depends_on: ["TASK-079"]
assignee: PM（Claude）
---

# TASK-081 CommandRunner を使うテストを、時間の差に頼らない形にする

## 目的

0.0.0 の版のコミットの CI で、`CommandRunnerTests` の2件が失敗した。テストを直し、混み合った CI でも結果が揺れないようにする。

## 原因

テストは、0.4 秒で終わる `/bin/sleep` と、0.02 秒の期限との差に頼って「実行中」を作っていた。CI のランナーは並列のテストで混み合い、スレッドの実行が秒単位で遅れることがある。そのため、期限を確かめる前に子が終わって成功が返る、1つ目が終わってから2つ目の呼び出しが届く、といったことが起きた。本番の `CommandRunner` が、期限が過ぎる前に終わった子の結果を成功として返すのは正しい。

## 範囲

- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/` の `Process/`（`CommandRunnerTests`、新しい `ProcessGate`）、`Helper/HelperSleepControllerTests.swift`、`Power/DisplaySleepCommandTests.swift`。本番のコードは変えない。

## 作るもの

- テストが開くまで終わらない子プロセス（`ProcessGate`）を用意し、「実行中」を時間の差ではなくテストの操作で作る。子は印のファイルを見つけると、それを消して終わる。テストが途中で失敗しても、`deinit` で開いて子を残さない。
- 同じ書き方の5件（`CommandRunnerTests` の3件、`HelperSleepControllerTests.sharedRunner`、`DisplaySleepCommandTests.deadline`）を書き換える。

## 完了条件

- `nix develop --command just check` が通る。
- `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` でもパッケージのテストがすべて通る。
- push の後、CI のすべてのジョブが成功する。

## 検証

通常の実行で3回、`LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` で3回、パッケージのテストがすべて通ることを確かめた。修正前は、`LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` で `CommandRunnerTests` と `DisplaySleepCommandTests` が失敗していた。テストの後に、子プロセスと印のファイルは残っていない。

## 範囲外で見つけたこと

`DisplaySleep.sleepDisplay()` は、`Task.detached` の中で `CommandRunner.run(timeout: 2)` を呼び、Swift の並行処理のスレッドプールのスレッドを最大2秒塞ぐ。`IPCServer` と `IPCClient` のように専用のスレッドに移すかは、別のチケットで扱う。
