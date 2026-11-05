---
schema: decision
id: DEC-SYS-003
title: 対応環境を macOS 26 以降の Apple Silicon の Mac に絞る
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-SYS-001", "REQ-SYS-002"]
based_on: []
---

# DEC-SYS-003 対応環境を macOS 26 以降の Apple Silicon の Mac に絞る

## 結論

v1 は macOS 26 以降の Apple Silicon の Mac だけに対応する。Intel Mac と macOS 25 以前には対応しない。

## 背景

Capsaicin は `disablesleep` や `HIDCapsLockLED` など、macOS のバージョンや機種によって挙動が変わりうる非公開の仕組みに依存する（`DEC-BLK-001`、`DEC-LED-001`）。

## 選択肢

- macOS 26 以降の Apple Silicon に絞る（採用）。
- Intel Mac や macOS 25 以前にも対応する。移行元はこれを非目標にしている（不採用）。

## 理由

移行元には、この範囲に絞る理由の記載がない。

## 影響

- 試作で確かめる項目は、macOS 26 でも同じ結果になることを確かめる必要がある（`HYP-SYS-001`）。

## 覆す条件

- `HYP-SYS-001` が外れ、macOS 26 で LED か `disablesleep` が期待どおりに動かないと分かったら、下限のバージョンを見直す。
- Intel Mac や macOS 25 以前の利用者に配ることになったら見直す。
