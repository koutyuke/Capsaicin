---
schema: evidence
id: EVID-BLK-014
title: disablesleep 1 は再起動の後に 0 だったが、ほかの電源管理アプリが書いた可能性を除けていない
observed_on: 2026-11-18
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、Capsaicin のヘルパーと LaunchDaemon は削除済み、AlDente Pro（root ヘルパーあり）、Amphetamine の sudoers のルール、ほかの root ヘルパーが入った Mac
sources: []
---

# EVID-BLK-014 disablesleep 1 は再起動の後に 0 だったが、ほかの電源管理アプリが書いた可能性を除けていない

## 確かめた事実

- 再起動の前: `pmset -g` は `SleepDisabled 0` だった。`sudo pmset -a disablesleep 1` の後、`SleepDisabled 1` になった。
- 再起動してログインした後: `SleepDisabled 0` だった。
- Capsaicin のヘルパーが戻したのではない。再起動の後、`/Library/LaunchDaemons` と `/Library/PrivilegedHelperTools` に Capsaicin のファイルはなく、launchd は起動時に `Could not find job with label io.github.koutyuke.capsaicin.helper.debug` を出した。
- `/Library/Preferences/com.apple.PowerManagement.plist` の `SystemPowerSettings` は `SleepDisabled = false` を持ち、ファイルの更新時刻は 03:34:06 だった。Mac の起動（`kern.boottime`）は 03:34:24 なので、シャットダウンの途中で書かれている。誰が書いたかは、ログから特定できなかった。

この結果を「macOS が再起動で `disablesleep` を戻す」根拠にはできない。次の交絡を除けていないためである。

- AlDente Pro の root ヘルパーは `IOPMSetSystemPowerSetting` で同じ設定を書く処理（`setSystemSleepEnabled`）を持つ。AlDente のアプリは、シャットダウンの直前まで2秒おきに `pmset` を実行していた。
- Amphetamine の sudoers のルールは、`pmset -a disablesleep 1|0` をパスワードなしで許している。
- 起動の3秒後に、出どころの分からない `pmset`（pid 85）が動いた。ログには設定の読み込みしか出ていない。

## 確かめ方

オーナーが SMAppService の試作の確認（`EVID-HLP-004`）と同じ再起動で、`HYP-BLK-007` の手順を行った。設定ファイルの中身と更新時刻、起動とシャットダウンの前後のログは、エージェントが読み取りだけで確かめた。

## 適用範囲

- 使ってよい: `HYP-BLK-007` がまだ確かめられていないことの根拠。ほかの電源管理アプリが `SleepDisabled` を書きうることの例。
- 使ってはいけない: 再起動で `disablesleep` が戻る、または残ることの根拠。

## 未確認のこと

- ほかの電源管理アプリを止めた（または入れていない）Mac で、`disablesleep 1` が再起動の後に残るか。
- シャットダウンの途中で設定ファイルを書いたプロセス。
