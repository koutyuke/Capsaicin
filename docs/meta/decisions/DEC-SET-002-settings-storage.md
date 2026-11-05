---
schema: decision
id: DEC-SET-002
title: 設定はアプリの UserDefaults だけが持ち、型と既定値は 1 か所で定める
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-SET-001", "REQ-LCY-004"]
based_on: []
---

# DEC-SET-002 設定はアプリの UserDefaults だけが持ち、型と既定値は 1 か所で定める

## 結論

- 設定はアプリの `UserDefaults` だけが持つ。設定の型、既定値、検証は `CapsaicinCore` の1か所で定める。
- CLI は設定を読まない（CLI とアプリの境界は `DEC-SYS-007`）。
- 再開に使う記録は、通常の設定と別に保存する。中身は `specs/lifecycle.md` の「状態」にある。

## 背景

アプリ、CLI、ヘルパーが動く。設定の既定値（`SPEC-SET-002`）を複数の場所で持つと、食い違う。

## 選択肢

- CLI も設定を読み、既定値を自分で判断する。アプリと CLI で既定値の解釈が食い違いうる（不採用）。
- アプリだけが設定を持ち、型と既定値を1か所で定める（採用）。

## 理由

既定値と検証の正本を1つにし、CLI とアプリで解釈が食い違わないようにするため。

## 影響

- CLI の振る舞いはアプリが起動していることに依存する（`SPEC-CLI-004`）。

## 覆す条件

- アプリを起動せずに CLI だけで設定を扱う必要が出たら見直す。
