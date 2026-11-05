---
schema: decision
id: DEC-LED-001
title: LED は HIDCapsLockLED プロパティで制御し、Caps Lock の入力状態には触れない
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-LED-001", "REQ-LED-002", "REQ-LED-003", "REQ-LED-008"]
based_on: ["EVID-LED-001", "EVID-LED-002"]
---

# DEC-LED-001 LED は HIDCapsLockLED プロパティで制御し、Caps Lock の入力状態には触れない

## 結論

内蔵・外付けとも、Caps Lock の LED は非公開のプロパティ `HIDCapsLockLED` で制御する。抑止中は `"On"` を書き込み、解除したら `"Auto"`（Caps Lock の状態に連動する通常の動作）に戻す。書き込みは Passive 型の `IOHIDEventSystemClient` から行う。Caps Lock の入力状態は変えない。

## 背景

抑止中であることを LED で知らせたいが、Caps Lock の入力状態を変えると文字入力に影響する。Caps Lock キーを別のキーに割り当てている人もいる。Karabiner-Elements のようにキーボードを独占するツールと併用されることもある。

## 選択肢

- `HIDCapsLockLED` を Passive 型の `IOHIDEventSystemClient` から書き込む（採用）。入力監視の権限が要らないと見込んでいる（`HYP-LED-001`）。
- `IOHIDDeviceSetValue` で LED の出力レポートを送る。Karabiner-Elements がキーボードを独占していると `kIOReturnExclusiveAccess` で失敗し、外付けキーボードには入力監視の権限も必要になると移行元は述べている（`HYP-LED-004`）（却下）。
- Caps Lock の入力状態そのものを切り替えて LED を点ける。LED は点くが、大文字入力になる。移行元の目標（入力状態は変えない）に反する（却下）。

## 理由

- 入力状態を変えずに LED だけを制御でき、入力監視の権限も求めずに済むため。
- `HIDCapsLockLED` は内蔵キーボードにも外付けの機器にもあることを `ioreg` で確かめているため（`EVID-LED-001`、`EVID-LED-002`）。

## 影響

- `HIDCapsLockLED` と Passive 型の `IOHIDEventSystemClient` は非公開 API であり、macOS の更新で使えなくなる可能性を引き受ける。
- 外付けキーボードで実際に光るか（`HYP-LED-003`）、Karabiner-Elements が有効なときに点灯が保たれるか（`HYP-LED-002`）、アプリの終了後に `"On"` が残るか（`HYP-LCY-001`）は試作で確かめる。

## 覆す条件

- `HYP-LED-001` が外れ、入力監視の権限が要る、LED が光らない、または入力状態が変わると分かったら見直す。
- macOS の更新で `HIDCapsLockLED` か Passive 型の `IOHIDEventSystemClient` が使えなくなったら見直す。
- `HYP-LED-004` が外れ、`IOHIDDeviceSetValue` が独占時にも権限なしで使えると分かったら、選択肢を比べ直す。
