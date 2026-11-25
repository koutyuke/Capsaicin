---
schema: evidence
id: EVID-HLP-015
title: 製品のビルドで抑止中にデーモンを SIGKILL で終了させると、新しいデーモンが後片付けの役目を持ち、続くアプリの終了で off を実行した
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、Xcode 27.2（27B52）。`feature/smappservice` の `fa4bc85` の Debug ビルドを `just sign-debug` で Developer ID Application の証明書で署名し直した。電源アダプターに接続
sources: ["fa4bc85:docs/manual/verification/daemon-restart-resend.md"]
---

# EVID-HLP-015 製品のビルドで抑止中にデーモンを SIGKILL で終了させると、新しいデーモンが後片付けの役目を持ち、続くアプリの終了で off を実行した

## 確かめた事実

「ディスプレイを閉じたとき」を「オンのまま」にし、ヘルパーを「有効」にして抑止を始めた。1回だけ試した。

1. 07:17:19 に、オーナーがデーモン（PID 72695）に `sudo kill -9` を送った。送る前に、PID が Debug のデーモンのもので、実行ファイルがアプリの `Contents/Helpers/capsaicin-helper` であることを確かめた。
2. 新しいデーモン（PID 74132）が起動し、35 秒を超えて同じ PID のまま動き続けた。役目のないデーモンは 30 秒で終了するので、新しいデーモンが役目を持っていたことを示す。アプリ（PID 72206）の PID、開始時刻、実行ファイルは変わらず、`SleepDisabled 1` のままだった。
3. 07:18:24 にアプリに `kill -9` を送った。新しいデーモンが同じ時刻に `Helper disconnect cleanup succeeded: peer_pid=72206` を記録した。このログは `on` を受けた接続が切れたときだけ出る。
4. その後は `SleepDisabled 0` で、Capsaicin のプロセスとアサーションはなかった。

## 確かめ方

`docs/manual/verification/daemon-restart-resend.md`（`fa4bc85`）の手順で、シグナルを送る前後に PID、実行ファイル、`SleepDisabled`、デーモンのログを読んだ。

## 適用範囲

製品の実装で、デーモンが `SIGKILL` で終了し、ヘルパーの登録と許可が残っている（`enabled`）場合に当てはまる。

## 未確認のこと

- 中断から `on` を送り直すまでの時間。製品はこの区間をログに残さないため測っていない。試作では約 37 ミリ秒だった（`EVID-HLP-013`）。
- デーモンが繰り返し落ちる場合と、送り直しが失敗した後の合わせ直し。
