---
schema: hypothesis
id: HYP-LCY-001
title: 書き込んだプロセスが終了しても HIDCapsLockLED は "On" のまま残る
status: open
affects: ["DEC-LCY-001", "REQ-LCY-003", "SPEC-LCY-002", "SPEC-LCY-003"]
evidence: []
---

# HYP-LCY-001 書き込んだプロセスが終了しても HIDCapsLockLED は "On" のまま残る

## 主張

`HIDCapsLockLED` に `"On"` を書き込んだプロセスを強制終了しても、値は `"On"` のまま残り、LED は点灯し続ける。

## 外れたときに起きること

プロセスが終了すると LED が自動で元に戻るので、終了時とクラッシュ時に LED を戻す処理（`SPEC-LCY-002`、`SPEC-LCY-003`）は、LED については不要になる。`DEC-LCY-001` の背景が弱まるが、スリープ設定の復旧のために判断は残る。

## 確かめ方

1. 環境: 対応環境の Mac の内蔵キーボード。
2. 試作プログラムで `"On"` を書き込み、LED の点灯を確かめる。
3. `kill -9` でそのプロセスを強制終了する。
4. `ioreg -l` で `HIDCapsLockLED` の値を読み、LED を目視する。
5. 成功（主張どおり）: 値が `"On"` のままで、LED が点灯している。失敗: 値が `"Auto"` に戻り、LED が Caps Lock の状態に連動する。

主張どおりなら値が残るので、終わったら `"Auto"` を書き込み、`ioreg -l` で戻ったことを確かめる。

## 結果

未確認。
