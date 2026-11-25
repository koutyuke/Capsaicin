---
schema: evidence
id: EVID-LED-014
title: Sidecar の仮想キーボードは Transport に "Virtual" を持ち、Capsaicin の書き込みの対象に入った
observed_on: 2026-11-12
environment: macOS 27.2.1（26B131）、Mac16,8、Capsaicin の Debug ビルド（2a8e733）
sources: ["/usr/bin/hidutil", "/usr/sbin/ioreg", "/usr/bin/log"]
---

# EVID-LED-014 Sidecar の仮想キーボードは Transport に "Virtual" を持ち、Capsaicin の書き込みの対象に入った

## 確かめた事実

`EVID-LED-013` の検証の記録に、実機ではないキーボードのサービスが1つあった。

| 項目 | 値 |
| --- | --- |
| サービスの登録 ID | `0x100047355`（`4295258965`） |
| サービスのクラス | `AppleUserHIDEventService` |
| デバイス | `IOHIDUserDevice`（`0x100047351`） |
| `Transport` | `"Virtual"` |
| VendorID、ProductID | `0x5ac`、`0x8600` |
| 製品名 | なし |
| usage | キーボード（usage page 1、usage 6） |

- デバイスを開いているプロセスは、`SidecarDisplayAgent`、`WindowServer`、Karabiner-Elements だった。検証の後（Karabiner-Elements を起動し直した後）に `ioreg` の `IOUserClientCreator` で読んだ。登録 ID は検証中の記録と同じである。
- Capsaicin は、このサービスを毎回の書き込みの対象に入れ、`"On"` と `"Auto"` を書いた。失敗はなかった。`ioreg` で読んだ `HIDCapsLockLED` は、抑止中は `"On"`、解除の後は `"Auto"` だった。
- 検証の開始時（14:11）の記録には、同じ属性で登録 ID が違うサービス（`0x100046f5e`）があった。このデバイスは作り直されることがある。
- 2026-11-11 の検証の記録には、このサービスはなかった。
- Karabiner-Elements の仮想キーボードは `Transport` を持たない（`EVID-LED-006`）。検証の後に読んだ `hidutil` でも、`Transport` は `(null)` だった。

## 確かめ方

`hidutil list --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}'` と `ioreg -l -w0 -r -c IOHIDUserDevice` を読んだ。書き込みの対象は `2-applog.txt` の `targets` で確かめた。

## 適用範囲

- 「`Transport` を持つ」だけでは、実機のキーボードと仮想キーボードを見分けられないことの根拠に使ってよい。
- `Transport` が `"Virtual"` の仮想キーボードがあることの根拠に使ってよい。

## 未確認のこと

- このサービスに `"On"` を書いたときに、Sidecar や iPad の側で何かが変わるか。
- このデバイスが作られる条件。検証中に Sidecar を使っていたかは記録していない。
- `Transport` が `"Virtual"` の実機のキーボードがあるか。
