---
schema: evidence
id: EVID-LED-007
title: 外付けキーボードは3つの接続方式で点灯し、キーボードを名乗るマウスへの書き込みは失敗しなかった
observed_on: 2026-11-11
environment: macOS 27.2.1（26B131）、Mac16,8、Capsaicin の Debug ビルド（cf9d459）、Karabiner-Elements 16.3.0 は終了（常駐プロセスは残る）、Lofree Flow Lite（USB・Bluetooth Low Energy・2.4 GHz）、Razer Viper V2 Pro（USB・2.4 GHz）
sources: ["/usr/bin/log", "/usr/bin/hidutil", "/usr/sbin/ioreg", "~/capsaicin-led-check/20261111-010115/verification-results.txt", "~/capsaicin-led-check/20261111-010115/session-state.json", "~/capsaicin-led-check/20261111-010115/session-applog.txt"]
---

# EVID-LED-007 外付けキーボードは3つの接続方式で点灯し、キーボードを名乗るマウスへの書き込みは失敗しなかった

## 確かめた事実

`docs/manual/led-remapper-verification.md` の B1 を行った。機器を替えるたびに Capsaicin を起動し直し、抑止の開始、手動の Caps Lock 操作、解除を行った。LED と入力はオーナーの目視、書き込みの対象と失敗はアプリのログ（`LED 書き込み: mode=… targets=… failedTargets=…`）による。

| 機器 | 接続 | 製品名 | Transport | キーボードのサービス数 | 書き込みの失敗 | LED |
| --- | --- | --- | --- | --- | --- | --- |
| 内蔵 | — | `Apple Internal Keyboard / Trackpad` | `FIFO` | 1 | なし | 点灯 |
| Lofree | USB | `Air84@Lofree` | `USB` | 2 | なし | 点灯 |
| Lofree | Bluetooth | `Flow84-L@Lofree `（末尾に空白） | `Bluetooth Low Energy` | 1 | なし | 点灯 |
| Lofree | 2.4 GHz | `2.4G Wireless Receiver` | `USB` | 2 | なし | 点灯 |
| Viper V2 Pro | USB | `Razer Viper V2 Pro` | `USB` | 2 | なし | 機器に LED なし |
| Viper V2 Pro | 2.4 GHz | `Razer Viper V2 Pro` | `USB` | 2 | なし | 機器に LED なし |

- 外付けキーボードが点灯した3つの条件すべてで、抑止中に Caps Lock を手動でオン・オフしても LED は点いたままで、入力は abc → ABC → abc と切り替わった。解除すると LED は消え、Caps Lock に連動する動作に戻った。
- Viper V2 Pro はマウスだが、usage page 1・usage 6 のサービスを2つ持つ。`"On"` と `"Auto"` の書き込みは成功を返し、`ioreg` の読み返しも `"On"` になった。「Caps Lock の LED を切り替えられていません」の警告も、解除時の「一部を戻せません」も出なかった。
- Karabiner-Elements のアプリを終了すると、仮想キーボードは一覧から消えた。常駐プロセスは残り、メニューの Karabiner-Elements の案内は出続けた。

2.4 GHz の最初の試行では Lofree が点灯しなかった。Capsaicin を起動し直しておらず、前の Bluetooth のサービスへ書いて失敗していたためで、接続方式の問題ではない（`EVID-LED-008`）。

## 確かめ方

手順は `docs/manual/led-remapper-verification.md` の B0 と B1。記録は `~/capsaicin-led-check/20261111-010115/` の `B1-*` にある。

```sh
/usr/bin/hidutil list --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}'
/usr/bin/log show --start "$T0" --style compact \
  --predicate 'subsystem == "io.github.koutyuke.capsaicin" AND category == "LED"'
```

## 適用範囲

- `HIDCapsLockLED` で、USB、Bluetooth Low Energy、2.4 GHz のレシーバーの外付けキーボードの LED が点くことの根拠に使ってよい。確かめた機種は Lofree Flow Lite の1つである。
- キーボードを名乗るサービスを持つマウスへの書き込みが、LED 全体の失敗にならないことの根拠に使ってよい。確かめた機種は Viper V2 Pro の1つである。

## 未確認のこと

- ほかのメーカーのキーボードとマウス。
- 警告と通常のオフの HUD の正確な全文。オーナーの報告は要約である。
