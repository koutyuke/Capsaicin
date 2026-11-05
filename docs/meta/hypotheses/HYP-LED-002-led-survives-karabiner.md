---
schema: hypothesis
id: HYP-LED-002
title: Karabiner-Elements が有効なままでも HIDCapsLockLED の点灯が保たれる
status: open
affects: ["REQ-LED-007", "SPEC-LED-005"]
evidence: []
---

# HYP-LED-002 Karabiner-Elements が有効なままでも HIDCapsLockLED の点灯が保たれる

## 主張

Karabiner-Elements を有効にしたまま、キーボードの `HIDCapsLockLED` に `"On"` を書き込むと、10 分間 LED が点灯し続ける。

## 外れたときに起きること

Karabiner-Elements を使う利用者には LED で知らせられない。`SPEC-LED-005` の案内の内容（「上書きされる場合がある」）を、より強い案内に変えるか、併用できないことを明示するかを決める。`REQ-LED-007` が変わりうる。

## 確かめ方

LED への最初の書き込み前に、対象へ `"Auto"` を書ける独立した復旧プロセスと復旧手順を用意し、PM の承認を得る。用意できなければ、最初の書き込み前で止める。Caps Lock の入力操作は、承認された手順で利用者が手動で行い、ソフトウェアからは変えない。

1. 環境: 対応環境の Mac。Karabiner-Elements を有効にする。`EVID-LED-002` のとおり、Karabiner-Elements の仮想キーボードも `HIDCapsLockLED` を持つので、実機のキーボードと仮想キーボードのどちらに書き込むかを記録する。
2. 実機のキーボードのサービスに `"On"` を書き込み、10 分間、LED を目視する。途中で Caps Lock をオン・オフし、文字を入力する。
3. 成功: 10 分間、LED が点灯し続ける。失敗: 途中で消える、または Caps Lock の操作で `"Auto"` の動作に戻る。

終わったら `"Auto"` の書き込みの戻り値が成功であることと、LED が通常の Caps Lock 連動に戻ったことを確かめる。読み戻し値が `"Auto"` であることは復旧の条件にしない（`EVID-LED-002`）。

## 結果

未確認。
