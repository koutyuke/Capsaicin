---
schema: evidence
id: EVID-HLP-017
title: 製品のビルドで、バックグラウンドの項目をオフにすると、抑止の有無・ヘルパーの使用・「ログイン時に起動」によらず、macOS がアプリを SIGTERM で終了させた
observed_on: 2026-11-20
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）。`feature/helper-intro-card`（`703c8b9`）の Debug ビルドを Developer ID Application の証明書で署名し直したもの
sources: ["~/Capsaicin-verification.jYD5Gl/stream.log", "~/Capsaicin-verification.jYD5Gl/quit.log", "~/Capsaicin-verification.jYD5Gl/btm-before.txt", "~/Capsaicin-verification.jYD5Gl/btm-A-before.txt", "~/Capsaicin-verification.jYD5Gl/btm-C-before.txt", "~/Capsaicin-verification.vaBwpy/btm.off.txt"]
---

# EVID-HLP-017 製品のビルドで、バックグラウンドの項目をオフにすると、抑止の有無・ヘルパーの使用・「ログイン時に起動」によらず、macOS がアプリを SIGTERM で終了させた

## 確かめた事実

オーナーがシステム設定の「一般 > ログイン項目と機能拡張」の「アプリのバックグラウンドでのアクティビティ」で、検証に使った worktree（`capsaicin-helper-intro-card`）の Debug の Capsaicin のスイッチをオフにした。アプリはエージェントが `just start` で起動した。4つの条件で試した。

| 回 | 条件 | 結果 |
| --- | --- | --- |
| A | 抑止なし | 18:24:31 に終了（PID 16283）。 |
| B1 | CLI の `on --no-time-limit` で抑止中。「ディスプレイを閉じたとき」は「Macをスリープ（標準）」でヘルパーを使わない | 18:27:43 に終了（PID 25231）。 |
| B2 | 「ディスプレイを閉じたとき」を「オンのまま」にし、CLI の `on --no-time-limit` で抑止中。`SleepDisabled 1`、デーモン（PID 39219）が動いていた。`EVID-HLP-016` と同じ条件 | 18:29:09 に終了（PID 36377）。デーモンは `Helper SIGTERM cleanup succeeded` を記録し、`SleepDisabled` は 0 になった。 |
| C | 抑止なし。「ログイン時に起動」をオフにし、UID 501 のアプリの記録が `[enabled, …]` から `[disabled, allowed, not notified]` に変わった後 | 18:54:27 に終了（PID 52718）。 |

どの回も、オフにした直後に loginwindow が `forceQuitAppWithURL` を記録し、続けて `Capsaicin [PID] force quit (caller responsible for termination)`、`calling back to client to terminate` を記録した。runningboardd はアプリの終了を `termination reported by launchd (2, 15, 15)`（`SIGTERM`）と記録した。クラッシュレポートはなかった。

UID 501 のアプリの記録への更新は、smd が `Update request for unmanaged item ignored` と記録した。

BTM（`sfltool dumpbtm`）の UID -2 にある親のアプリの記録 `2.io.github.koutyuke.capsaicin.debug` は、今回の各試験の前で `[enabled, allowed, not notified]` だった。`EVID-HLP-016` の検証中（11/19、`~/Capsaicin-verification.vaBwpy` ほか 11/19 00:17〜07:46 の 37 件の記録）は、同じ記録がすべて `[disabled, allowed, not notified]` だった。11/18 の記録（`~/Capsaicin-verification.Zwk6AP`）では `enabled` だった。

オーナーは、ほかのアプリでもバックグラウンドの項目をオフにすると終了することを見た（アプリ名は記録していない）。

## 確かめ方

エージェントが `log stream`（loginwindow、runningboardd、smd、backgroundtaskmanagementd、デーモン）を記録し、各試験の前後で `sfltool dumpbtm`、`pmset -g`、`ps`、Debug の CLI の `status` を読んだ。スイッチの操作と設定の変更はオーナーが行った。

## 適用範囲

このビルドと環境で、親のアプリの記録が `enabled` の場合。

## 未確認のこと

- 親のアプリの記録がいつ、何によって `enabled` になったか（ログは 11/20 15:30 頃からしか残っていない）。
- loginwindow が `SIGTERM` の後にどれだけ待つか（`HYP-LCY-010`）。
- 親の記録が `disabled` だと終了しないか（`HYP-HLP-013`）。
