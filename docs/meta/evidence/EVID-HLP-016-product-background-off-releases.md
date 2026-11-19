---
schema: evidence
id: EVID-HLP-016
title: 製品のビルドで抑止中にバックグラウンドの項目をオフにすると、デーモンが off を実行し、アプリは動き続けたまま抑止を解除し、設定の保存値は変わらなかった
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、Xcode 27.2（27B52）。`feature/smappservice` の `fa4bc85` の Debug ビルドを `just sign-debug` で Developer ID Application の証明書で署名し直した。電源アダプターに接続
sources: ["fa4bc85:docs/manual/verification/background-off-release.md", "~/Capsaicin-verification.2CTPup/result-background-off-release.txt", "~/Capsaicin-verification.2CTPup/hud.background-off.png", "~/Capsaicin-verification.2CTPup/settings.background-off.comparison.txt", "412c506:docs/manual/verification/background-off-release.md", "~/Capsaicin-verification.vaBwpy/result-background-off-release.txt", "~/Capsaicin-verification.vaBwpy/hud.background-off.png"]
---

# EVID-HLP-016 製品のビルドで抑止中にバックグラウンドの項目をオフにすると、デーモンが off を実行し、アプリは動き続けたまま抑止を解除し、設定の保存値は変わらなかった

## 確かめた事実

「切り替え時にHUDを表示」をオン、「ディスプレイを閉じたとき」を「オンのまま」にし、ヘルパーを「有効」にして抑止を始めた。オーナーがシステム設定で、このチェックアウトの Debug のバックグラウンドの項目だけをオフにした。2回試した。

1. 項目をオフにすると、デーモンが `Helper SIGTERM cleanup succeeded` を記録し、`SleepDisabled 0` になり、Capsaicin のアサーションとデーモンのサービスはなくなった。
2. アプリ（PID 87525）の PID、開始時刻、実行ファイルは前後で同じだった。メニューには「スリープ防止をオンにする」が出た。
3. 「ヘルパー」の「状態」は「システム設定での許可待ち」になった。
4. `capsaicin.settings` の保存値は前後で同じだった。
5. HUD には「スリープ防止 オフ」と、解除の理由「バックグラウンド項目オフ（シス…」が出た。理由の文言「バックグラウンド項目オフ（システム設定）」は HUD の最大幅（420 pt）に収まらず、末尾が省略された。
6. 理由の文言を「バックグラウンド項目オフ」に短くしたビルド（`412c506`）で、同じ手順をもう1回試した。HUD には「スリープ防止 オフ」と「バックグラウンド項目オフ」が省略されずに出た。デーモンは `Helper SIGTERM cleanup succeeded` を記録し、`SleepDisabled` は 1 から 0 になり、アプリ（PID 15524）の PID と開始時刻は変わらず、設定の保存値も同じだった。メニューの「スリープ防止をオンにする」、「ヘルパー」の「システム設定での許可待ち」と「システム設定を開く」「削除…」、「ディスプレイを閉じたとき」の注意の記号は、オーナーが目で確かめた。

## 確かめ方

`docs/manual/verification/background-off-release.md`（`fa4bc85`）の手順で、前後の PID、`SleepDisabled`、アサーション、デーモンの照会とログ、設定の保存値を読んだ。HUD は画面写真で、「ヘルパー」の状態はオーナーが目で確かめた。

## 適用範囲

製品の実装で、ヘルパーが要る設定で抑止中に、システム設定でバックグラウンドの項目をオフにした場合に当てはまる。HUD の理由の文言は、最初の観測の後に短くし、短くした文言を日本語の表示で確かめた。

## 未確認のこと

- 英語の表示での HUD の文言「Background item off」の見え方。バンドルの文言は照合したが、英語の画面では表示していない。
- 項目をオンに戻した後に、再び抑止を始められること（復元では「状態」が「有効」に戻ったことだけを確かめた）。
