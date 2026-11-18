---
schema: evidence
id: EVID-HLP-016
title: 製品のビルドで抑止中にバックグラウンドの項目をオフにすると、デーモンが off を実行し、アプリは動き続けたまま抑止を解除し、設定の保存値は変わらなかった
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、Xcode 27.2（27B52）。`feature/smappservice` の `fa4bc85` の Debug ビルドを `just sign-debug` で Developer ID Application の証明書で署名し直した。電源アダプターに接続
sources: ["fa4bc85:docs/manual/verification/background-off-release.md", "~/Capsaicin-verification.2CTPup/result-background-off-release.txt", "~/Capsaicin-verification.2CTPup/hud.background-off.png", "~/Capsaicin-verification.2CTPup/settings.background-off.comparison.txt"]
---

# EVID-HLP-016 製品のビルドで抑止中にバックグラウンドの項目をオフにすると、デーモンが off を実行し、アプリは動き続けたまま抑止を解除し、設定の保存値は変わらなかった

## 確かめた事実

「切り替え時にHUDを表示」をオン、「ディスプレイを閉じたとき」を「オンのまま」にし、ヘルパーを「有効」にして抑止を始めた。オーナーがシステム設定で、このチェックアウトの Debug のバックグラウンドの項目だけをオフにした。2回試した。

1. 項目をオフにすると、デーモンが `Helper SIGTERM cleanup succeeded` を記録し、`SleepDisabled 0` になり、Capsaicin のアサーションとデーモンのサービスはなくなった。
2. アプリ（PID 87525）の PID、開始時刻、実行ファイルは前後で同じだった。メニューには「スリープ防止をオンにする」が出た。
3. 「ヘルパー」の「状態」は「システム設定での許可待ち」になった。
4. `capsaicin.settings` の保存値は前後で同じだった。
5. HUD には「スリープ防止 オフ」と、解除の理由「バックグラウンド項目オフ（シス…」が出た。理由の文言「バックグラウンド項目オフ（システム設定）」は HUD の最大幅（420 pt）に収まらず、末尾が省略された。

## 確かめ方

`docs/manual/verification/background-off-release.md`（`fa4bc85`）の手順で、前後の PID、`SleepDisabled`、アサーション、デーモンの照会とログ、設定の保存値を読んだ。HUD は画面写真で、「ヘルパー」の状態はオーナーが目で確かめた。

## 適用範囲

製品の実装で、ヘルパーが要る設定で抑止中に、システム設定でバックグラウンドの項目をオフにした場合に当てはまる。HUD の理由の文言は、この観測の後に短くした。短くした文言の表示は確かめていない。

## 未確認のこと

- 短くした理由の文言「バックグラウンド項目オフ」が、日本語と英語で省略されずに出ること。
- 項目をオンに戻した後に、再び抑止を始められること（復元では「状態」が「有効」に戻ったことだけを確かめた）。
