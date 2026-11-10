---
schema: hypothesis
id: HYP-LED-006
title: キー配列を変えるアプリの仮想キーボードの LED に書くと、そのアプリは Caps Lock がオンだと誤認する
status: open
affects: ["REQ-LED-003", "SPEC-LED-002", "SPEC-LED-005"]
evidence: []
---

# HYP-LED-006 キー配列を変えるアプリの仮想キーボードの LED に書くと、そのアプリは Caps Lock がオンだと誤認する

## 主張

キーボードを占有し、仮想キーボードから入力を流し直すアプリ（Karabiner-Elements など）は、OS が仮想キーボードに送る LED の出力を、Caps Lock の状態として読む。Capsaicin が仮想キーボードに `"On"` を書くと、Caps Lock がオフのままでも、アプリは抑止中ずっと Caps Lock をオンとみなす。Karabiner-Elements では、修飾キーを厳密に照合するルール（`from.modifiers` の `optional` に `any` も `caps_lock` もないもの）が成立しなくなる。

根拠はソースの読解である。Karabiner-DriverKit-VirtualHIDDevice は LED の出力レポートを入力レポートとして返し、Karabiner-Elements はそれを Caps Lock の状態として使う。`DEC-LED-003` の調査に続く 2026-11-10 の調査で読んだ。

## 外れたときに起きること

仮想キーボードに書いても入力には影響しない。仮想キーボードを書き込みの対象から外す理由は、警告の誤り（`HYP-LED-005`）と、実機の LED を保つかどうかだけになる。

当たっていれば、Capsaicin は仮想キーボードに書いてはならない。`REQ-LED-003`（Caps Lock の入力状態を変えない）の趣旨に反するためである。`SPEC-LED-002` の対象を実機のキーボードに限る。`SPEC-LED-005` と設定画面の「入力機能には影響ありません」は、書き込みの対象を直すまで正しくない。

## 確かめ方

`docs/manual/led-remapper-verification.md` の B3 の 4・5 で確かめる。

1. Karabiner-Elements が内蔵キーボードを占有している。修飾キーを厳密に照合するルールを1つ選び、抑止していない状態で成立することを確かめる。
2. Capsaicin で抑止を始め（LED で知らせるをオン）、仮想キーボードの `HIDCapsLockLED` が `"On"` であることを `ioreg` で確かめてから、同じキーを押す。
3. 抑止を解除し、同じキーを押す。
4. Capsaicin を使わず、`hidutil` で仮想キーボードだけに `"On"` を書いて、同じキーを押す。`"Auto"` に戻して、もう一度押す。

成功（主張どおり）: 2 と 4 の `"On"` の間だけルールが成立しない。失敗: ルールは常に成立する。

## 結果

未確認。
