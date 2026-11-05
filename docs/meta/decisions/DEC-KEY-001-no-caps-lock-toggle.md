---
schema: decision
id: DEC-KEY-001
title: 抑止の切り替えに Caps Lock キーを使わない
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-KEY-001", "REQ-LED-003"]
based_on: []
---

# DEC-KEY-001 抑止の切り替えに Caps Lock キーを使わない

## 結論

抑止の切り替えに Caps Lock キーを使わない。キーボードからの切り替えは、利用者が割り当てるグローバルホットキーで行う（`SPEC-KEY-001`）。

## 背景

LED が Caps Lock のものなので、Caps Lock キーで抑止を切り替える案が考えられた。

## 選択肢

- Caps Lock キーで抑止を切り替える。Caps Lock を別のキーに割り当てている人が使えず、入力監視の権限も必要になる（却下）。
- 利用者が割り当てるグローバルホットキーで切り替える（採用）。

## 理由

Caps Lock キーを別のキーに割り当てている人も使えるようにし、入力監視の権限を求めないため（`REQ-LED-003`、`REQ-LED-008`）。

## 影響

- 利用者がホットキーを割り当てるまで、キーボードから切り替えられない（既定値は `SPEC-SET-002`）。

## 覆す条件

- Caps Lock キーの押下を、入力監視の権限なしに、別のキーへの割り当てと衝突せずに検知できる手段が見つかり、利用者がそれを望んだら見直す。
