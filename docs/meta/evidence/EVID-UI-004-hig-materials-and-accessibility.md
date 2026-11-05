---
schema: evidence
id: EVID-UI-004
title: HIG は文字の多い部品に Liquid Glass の Regular を使い、視差効果を減らす設定では移動をフェードに置き換えるよう求める
observed_on: 2026-11-06
environment: Web 上の文書（Apple Human Interface Guidelines「Materials」「Accessibility」）
sources: ["https://developer.apple.com/tutorials/data/design/human-interface-guidelines/materials.json", "https://developer.apple.com/tutorials/data/design/human-interface-guidelines/accessibility.json"]
---

# EVID-UI-004 HIG は文字の多い部品に Liquid Glass の Regular を使い、視差効果を減らす設定では移動をフェードに置き換えるよう求める

## 確かめた事実

- 「Materials」: Liquid Glass は、コンテンツの層の上に浮かぶ、コントロールとナビゲーションの層に使う。Regular は背景をぼかして明るさを調整し、前景の文字の読みやすさを保つ。背景が読みやすさを損ないうるときや、アラート、サイドバー、ポップオーバーのように文字の多い部品に使う。Clear は写真や動画などの豊かな背景の上に浮かぶ部品だけに使う。
- 「Accessibility」: 文字のコントラストの最小値は、17 pt 以下で 4.5:1、18 pt 以上か太字で 3:1（WCAG の AA）。視差効果を減らす設定がオンのときは、拡大・縮小や周辺の動きを含む自動の動きを減らし、x・y・z 軸の移動をフェードに置き換える。

## 確かめ方

上記の JSON を読んだ。人が読むページは https://developer.apple.com/design/human-interface-guidelines/materials と https://developer.apple.com/design/human-interface-guidelines/accessibility にある。

## 適用範囲

HUD の素材と、アクセシビリティの設定での動きとコントラストの基準の根拠に使ってよい（`SPEC-HUD-008`、`SPEC-UI-008`）。

## 未確認のこと

- `NSGlassEffectView` が「透明度を下げる」の設定で自動的に不透明になるか。
