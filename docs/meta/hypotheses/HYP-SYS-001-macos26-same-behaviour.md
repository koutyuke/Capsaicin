---
schema: hypothesis
id: HYP-SYS-001
title: macOS 26 でも LED と disablesleep が同じように動く
status: open
affects: ["REQ-SYS-001", "DEC-SYS-003", "DEC-BLK-001", "DEC-LED-001"]
evidence: []
---

# HYP-SYS-001 macOS 26 でも LED と disablesleep が同じように動く

## 主張

macOS 26 の Apple Silicon の Mac で、`HIDCapsLockLED` と `disablesleep` に関する仮説（`HYP-BLK-001`、`HYP-BLK-002`〜`HYP-BLK-007`、`HYP-LED-001`、`HYP-LED-002`、`HYP-LED-003`、`HYP-LCY-001`）を確かめると、試作に使った Mac と同じ結果になる。

## 外れたときに起きること

macOS 26 では一部の機能が動かないか、`pmset displaysleepnow` に root が要る。`REQ-SYS-001` の下限を上げるか、`DEC-BLK-001` か `DEC-LED-001` の方式を macOS のバージョンで分ける。`DEC-SYS-003` を見直す。

## 確かめ方

1. 環境: macOS 26 の Apple Silicon の実機か仮想マシン。開発用の Mac は macOS 27.0.1 である（`EVID-LED-002`）ので、別に用意する。仮想マシンでは蓋や内蔵キーボードの LED を試せないため、蓋と LED の項目は実機で確かめる。
2. 上に挙げた各仮説の「確かめ方」を、同じ手順で実行する。
3. 成功: すべての項目で、試作に使った Mac と同じ結果になる。失敗: 1つでも結果が異なる。

各仮説の手順にある永続的なシステム変更と、元に戻す手順に従う。

## 結果

未確認。
