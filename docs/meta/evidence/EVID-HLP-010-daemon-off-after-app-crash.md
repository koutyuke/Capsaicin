---
schema: evidence
id: EVID-HLP-010
title: 抑止中のアプリを SIGKILL か SIGSEGV で終了させると、接続を保つデーモンが切断を受けて off を実行し、1秒以内に SleepDisabled が 0 に戻った
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）。デーモンによる後片付けの試作を標準の Debug のヘルパーのラベル（`io.github.koutyuke.capsaicin.debug.helper`）でビルドし、Developer ID Application で署名した
sources: ["docs/meta/hypotheses/HYP-HLP-008-daemon-cleans-up-on-app-disconnect.md", "7528138:docs/meta/tasks/TASK-114-daemon-cleanup-probe.md"]
---

# EVID-HLP-010 抑止中のアプリを SIGKILL か SIGSEGV で終了させると、接続を保つデーモンが切断を受けて off を実行し、1秒以内に SleepDisabled が 0 に戻った

## 確かめた事実

オーナーが、ヘルパーを登録して許可した試作で抑止を始め、アプリに `kill -9` を2回、`kill -SEGV` を1回送った。PM がデーモンのログ、`pmset -g`、`pmset -g assertions`、プロセスを読んだ。

| 試行 | アプリの PID | デーモンの PID | 役目を持った時刻 | シグナルの送信 | アプリの不在を観測 | `Disconnect cleanup off: success=true` |
| --- | --- | --- | --- | --- | --- | --- |
| `SIGKILL` 1回目 | 17372 | 18670 | 01:00:28.037 | 01:02:21 | 01:02:22.007 | 01:02:21.966 |
| `SIGKILL` 2回目 | 25098 | 31583 | 01:13:07.310 | 01:14:12 | 01:14:12.312 | 01:14:12.341 |
| `SIGSEGV` | 36201 | 37205 | 01:18:09.662 | 01:19:48 | 01:19:48.259 | 01:19:48.290 |

- どの試行でも、デーモンは役目を持ってからシグナルまで（65〜113 秒）同じ PID で動き続け、`Idle exit` を出さなかった。その間 `SleepDisabled` は 1 だった。
- どの試行でも、`Disconnect cleanup off: success=true` の直後に `Cleanup responsibility released: peer_pid=<アプリの PID>` が出た。試作は、役目を持つ接続で `XPC_ERROR_CONNECTION_INVALID` を受けた経路でだけ前者を出す。
- 終了の約1秒後と約5秒後の `pmset -g` は、どの試行でも `SleepDisabled 0` だった。Capsaicin のプロセスとアサーションはなく、アプリは再起動しなかった。
- `SIGSEGV` でも、アプリの不在の観測から `off` まで約 31 ミリ秒で、クラッシュの報告の処理による遅れは見えなかった。
- 役目を手放した後は、アイドルの時間でデーモンが終了した。その後にアプリが `on` を送ると、launchd が新しいデーモンを起動し、新しい PID が役目を持った（2回目の `SIGKILL` の前の 27102 → 28839 → 31583）。

## 確かめ方

`docs/manual/verification/app-crash-daemon-cleanup.md`（`b107708`）の手順で、各試行の前に役目の取得、デーモンの PID、`SleepDisabled 1` を確かめ、シグナルの後に1秒と5秒で読んだ。

## 適用範囲

接続を保ったまま `on` を送ったアプリが、`SIGKILL` か `SIGSEGV` で終了した場合に当てはまる。デーモンが動いていることが前提で、デーモン自身の終了や、システム設定で許可を外した場合（`HYP-HLP-009`）は含まない。

## 未確認のこと

- 同時に複数のアプリの個体が接続している場合の役目の扱い。
- スリープからの復帰の直後など、XPC の切断の通知が遅れうる状況。
