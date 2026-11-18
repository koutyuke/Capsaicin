---
schema: evidence
id: EVID-HLP-006
title: 公証した Debug ビルドで、SMAppService のヘルパーは承認・on と off・起動時の後片付け・削除・更新の後の登録し直しが仕様どおりに動いた
observed_on: 2026-11-18
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、PR #15 の `702cb18` から作った Developer ID 署名・公証済みの Debug ビルド（`CFBundleVersion` 20261118011831 と 20261118052018）を /Applications に配置
sources: ["https://github.com/koutyuke/Capsaicin/actions/runs/44243514126", "docs/manual/verification.md", "Sources/capsaicin-helper/boot.c", "Packages/CapsaicinKit/Sources/CapsaicinPlatform/Helper/HelperRegistration.swift", "Sources/Capsaicin/Settings/SettingsModel.swift"]
---

# EVID-HLP-006 公証した Debug ビルドで、SMAppService のヘルパーは承認・on と off・起動時の後片付け・削除・更新の後の登録し直しが仕様どおりに動いた

## 確かめた事実

オーナーが手順書の4節（4.1〜4.5、4.8）に沿って操作し、結果を `launchctl print`、`pmset -g`、`pmset -g log`、`sfltool dumpbtm`、`/usr/bin/log` と画面で確かめた。

### 起動と設置（4.1）

- Finder から開くと、アプリは agent に引き渡され、launchd の子（PPID 1）として1つだけ動いた。agent の登録版の記録は起動した版と一致した。
- 設置の確認を取り消すと、「ディスプレイを閉じたとき」は「システムスリープ（標準）」に戻り、ヘルパーは「未インストール」のままだった。
- 設置すると「システム設定での許可待ち」になり、「システム設定を開く」と「削除」が表示された。設定ウインドウを開き直すと、選んだ値は捨てられて「システムスリープ（標準）」に戻り、許可待ちは残った。許可待ちのまま選び直すと、確認なしでシステム設定が開いた。
- 許可すると、選んだ値（`lidCloseDisplay=turnOff`）とヘルパーの登録版が保存された。デーモンは1回起動して起動の記録を書き、終了コード 0 で終わった。BTM では、デーモンが UID 0、agent が UID 501 で、どちらも `enabled, allowed` だった。
- 一度許可した Mac で、削除してから設置し直すと、システム設定での許可は求められなかった。

### on と off（4.2）

- 「オンのまま」と「ディスプレイスリープ」のどちらでも、抑止の開始で `SleepDisabled` が 1 になり、解除で 0 に戻った。抑止中は Apple メニューの「スリープ」を選べなかった。
- 「ディスプレイスリープ」で抑止中にディスプレイを閉じると、画面は消灯したが、`pmset -g log` にシステムの Sleep と Wake は記録されなかった。抑止を解除して閉じると、`Clamshell Sleep` と `DarkWake to FullWake` が記録された。

### システム設定で許可を外す（4.3）

- 「ログイン項目と機能拡張」で Capsaicin の項目をオフにすると、動いていたアプリが終了し、agent とデーモンのジョブがどちらも消えた。`SleepDisabled` は 0 のままだった。
- オフのまま Finder から開くと、アプリは agent なしで動いた。「ヘルパー」は「システム設定での許可待ち」、ヘルパーが要る保存値の行は注意の記号付きで残り、「一般」には「バックグラウンド項目が無効です」が出た。項目をオンに戻すと、ヘルパーは「有効」になり、両方のジョブが起動した。

### 起動時の後片付け（4.4）

- 版 20261118052018 で、再起動の前に `SleepDisabled = 1` を記録し、再起動の後に 0 を記録した。launchd は起動の直後にデーモンを読み込み、同じ時刻に起動の記録のディレクトリが更新された。デーモンは1回動いて終了コード 0 で終わり、ログに `Helper boot cleanup failed` はなかった。

### 削除（4.5）

- Capsaicin が立てた `disablesleep` は、削除で 0 に戻り、状態は「未インストール」、設定は「システムスリープ（標準）」に戻った。
- 外部から `SleepDisabled = 1` を立てた状態で削除すると、1 のまま残った。再開用の記録の所有は `ownsSleepDisabled = false` だった。

### 更新の後の登録し直し（4.8）

- 版 20261118011831 でヘルパーと agent を登録した後、同じ `/Applications/Capsaicin.app` を版 20261118052018 に置き換えて開いた。launchd のログでは、デーモンの登録の解除と、3秒後の登録し直しが記録された。承認は求められず、ヘルパーは「有効」のままで、抑止の開始と解除で `SleepDisabled` が 1 と 0 になった。
- その後、アプリの `CFBundleVersion`、ヘルパーと agent の登録版の記録、launchd の両ジョブのバンドル版が、すべて 20261118052018 で一致した。

## 確かめ方

オーナーが PR #15 の Debug ビルドを `/Applications` に置き、手順書の4節に沿って操作した。4.8 では、同じコミットから作り直した、版番号だけが大きいビルドに入れ替えた。記録はリポジトリの外の検証フォルダーに残した。

## 適用範囲

- 使ってよい: 公証したビルドで、SMAppService のヘルパーと agent の承認、on と off、許可を外したときの表示、起動時の後片付け、削除の所有の規則、更新の後の登録し直しが動くと判断するとき。
- 使ってはいけない: `disablesleep` が再起動で戻るかの判断（`HYP-BLK-007`）。後片付けが動いた後の値なので、再起動だけで戻ったかとは分けられない。

## 未確認のこと

- 2節の、クラッシュの後の再起動とログイン時の起動。
- 4.6（デーモンのない状態での値の永続性）と 4.7（「明るさを0」）。LED の独立した復旧手段がなかったため行わなかった。
- BTM の UID 501 のアプリの項目に出た `(pending authorization)` の意味。
- 1台、1つの macOS のバージョンでしか確かめていない。
