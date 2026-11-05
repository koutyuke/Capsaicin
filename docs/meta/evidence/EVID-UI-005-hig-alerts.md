---
schema: evidence
id: EVID-UI-005
title: HIG はアラートの注意の記号、OK のボタン、タイトル、破壊的なボタンの扱いを定める
observed_on: 2026-11-06
environment: Web 上の文書（Apple Human Interface Guidelines「Alerts」）
sources: ["https://developer.apple.com/tutorials/data/design/human-interface-guidelines/alerts.json"]
---

# EVID-UI-005 HIG はアラートの注意の記号、OK のボタン、タイトル、破壊的なボタンの扱いを定める

## 確かめた事実

HIG の「Alerts」は、次のように述べている。

- macOS では注意の記号（`exclamationmark.triangle` など）を控えめに使い、上書きや削除だけが目的の操作（保存、ゴミ箱を空にするなど）には使わない。
- 「OK」は、情報を伝えるだけのアラートでだけ承諾に使う。
- 「Error」のような、役に立つ情報を伝えないタイトルを避け、2行を超えて折り返す長いタイトルも避ける。
- 破壊的なスタイルは、利用者が意図して選んでいない破壊的な操作のボタンに使う。利用者が意図して選んだ操作（ゴミ箱を空にするなど）の確認では、そのボタンに破壊的なスタイルを使わない。

## 確かめ方

上記の JSON を読んだ。人が読むページは https://developer.apple.com/design/human-interface-guidelines/alerts にある。

## 適用範囲

ヘルパーのダイアログの記号、ボタン、タイトルの根拠に使ってよい（`SPEC-HLP-006`）。

## 未確認のこと

なし。
