---
schema: decision
id: DEC-SYS-004
title: Apple Developer Program に加入せず、公証せずに配る
status: superseded
supersedes: []
superseded_by: ["DEC-SYS-021"]
requirements: ["REQ-SYS-005", "REQ-SYS-006"]
based_on: ["EVID-SYS-001", "EVID-SYS-002"]
---

# DEC-SYS-004 Apple Developer Program に加入せず、公証せずに配る

## 結論

Apple Developer Program には加入しない。v1 は自分の Mac でソースからビルドして使う。将来ほかの人に無料で配る場合に備えて、コード署名に依存しない方式を選ぶ。配る場合は公証せず、GitHub Releases か自前の Homebrew tap を使う。

## 背景

v1 は作者自身が使う。将来ほかの人に無料で配る可能性はあるが、Mac App Store での公開、有料販売、ライセンス認証、公証、自動アップデートは非目標である（`docs/product/overview.md`）。

## 選択肢

- Apple Developer Program に加入し、Developer ID で署名して公証する。移行元はこれを非目標にしている（不採用）。
- 加入せず、署名に依存しない方式で作る（採用）。

## 理由

移行元には、加入しない理由の記載がない。署名に依存しない方式を選ぶのは、将来ほかの人に配った場合でも同じ方式のまま動くようにするためである。

## 影響

- 将来配る場合、公証していないアプリは、利用者が「システム設定 > プライバシーとセキュリティ」の「このまま開く」で開く必要がある（`EVID-SYS-002`）。
- Homebrew の公式 Cask には掲載できない。公式 Cask は Gatekeeper の検査に通ることを求めるためである（`EVID-SYS-001`）。
- root の処理やログイン時の起動など、署名に依存しうる仕組みの選び方が制約される（`DEC-HLP-001`、`DEC-LCY-001`）。

## 覆す条件

- Apple Developer Program に加入することになったら見直す。
- 公証していないアプリを開く手順が macOS の更新でなくなるなど、配布の前提が崩れたら見直す。
