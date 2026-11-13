---
schema: task
id: TASK-077
title: IPC のテストがスレッドプールを塞いで CI で止まる問題を直す
status: done
requirements: ["REQ-CLI-001", "REQ-CLI-007"]
depends_on: ["TASK-076"]
assignee: PM（Claude）
---

# TASK-077 IPC のテストがスレッドプールを塞いで CI で止まる問題を直す

## 目的

最初の CI（`xcode-27` ランナー）で、`just test-package` の `CapsaicinIPCTests` が1件も終わらないまま30分止まった。原因を直し、CI でテストが終わるようにする。

## 原因

`IPCClientWireTests` のテスト本体が、Swift の並行処理のスレッドプールの上で、ソケットの `accept` と `recv` を期限なしでブロックしたまま、クライアント側の `Task` が要求を送るのを待っていた。その `Task` もスレッドプールで動く。CI のランナーはコア数が少なくプールが小さいので、並列に走るテストケースがプールを使い切ると `Task` が始まらず、テストが終わらない。手元の開発機はコア数が多いので表に出なかった。

`LIBDISPATCH_COOPERATIVE_POOL_STRICT=1`（プールの幅を1にする）で手元でも再現し、修正前は 60 秒で1件も終わらず、修正後は `CapsaicinIPCTests` の 38 件が通ることを確かめた。

本番の `IPCServer` と `IPCClient` は、ブロックする処理を `Thread.detachNewThread`（`ipcBackground`）で専用のスレッドに逃がしているので、この問題はない。

## 範囲

- `Packages/CapsaicinKit/Tests/CapsaicinIPCTests/Transport/` のテストとフィクスチャだけ。本番のコードは変えない。

## 作るもの

- テストでも、相手の `Task` の進みを待つブロックするソケット操作は `ipcBackground` で専用のスレッドに移す。受け付けは `acceptRaw` にまとめる。
- `Task.detached` で行っていたブロックする読み書きも、プールを使う `Task.detached` ではなく `ipcBackground` で行う。

## 完了条件

- `nix develop --command just check` が通る。
- `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` で `CapsaicinIPCTests` が終わり、すべて通る。
- push の後、CI の `Check` が終わる。

## 検証

上のコマンドの結果。`LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` では `CapsaicinPlatformTests` の時間に依存する2件（`CommandRunnerTests`、`DisplaySleepCommandTests`）が失敗するが、止まりはせず、CI の3スレッドでは通っている。プールの幅を1にした条件は CI より厳しすぎるため、この検査は `just` のレシピに入れない。
