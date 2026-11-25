---
schema: evidence
id: EVID-LED-009
title: Karabiner-Elements が占有するキーボードでは実機への書き込みが消され、仮想キーボードへの書き込みは点灯を保つ代わりにルールを成立させなくする
observed_on: 2026-11-11
environment: macOS 27.2.1（26B131）、Mac16,8、Capsaicin の Debug ビルド（cf9d459）、Karabiner-Elements 16.3.0（仮想キーボード 1.8.0）、内蔵キーボードと Lofree Flow Lite（USB）
sources: ["/usr/bin/log", "/usr/bin/hidutil", "/usr/sbin/ioreg"]
---

# EVID-LED-009 Karabiner-Elements が占有するキーボードでは実機への書き込みが消され、仮想キーボードへの書き込みは点灯を保つ代わりにルールを成立させなくする

## 確かめた事実

`docs/manual/led-remapper-verification.md`（コミット `14fd1f7`） の B3 を行った。Karabiner-Elements は内蔵と Lofree（USB）の両方で「Modify events」と「Manipulate caps lock LED」がオン（既定）だった。LED とルールの成否はオーナーの目視、書き込みが届いたことは WindowServer の `updateCapslockLED` のログによる。

ルールは「左 Shift＋左 Option＋3 を、左 Shift＋左 Command＋左 Control＋4 に変える」で、`from.modifiers` に `optional` がない。成立すると画面の範囲選択の十字が出る。Caps Lock は、どの試行でもオフのままだった。

### 書き込み先ごとの結果

Capsaicin と同じ Passive のクライアントで、1つのサービスだけに書くツール（`led-service-check`）をオーナーが実行した。

| 書き込み先 | 設定 | 内蔵の LED | Lofree の LED | ルール |
| --- | --- | --- | --- | --- |
| 内蔵だけに `"On"` | 既定 | 一瞬点いて、すぐ消えた | — | — |
| 仮想キーボードだけに `"On"` | 既定 | 10秒後も点灯 | 10秒後も点灯 | 両方のキーボードで成立しない |
| 仮想キーボードを `"Auto"` に戻す | 既定 | 消灯 | 消灯 | 両方で成立する |
| 内蔵だけに `"On"` | 内蔵の「Manipulate caps lock LED」をオフ | 10秒後も点灯 | — | — |
| 内蔵だけに `"On"` | 内蔵の「Modify events」をオフ | 10秒後も点灯 | — | — |

- 内蔵だけに書いて LED が消えた後も、`ioreg` の `HIDCapsLockLED` は10秒後まで `"On"` のままだった。
- 「Manipulate caps lock LED」をオフにした内蔵キーボードでは、手動で Caps Lock をオンにしても LED が点かなかった。入力は切り替わった。

### Capsaicin での結果

Capsaicin は、内蔵、Lofree の2つのサービス、仮想キーボードの4つに書いた（失敗なし）。

- 開始直後、15秒後、1分後、10分後のどれでも、内蔵と Lofree が点灯していた。途中で両方のキーボードの Caps Lock をオン・オフしても点いたままだった。
- 抑止中は、両方のキーボードでルールが成立しなかった。抑止の前と、解除した後は成立した。解除から確認までの間、Caps Lock には触れていない。

### 占有の印

IORegistry の usage 6 のデバイスの下にある Karabiner-Core-Service の `IOHIDLibUserClient` を、`DebugState` の `ClientOptions` と `ClientOpened` で比べた。

| 状態 | 内蔵 | Lofree（USB） |
| --- | --- | --- |
| Karabiner-Elements が起動中 | `Options=1 Opened=Yes` | `Options=1 Opened=Yes` |
| アプリを終了 | 印なし | 印なし |
| 起動し直した | `Options=1 Opened=Yes` | `Options=1 Opened=Yes` |
| 内蔵の「Modify events」をオフ | 印なし | `Options=1 Opened=Yes` |
| 内蔵の「Manipulate caps lock LED」をオフ | `Options=1 Opened=Yes` | `Options=1 Opened=Yes` |

アプリを終了して仮想キーボードが消えても、Karabiner-Elements の常駐プロセスは残り、Capsaicin の案内は出続けた。

### `hidutil` での書き込み

`hidutil property --set` で内蔵や仮想キーボードに `"On"` を書く試行は、コマンドが `On` を表示しただけだった。WindowServer のログに書き込みが残らず、`--get` は `(null)` を返し、LED もルールも変わらなかった。この方法では書き込みが届いたと言えないので、上の表はすべて Passive のクライアントで取り直した。

## 確かめ方

手順は `docs/manual/led-remapper-verification.md`（コミット `14fd1f7`） の B0 と B3。1つのサービスだけに書くツールは、Capsaicin の `CapsaicinLEDCreatePassiveClient` で Passive のクライアントを作り、`IOHIDServiceClientCopyServices` のうちキーボード（UsagePage 1、Usage 6）で `Product` が指定の名前（`Apple Internal Keyboard / Trackpad` か `Karabiner DriverKit VirtualHIDKeyboard 1.8.0`）のサービスだけに、`IOHIDServiceClientSetProperty` で `HIDCapsLockLED` に `On` か `Auto` を書き、書いた後の値を読み返す。

```sh
/usr/bin/log show --start "$T0" --info --style compact \
  --predicate 'eventMessage CONTAINS "updateCapslockLED"'
/usr/sbin/ioreg -l -w0 -r -c IOHIDDevice | grep -E -- '-o |"Product" =|"PrimaryUsage" =|IOUserClientCreator|"DebugState"'
```

## 適用範囲

- Karabiner-Elements 16.3.0 が既定の設定で占有するキーボードでは、実機だけに書いた `"On"` が保たれないことの根拠に使ってよい。
- 仮想キーボードに `"On"` を書くと、Caps Lock がオフのままでも、修飾キーを厳密に照合するルールが成立しなくなることの根拠に使ってよい。
- 「Manipulate caps lock LED」か「Modify events」をオフにすれば実機への書き込みが保たれること、占有の印が「Modify events」に連動することの根拠に使ってよい。
- `HIDCapsLockLED` の読み返しでは、LED が実際に消されたことを検出できないことの根拠に使ってよい。

## 未確認のこと

- 実機だけに書いた LED が消えるまでの秒数。「一瞬」という目視の報告だけである。
- 「Manipulate caps lock LED」や「Modify events」をオフにした状態で、10秒を超えて点灯が続くか。
- ルールの不成立のほかに、Karabiner-Elements の動作へ及ぶ影響（`caps_lock` を条件にしたルール、変数など）。
- Karabiner-Elements の 16.3.0 以外の版と、ほかのキー配列を変えるアプリ。
- `DebugState` の印が、OS のほかの版でも同じ形で読めるか。
