---
schema: evidence
id: EVID-HLP-013
title: 抑止中にデーモンを SIGKILL で終了させると、アプリは中断を受けて on を送り直し、launchd が起動した新しいデーモンが役目を持ち、アプリの終了で off を実行した
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）。試作 `spike/daemon-cleanup-probe` の `d76d393` を標準の Debug のヘルパーのラベルでビルドし、Developer ID Application で署名した。agent は登録していない
sources: ["docs/meta/hypotheses/HYP-HLP-010-app-reconnects-after-daemon-exit.md", "7528138:docs/meta/tasks/TASK-114-daemon-cleanup-probe.md"]
---

# EVID-HLP-013 抑止中にデーモンを SIGKILL で終了させると、アプリは中断を受けて on を送り直し、launchd が起動した新しいデーモンが役目を持ち、アプリの終了で off を実行した

## 確かめた事実

オーナーがヘルパーを登録して抑止を始め、デーモン（PID 91350、UID 0）がアプリ（PID 90413）の後片付けの役目を持ち、`SleepDisabled 1` になったことを確かめた。1回だけ試した。

1. 02:12:15 に、オーナーがデーモンの PID に `sudo kill -9` を送った。送る前に、PID が launchd の Debug のデーモンのもので、実行ファイルが試作の `Contents/Helpers/capsaicin-helper` であることを確かめた。
2. 02:12:15.942 に、アプリは `interrupted` を受けた。そのときの `SMAppService.daemon` の状態は `1`（`enabled`）だった。前後を約 0.3 秒間隔で読んだ `SleepDisabled` は 1 のままだった。
3. launchd は Mach サービスへの要求（`ipc (mach)`）で新しいデーモン（PID 92746、UID 0、同じ実行ファイル）を起動した。前の終了は `Killed: 9` と記録された。
4. 02:12:15.978 に新しいデーモンが同じアプリの役目を持ち、02:12:15.979 にアプリが `Helper reconnect on: success=true` を記録した。中断から約 37 ミリ秒で、失敗もタイムアウトもなかった。
5. 02:12:51.089 にアプリに `kill -9` を送ると、02:12:51.129 に新しいデーモンが `Disconnect cleanup off: success=true` と `Cleanup responsibility released: peer_pid=90413` を記録した。1秒後と5秒後は `SleepDisabled 0` で、Capsaicin のアサーションはなく、アプリは再起動しなかった。

生の記録は `/Users/koutyuke/Capsaicin-verification.DtxMpk/result-daemon-reconnect-cleanup.txt` と、同じ場所のログ・時系列・`lsof` の出力にある。

## 確かめ方

`docs/manual/verification/daemon-reconnect-cleanup.md`（`b107708`）の手順で、デーモンとアプリにシグナルを送る前後に PID、実行ファイル、`SleepDisabled`、試作のログを読んだ。

## 適用範囲

デーモンが `SIGKILL` で終了し、ヘルパーの登録と許可が残っている（状態が `enabled`）場合に当てはまる。許可を外した場合は `EVID-HLP-012` にある。

## 未確認のこと

- 中断から送り直しまでの約 37 ミリ秒の間にアプリも終了した場合。その間は役目を持つデーモンがいない。
- デーモンが繰り返し落ちる場合の送り直しの振る舞い。
