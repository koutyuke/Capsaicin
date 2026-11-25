---
schema: evidence
id: EVID-LCY-008
title: 別のビルドが登録した Debug の agent は、同じ bundle ID と plist 名のビルドの unregister で notRegistered になり、デーモンの登録とバックグラウンドの項目のスイッチは変わらなかった
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、日本語表示。登録したのは `feature/smappservice` の `195dda2` の Debug ビルド、解除したのはデーモンによる後片付けの試作。どちらも bundle ID `io.github.koutyuke.capsaicin.debug`、接尾辞のない同じ agent とヘルパーの plist 名で、同じ Team ID の Developer ID Application で署名した
sources: ["docs/meta/hypotheses/HYP-LCY-009-agent-item-removed-by-unregister.md", "7528138:docs/meta/tasks/TASK-114-daemon-cleanup-probe.md"]
---

# EVID-LCY-008 別のビルドが登録した Debug の agent は、同じ bundle ID と plist 名のビルドの unregister で notRegistered になり、デーモンの登録とバックグラウンドの項目のスイッチは変わらなかった

## 確かめた事実

オーナーが `feature/smappservice` のビルドを起動して agent を登録させ、ヘルパーも登録してから、「Capsaicinを終了」で終了した。終了の後、agent のジョブは `not running` で残っていた。続けて試作を起動した。1回だけ試した。

- 02:23:39.620 に、試作（PID 7106）が `Agent cleanup before: status=1`（`enabled`）を、02:23:39.632 に `Agent cleanup after: status=0`（`notRegistered`）を記録した。エラーはなかった。
- 解除の後、`launchctl print gui/501/io.github.koutyuke.capsaicin.debug` は終了コード 113（`Could not find service`）で失敗した。
- BTM の agent の項目 `8.io.github.koutyuke.capsaicin.debug` は消えずに、`[enabled, allowed, notified]` から `[disabled, allowed, notified]` になった。
- デーモンの項目 `16.io.github.koutyuke.capsaicin.debug.helper` は `[enabled, allowed, not notified]` のままで、項目全体に差分はなかった。`launchctl print` は解除の前後とも成功し、試作の「ヘルパー」の「状態」は「有効」だった。
- システム設定の「アプリのバックグラウンドでのアクティビティ」の「Capsaicin.app」のスイッチは、解除の前後ともオンだった。agent とデーモンは1つの行にまとまっているので、行は残った。
- 抑止はしておらず、`SleepDisabled` はずっと 0 だった。

## 確かめ方

`docs/manual/verification/agent-unregister-cleanup.md`（`b107708`）の手順で、試作を起動する前と後に `launchctl print`、`sfltool dumpbtm`、試作のログ、システム設定の画面を比べた。

## 適用範囲

登録したビルドと解除したビルドで、bundle ID、Team ID、agent の plist 名が同じ場合に当てはまる。

## 未確認のこと

- デーモンを登録していない状態で agent だけを解除した場合に、システム設定の行が消えるか。
- Team ID や plist 名が違うビルドからの解除。
