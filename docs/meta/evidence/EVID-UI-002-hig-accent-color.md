---
schema: evidence
id: EVID-UI-002
title: macOS はアクセントカラーがマルチカラーのときだけアプリのアクセントカラーを使う
observed_on: 2026-11-06
environment: Web 上の文書（Apple Human Interface Guidelines「Color」）
sources: ["https://developer.apple.com/tutorials/data/design/human-interface-guidelines/color.json"]
---

# EVID-UI-002 macOS はアクセントカラーがマルチカラーのときだけアプリのアクセントカラーを使う

## 確かめた事実

HIG の「Color」の「App accent colors」は、macOS 11 以降、アプリはボタン、選択の強調、サイドバーのアイコンにアクセントカラーを指定でき、システムはシステム設定の「一般 > アクセントカラー」がマルチカラーのときにそれを使うと述べている。利用者がマルチカラー以外を選ぶと、システムは利用者の色でアプリのアクセントカラーを置き換える。例外は、固定の色を指定したサイドバーのアイコンである。

## 確かめ方

上記の JSON を読んだ。人が読むページは https://developer.apple.com/design/human-interface-guidelines/color にある。

## 適用範囲

アプリのアクセントカラーが表示される条件の根拠に使ってよい。

## 未確認のこと

- `NSMenu` の選択の色にアプリのアクセントカラーが使われるか。
