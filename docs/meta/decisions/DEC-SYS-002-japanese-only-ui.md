---
schema: decision
id: DEC-SYS-002
title: 表示言語は日本語だけにし、文字列は String Catalog で管理する
status: superseded
supersedes: []
superseded_by: ["DEC-SYS-017"]
requirements: ["REQ-SYS-003", "REQ-SYS-004"]
based_on: []
---

# DEC-SYS-002 表示言語は日本語だけにし、文字列は String Catalog で管理する

## 結論

v1 の表示言語は日本語だけにし、英語の UI は作らない。文字列は String Catalog で管理し、あとから言語を追加できるようにしておく。

## 背景

v1 の利用者は作者自身である。将来ほかの人に配る可能性がある（`DEC-SYS-004`）。

## 選択肢

- 日本語だけにし、文字列を String Catalog で管理する（採用）。
- v1 から英語の UI も用意する。移行元はこれを非目標にしている（不採用）。

## 理由

移行元には、日本語だけにする理由の記載がない。String Catalog で管理するのは、あとから言語を追加できるようにするためである。

## 影響

- 文字列をコードに直接書かず、String Catalog を経由させる。

## 覆す条件

- 日本語以外の利用者に配ることになったら、英語などの追加を見直す。
