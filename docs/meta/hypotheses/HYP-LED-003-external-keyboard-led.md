---
schema: hypothesis
id: HYP-LED-003
title: 外付けキーボードでも HIDCapsLockLED で LED が光る
status: open
affects: ["REQ-LED-004", "SPEC-LED-002"]
evidence: []
---

# HYP-LED-003 外付けキーボードでも HIDCapsLockLED で LED が光る

## 主張

`HIDCapsLockLED` を持つ外付けキーボードのサービスに `"On"` を書き込むと、その外付けキーボードの Caps Lock の LED が点灯する。

## 外れたときに起きること

外付けキーボードでは LED で知らせられない。`REQ-LED-004` を内蔵キーボードに限るか、外付けキーボード向けの別の方式を探す。`SPEC-LED-002` の対象が変わる。

## 確かめ方

1. 環境: 対応環境の Mac。USB 接続、Bluetooth 接続、2.4 GHz のレシーバー接続（`EVID-LED-001` の「2.4G Wireless Receiver」など）の外付けキーボードを、手に入る範囲で用意する。
2. 外付けキーボードを接続し、`ioreg -l` でそのサービスに `HIDCapsLockLED` があることを確かめる。
3. そのサービスに `"On"` を書き込み、LED を目視する。
4. 成功: 外付けキーボードの LED が点灯する。失敗: プロパティがない、または書き込んでも点灯しない。機器ごとに結果を記録する。

終わったら `"Auto"` を書き込み、`ioreg -l` で戻ったことを確かめる。

## 結果

未確認。
