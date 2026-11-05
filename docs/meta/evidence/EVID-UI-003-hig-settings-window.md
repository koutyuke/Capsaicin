---
schema: evidence
id: EVID-UI-003
title: HIG は設定ウインドウのタイトル、最小化・ズームのボタン、前回のペインの扱いを定める
observed_on: 2026-11-06
environment: Web 上の文書（Apple Human Interface Guidelines「Settings」）
sources: ["https://developer.apple.com/tutorials/data/design/human-interface-guidelines/settings.json"]
---

# EVID-UI-003 HIG は設定ウインドウのタイトル、最小化・ズームのボタン、前回のペインの扱いを定める

## 確かめた事実

HIG の「Settings」は、macOS の設定ウインドウについて次のように述べている。

- 「Update the window's title to reflect the currently visible pane.」
- 「Dim a settings window's minimize and maximize buttons.」
- 「Restore the most recently viewed pane.」

## 確かめ方

上記の JSON を読んだ。人が読むページは https://developer.apple.com/design/human-interface-guidelines/settings にある。

## 適用範囲

設定ウインドウのタイトル、ボタン、開くペインの根拠に使ってよい（`SPEC-SET-001`）。

## 未確認のこと

なし。
