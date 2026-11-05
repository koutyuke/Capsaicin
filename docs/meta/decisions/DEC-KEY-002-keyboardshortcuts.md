---
schema: decision
id: DEC-KEY-002
title: ホットキーには KeyboardShortcuts を使う
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-KEY-002"]
based_on: []
---

# DEC-KEY-002 ホットキーには KeyboardShortcuts を使う

## 結論

ホットキーの登録と記録欄には、sindresorhus/KeyboardShortcuts（MIT ライセンス）を、版を固定してアプリだけの依存として使う。配布物にはライセンスの表示を含める。

## 背景

macOS には、ショートカットを記録する標準のコントロールがない。記録欄の UI、キーの表記、保存、重複の表示が要る（`SPEC-KEY-002`）。

## 選択肢

- Carbon の `RegisterEventHotKey` を直接使う。登録は短く書けるが、記録欄の UI とキーの表記、重複の検出を自作することになる（不採用）。
- KeyboardShortcuts を使う（採用）。

## 理由

記録欄の UI、保存、重複の表示がそろっていて、権限のダイアログを出さずに使えるため。

## 影響

- 外部の依存が1つ増える。版は固定し、アプリのターゲットだけが使う。
- 配布物にライセンスの表示を含める必要がある。

## 覆す条件

- KeyboardShortcuts が権限のダイアログを出す、保守されなくなる、または対応環境の macOS で動かないと分かったら見直す。
