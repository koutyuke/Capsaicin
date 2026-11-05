---
schema: decision
id: DEC-LED-003
title: LED の API は公開ヘッダーの関数を優先して呼び、Karabiner-Elements とは取り合わない
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-LED-001", "REQ-LED-004", "REQ-LED-007"]
based_on: ["DEC-LED-001", "HYP-LED-002"]
---

# DEC-LED-003 LED の API は公開ヘッダーの関数を優先して呼び、Karabiner-Elements とは取り合わない

## 結論

`DEC-LED-001` を補い、次のようにする。

- SDK の公開ヘッダーにある `IOHIDEventSystemClient` と `IOHIDServiceClient` の関数で呼べるなら、それを使う。公開されていない関数が要る場合は、小さな C のモジュールに宣言を閉じ込め、弱いリンク（weak import）にする。`dlsym` と関数の型の手作業の変換は使わない。関数がないときの振る舞いは `SPEC-LED-006` にある。
- Karabiner-Elements との関係は、選択肢のうち「検出して案内するだけにし、書き直し返さない」を採る（`SPEC-LED-005`）。

## 背景

- MacOSX27.2 の SDK の公開ヘッダー（`IOKit.framework/Headers/hidsystem/IOHIDEventSystemClient.h`、`IOKit.framework/Headers/hidsystem/IOHIDServiceClient.h`）には、`IOHIDEventSystemClientCreateSimpleClient`、`IOHIDEventSystemClientCopyServices`、`IOHIDServiceClientSetProperty` がある。Passive 型のクライアントを作る関数は、これらのヘッダーにはない。
- Karabiner-Elements は、キーボードの Caps Lock の LED を 3000 ミリ秒ごとに書き直す。ソースの `hid_keyboard_caps_lock_led_state_manager.hpp` で、`timer_.start(...)` に `std::chrono::milliseconds(3000)` を渡し、そのたびに `update_caps_lock_led()` を呼んでいる（https://github.com/pqrs-org/Karabiner-Elements/blob/main/src/share/hid_keyboard_caps_lock_led_state_manager.hpp 、2026-11-06 に main ブランチで確認）。

## 選択肢

- `dlsym` で非公開の関数を探し、関数の型を手で変換して呼ぶ。型の誤りが実行時まで分からない（不採用）。
- 非公開の宣言を C のモジュールに閉じ込め、弱いリンクにする（採用）。
- Karabiner-Elements より短い間隔で LED を書き直し続ける。LED がちらつく（不採用）。

## 理由

- 公開ヘッダーの関数なら、型の誤りをコンパイル時に見つけられるため。非公開の関数が要る場合も、宣言を1か所に閉じ込め、関数がない OS では LED の機能だけを止められるため。
- Karabiner-Elements と取り合うと、LED がちらつき、抑止中であることがかえって分かりにくくなるため。

## 影響

- Karabiner-Elements が LED を書き直す設定のキーボードでは、LED が消えることがある。その旨を案内する（`SPEC-LED-005`）。
- Passive 型のクライアントを使うかどうかは、実装時に公開の関数で足りるかを確かめて決める（`HYP-LED-001`）。

## 覆す条件

- 公開ヘッダーの関数だけで `HIDCapsLockLED` を書けないと分かったら、呼び方を見直す。
- Karabiner-Elements が LED を書き直さなくなった、または連携の手段を用意したら、案内の扱いを見直す。
