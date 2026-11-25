---
schema: evidence
id: EVID-HLP-014
title: 製品のビルドで抑止中のアプリを SIGKILL で終了させると、デーモンが切断を受けて off を実行し、アプリは起動し直されなかった
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、Xcode 27.2（27B52）。`feature/smappservice` の `fa4bc85` の Debug ビルドを `just sign-debug` で Developer ID Application の証明書で署名し直した。電源アダプターに接続
sources: ["fa4bc85:docs/manual/verification/app-crash-cleanup.md", "~/Capsaicin-verification.2CTPup/result-app-crash-cleanup.txt", "~/Capsaicin-verification.2CTPup/log.app-crash.txt"]
---

# EVID-HLP-014 製品のビルドで抑止中のアプリを SIGKILL で終了させると、デーモンが切断を受けて off を実行し、アプリは起動し直されなかった

## 確かめた事実

「ディスプレイを閉じたとき」を「オンのまま」にし、ヘルパーを「有効」にして抑止を始めた。1回だけ試した。

1. 抑止中は `SleepDisabled 1` で、35 秒待つ前後でデーモンの PID（70107）は同じだった。役目のないデーモンが 30 秒で終了する仕組みに対して、接続を保つ間はデーモンが動き続けた。
2. 07:15:54 にアプリ（PID 67105）に `kill -9` を送った。同じ時刻にデーモンが `Helper disconnect cleanup succeeded: peer_pid=67105` を記録した。
3. 5 秒後は `SleepDisabled 0` で、Capsaicin のプロセスとアサーションはなかった。アプリは自動では起動しなかった。
4. 手で起動すると、メニューには「スリープ防止をオンにする」が出て、`SleepDisabled 0` のまま、アサーションもなかった。抑止は再開しなかった。

## 確かめ方

`docs/manual/verification/app-crash-cleanup.md`（`fa4bc85`）の手順で、PID、実行ファイル、`SleepDisabled`、アサーション、デーモンのログを読んだ。メニューの表示はオーナーが目で確かめた。

## 適用範囲

製品の実装で、ヘルパーの登録と許可が残っている場合の `SIGKILL` に当てはまる。試作で確かめた `SIGSEGV` の場合は `EVID-HLP-010` にある。

## 未確認のこと

- 製品のビルドでの `SIGSEGV` などクラッシュによる終了。
- LED の残り方（この確認では「スリープ防止中にCaps LockのLEDを点灯」をオフにした）。
