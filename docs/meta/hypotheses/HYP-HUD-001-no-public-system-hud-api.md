---
schema: hypothesis
id: HYP-HUD-001
title: Apple の明るさ表示を呼び出す公開 API はない
status: open
affects: ["DEC-HUD-001"]
evidence: []
---

# HYP-HUD-001 Apple の明るさ表示を呼び出す公開 API はない

## 主張

macOS の公開 API には、明るさや音量の表示と同じシステムの HUD に、アプリが任意のアイコンと文字列を表示させる手段がない。

## 外れたときに起きること

システムの HUD を使えば、見た目の保守が要らなくなる。`DEC-HUD-001` を比べ直す。

## 確かめ方

1. 対応環境の SDK のヘッダーと Apple の開発者向け文書で、システムの HUD（OSD）を表示する API を探す。
2. 成功（主張どおり）: 該当する公開 API が見つからない。失敗: 任意の内容を表示できる公開 API が見つかる。

永続的なシステム変更は伴わない。

## 結果

未確認。
