---
schema: evidence
id: EVID-HLP-012
title: 抑止中にバックグラウンドの項目をオフにすると、デーモンは SIGTERM を受けて off を実行し、アプリは同じ PID のまま切断と承認待ちを検知した
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、日本語表示。デーモンによる後片付けの試作を標準の Debug のヘルパーのラベルでビルドし、Developer ID Application で署名した。agent は登録していない
sources: ["docs/meta/hypotheses/HYP-HLP-009-daemon-sigterm-on-background-off.md", "7528138:docs/meta/tasks/TASK-114-daemon-cleanup-probe.md"]
---

# EVID-HLP-012 抑止中にバックグラウンドの項目をオフにすると、デーモンは SIGTERM を受けて off を実行し、アプリは同じ PID のまま切断と承認待ちを検知した

## 確かめた事実

オーナーがヘルパーを登録して抑止を始め、デーモン（PID 76598）がアプリ（PID 74829）の後片付けの役目を持ち、`SleepDisabled 1` になったことを確かめた。その後、システム設定の「一般 > ログイン項目と機能拡張」（画面の見出しは「ログイン項目」）にある「アプリのバックグラウンドでのアクティビティ」で、「Capsaicin.app」のスイッチをオフにした。

- BTM のデーモンの項目は `[enabled, allowed, not notified]` から `[enabled, disallowed, not notified]` になった。
- 02:00:24.587 に、同じデーモンが `SIGTERM cleanup off: success=true` を記録した。02:00:29 の `pmset -g` は `SleepDisabled 0` で、`launchctl print` はデーモンのサービスなしだった。
- アプリは 02:00:29 も PID 74829 のまま、試作の実行ファイルで動いていた。
- アプリは 02:00:24.604 に `interrupted`、02:00:24.614 に `invalid` を受け、どちらのときも `SMAppService.daemon` の状態は `2`（`requiresApproval`）だった。続く `on` の再送は失敗した（`Helper reconnect on: success=false`）。
- アプリの「ヘルパー」の「状態」は「システム設定での許可待ち」になり、警告のアイコンが出た。システム設定の行の補足は「バックグラウンドで実行中」のままだった。
- スイッチをオンに戻すと、BTM のデーモンの項目は `[enabled, allowed, not notified]` に戻った。

生の記録は `/Users/koutyuke/Capsaicin-verification.yfX2da/result-background-off-while-blocking.txt` と、同じ場所のログ・BTM・画面写真にある。

## 確かめ方

`docs/manual/verification/background-off-while-blocking.md`（`b107708`）の手順で、切り替えの前後の BTM、`pmset -g`、プロセス、試作のログを読み、画面を撮った。

## 適用範囲

macOS 27.2.1 で、アプリとデーモンを1つのバックグラウンドの項目として許可している場合に当てはまる。

## 未確認のこと

- 抑止をしていないとき（デーモンが動いていないとき）に項目をオフにした場合の、アプリの検知。
- macOS 26 での振る舞い。
