---
schema: evidence
id: EVID-LED-003
title: 画面だけのスリープで HIDCapsLockLED が "Auto" に戻り、Mac の復帰通知は来ない
observed_on: 2026-11-08
environment: macOS 27.0.1（ビルド 26A434）、Mac16,8（Apple M4 Pro）、Karabiner-Elements 16.3.0（DriverKit 仮想キーボード 1.8.0）が起動中、外付けキーボードは未接続
sources: ["/var/log/karabiner/core_service.log"]
---

# EVID-LED-003 画面だけのスリープで HIDCapsLockLED が "Auto" に戻り、Mac の復帰通知は来ない

## 確かめた事実

- 抑止中（LED の通知はオン）に `pmset displaysleepnow` で画面だけをスリープさせると、`"On"` だった2つのサービスの `HIDCapsLockLED` が、画面のスリープの開始から1秒以内に `"Auto"` に変わった。画面を復帰させた後も `"Auto"` のままで、LED は消えたままだった。
- 1回目は 01:11:38 に画面のスリープが始まり（システムログの `kCGSDisplayWillSleep`）、01:11:39 の読み取りで `"Auto"` になっていた。
- 2回目は、Karabiner-Elements の「Modify events」をオフにし、内蔵キーボードを掴んでいない状態で行った。Karabiner のログには 01:20:52 に `Apple Internal Keyboard / Trackpad ... hid device events monitor is stopped.` と `caps_lock_led_state_manager is stopped` が記録されている。この状態でも、01:22:01 の読み取りで `"Auto"` に戻った。
- どちらの時刻にも、Capsaicin は LED に書き込んでいない。Capsaicin が `"Auto"` を書くのは抑止を解除したときだけである。
- 画面だけのスリープでは Mac 本体は眠らないので、`NSWorkspace.didWakeNotification` は来ない。また、内蔵キーボードの接続・切断も起きない。そのため、既存の再適用の経路では LED が点灯し直されなかった。
- 復帰後に Capsaicin の CLI で抑止を解除して開始し直すと（`capsaicin off`、`capsaicin on`）、アプリの書き込みで `HIDCapsLockLED` は `"On"` に戻った。

## 確かめ方

抑止中に、次のコマンドで1秒ごとに値を記録しながら、オーナーが `pmset displaysleepnow` を実行し、10秒ほど待ってから Shift キーで画面を戻した。

```sh
while true; do echo "$(date +%T) $(ioreg -r -l -c IOHIDEventService | grep -o '"HIDCapsLockLED"="[A-Za-z]*"' | tr '\n' ' ')"; sleep 1; done | tee /tmp/capsaicin-led.log
```

画面のスリープの時刻は `/usr/bin/log show` の `kCGSDisplayWillSleep` で、Karabiner-Elements が内蔵キーボードを掴んでいるかは `/var/log/karabiner/core_service.log` で確かめた。記録ファイルは一時ファイルで、リポジトリには残していない。

## 適用範囲

観測した環境で、画面だけのスリープによって `HIDCapsLockLED` の `"On"` が失われることと、画面の復帰時に設定し直す必要があることの根拠に使ってよい。Karabiner-Elements が内蔵キーボードを掴んでいなくても起きたので、Karabiner-Elements の上書き（`HYP-LED-002`）とは別の現象として扱う。

## 未確認のこと

- `"Auto"` に戻しているのが macOS のどの部分か。Karabiner-Elements の常駐プロセスは2回目も起動していたので、Karabiner-Elements を完全に止めた環境では確かめていない。
- 画面の復帰時に `"On"` を書き直したとき、物理的な LED が点灯し直すか。`hidutil property --set` で `"On"` を書いたときは、Karabiner-Elements が内蔵キーボードを掴んだ状態で、LED は点かなかった。
- 外付けキーボードでも同じことが起きるか。
