---
schema: evidence
id: EVID-UI-001
title: HIG はメニューバーの項目にポップオーバーではなくメニューを求め、高さを 24 pt とする
observed_on: 2026-11-06
environment: Web 上の文書（Apple Human Interface Guidelines「The menu bar」）
sources: ["https://developer.apple.com/tutorials/data/design/human-interface-guidelines/the-menu-bar.json"]
---

# EVID-UI-001 HIG はメニューバーの項目にポップオーバーではなくメニューを求め、高さを 24 pt とする

## 確かめた事実

Apple の Human Interface Guidelines の「The menu bar」の「Menu bar extras」は、次のように述べている。

- 「Display a menu — not a popover — when people click your menu bar extra.」「Unless the app functionality you want to expose is too complex for a menu, avoid presenting it in a popover.」
- 「The menu bar's height is 24 pt.」
- アイコンやシンボルは黒と透明だけで形を作り、システムが黒の部分に色を付けて、明るい・暗いメニューバーや選択中の状態に合わせる。

## 確かめ方

ページ本文はスクリプトで描かれるため、同じ内容の JSON（上記の URL）を読んだ。人が読むページは https://developer.apple.com/design/human-interface-guidelines/the-menu-bar にある。

## 適用範囲

メニューバーの項目にメニューを使うこと、メニューバーのアイコンの高さと色の扱いの根拠に使ってよい。

## 未確認のこと

- メニューバーのアイコンの画像そのものの推奨の大きさ（このページには記載がない）。
