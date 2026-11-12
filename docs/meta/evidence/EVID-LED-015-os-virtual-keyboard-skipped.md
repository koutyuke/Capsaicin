---
schema: evidence
id: EVID-LED-015
title: Transport が "Virtual" のキーボードを対象から外すと、Sidecar の仮想キーボードに書かず、案内も出なかった
observed_on: 2026-11-12
environment: macOS 27.2.1（26B131）、Mac16,8、Capsaicin の Debug ビルド（2e1c028）、Karabiner-Elements 16.3.0 は終了、内蔵キーボードと Lofree Flow Lite（2.4 GHz）
sources: ["/usr/bin/log", "/usr/sbin/ioreg", "/usr/bin/hidutil", "~/capsaicin-led-check/20261112-142839/verification-results.txt", "~/capsaicin-led-check/20261112-142839/58-applog.txt", "~/capsaicin-led-check/20261112-142839/58-on-leds.txt", "~/capsaicin-led-check/20261112-142839/58-on-kbds.txt"]
---

# EVID-LED-015 Transport が "Virtual" のキーボードを対象から外すと、Sidecar の仮想キーボードに書かず、案内も出なかった

## 確かめた事実

`TASK-058` の「検証」の手順を行った。Capsaicin は、キーボードのうち、`Transport` を持ち、その値が `"Virtual"` ではないサービスだけに書く版である。LED と案内はオーナーの目視による。

- Karabiner-Elements を終了した後も、Sidecar の仮想キーボード（サービスの登録 ID `0x100047355`、`Transport` は `"Virtual"`）は残っていた。`EVID-LED-014` と同じ登録 ID である。
- 抑止の前、メニューと、設定の「LED」セクションに、案内は出なかった。
- 抑止を始めると、内蔵キーボードの LED が点灯した。
- 抑止中と解除時の書き込み（`"On"` が10回、`"Auto"` が1回）の対象は、内蔵（`0x100000cb5`）と、Lofree のレシーバーの2つのサービス（`0x100047881`、`0x100047888`）だけだった。Sidecar のサービスは、どの書き込みの対象にも入らなかった。失敗はなかった。
- 抑止中の `ioreg` では、内蔵とレシーバーの `HIDCapsLockLED` が `"On"`、Sidecar のサービスは `"Auto"` だった。解除の後は、すべて `"Auto"` だった。

## 確かめ方

手順は `TASK-058` の「検証」。記録は `~/capsaicin-led-check/20261112-142839/` にある。書き込みの対象は `58-applog.txt` の `targets` を読み、登録 ID は `58-on-kbds.txt` と `58-on-leds.txt` と照らした。

## 適用範囲

- `Transport` が `"Virtual"` のキーボードを対象から外しても、内蔵と、USB のレシーバーでつないだ外付けには書けることの根拠に使ってよい。
- `Transport` が `"Virtual"` のキーボードだけでは、案内が出ないことの根拠に使ってよい。

## 未確認のこと

- Bluetooth でつないだ外付けキーボード。今回は試していない。Bluetooth の `Transport` は `"Bluetooth Low Energy"` である（`EVID-LED-007`）。
- Sidecar の仮想キーボードに書いていたときに、害があったか。
