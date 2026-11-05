---
schema: hypothesis
id: HYP-LED-001
title: Passive 型のクライアントから HIDCapsLockLED を書けば、権限なしで LED だけを制御できる
status: open
affects: ["DEC-LED-001", "REQ-LED-001", "REQ-LED-002", "REQ-LED-003", "REQ-LED-008", "SPEC-LED-001"]
evidence: []
---

# HYP-LED-001 Passive 型のクライアントから HIDCapsLockLED を書けば、権限なしで LED だけを制御できる

## 主張

入力監視の権限を持たないアプリが、Passive 型の `IOHIDEventSystemClient` から内蔵キーボードのサービスの `HIDCapsLockLED` に `"On"` を書き込むと、Caps Lock の LED が点灯し、Caps Lock の入力状態は変わらない。`"Auto"` を書き込むと、LED は Caps Lock の状態に連動する動作に戻る。

## 外れたときに起きること

- 権限が要る場合: `REQ-LED-008` を満たせず、`DEC-LED-001` を見直す。
- LED が光らない場合: `REQ-LED-001` を満たす方式がなくなり、`DEC-LED-001` を見直す。
- 入力状態が変わる場合: `REQ-LED-003` を満たせず、`DEC-LED-001` と `SPEC-LED-001` を見直す。

## 確かめ方

1. 環境: 対応環境の Mac の内蔵キーボード。試作プログラムには入力監視の権限を与えない（システム設定の「入力監視」に載っていないことを確かめる）。
2. Caps Lock をオフにし、試作プログラムで `"On"` を書き込む。`ioreg -l` で値が `"On"` になったことを確かめ、LED を目視し、テキストエディタで文字を入力する。
3. `"Auto"` を書き込み、Caps Lock をオンにしてからオフにする。
4. 成功: 手順 2 で LED が点灯し、入力は小文字のままで、権限を求めるダイアログが出ない。手順 3 で LED が Caps Lock に合わせて点き、消える。失敗: いずれかが満たされない。

書き込んだ値はプロセスの終了後も残る可能性がある（`HYP-LCY-001`）。終わったら `"Auto"` を書き込み、`ioreg -l` で `"Auto"` に戻ったことを確かめる。

## 結果

未確認。
