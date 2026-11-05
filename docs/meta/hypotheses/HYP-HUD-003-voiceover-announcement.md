---
schema: hypothesis
id: HYP-HUD-003
title: フォーカスを受けないアプリからの announcementRequested を VoiceOver が読み上げる
status: open
affects: ["DEC-UI-005", "REQ-HUD-004", "SPEC-HUD-008"]
evidence: []
---

# HYP-HUD-003 フォーカスを受けないアプリからの announcementRequested を VoiceOver が読み上げる

## 主張

メニューバー常駐のアプリが、前面にないときに `NSAccessibility.post(element:notification:userInfo:)` で `.announcementRequested` を送ると、VoiceOver はその文を読み上げる。

## 外れたときに起きること

HUD の内容が VoiceOver の利用者に伝わらない。`DEC-UI-005` の読み上げの方法を見直し、`SPEC-HUD-008` が変わる。

## 確かめ方

1. 環境: 対応環境の Mac で VoiceOver をオンにする。
2. 別のアプリを前面にしたまま、試作のアプリから読み上げを要求する。
3. 成功: 文が読み上げられる。失敗: 読み上げられない。

永続的なシステム変更は伴わない。

## 結果

未確認。
