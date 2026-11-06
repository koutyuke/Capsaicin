---
schema: decision
id: DEC-UI-004
title: HUD は Liquid Glass の Regular で描き、揺れのない短い動きにする
status: superseded
supersedes: []
superseded_by: ["DEC-UI-007"]
requirements: ["REQ-HUD-001", "REQ-UI-002"]
based_on: ["DEC-HUD-001", "EVID-UI-004", "EVID-UI-006"]
---

# DEC-UI-004 HUD は Liquid Glass の Regular で描き、揺れのない短い動きにする

## 結論

HUD の素材は、Liquid Glass の Regular（`NSGlassEffectView`）を採る。動きは、揺れ（バネ）を使わない短い出入りにし、続けて切り替えたときは1枚のパネルの内容を置き換える案を採る。寸法と動きの値は `SPEC-HUD-004`〜`SPEC-HUD-006` にある。

## 背景

HUD は、ほかのウインドウの上に浮かぶ一時的な表示で、文字を含む。移行元は、macOS の明るさ表示と同じく約 2 秒表示して消すとしていた。

## 選択肢

- Liquid Glass の Clear。写真や動画などの上に浮かぶ部品向けで、文字の読みやすさを優先しない（不採用）。
- 不透明な背景。macOS 26 のほかのコントロールの層と見た目が揃わない（不採用。「透明度を下げる」がオンのときだけ使う）。
- Liquid Glass の Regular（採用）。
- バネの動き。揺れが注意を引く（不採用）。

## 理由

- HIG は、Liquid Glass をコントロールとナビゲーションの層に使い、文字の多い部品には Regular を使うとしている（`EVID-UI-004`）。`NSGlassEffectView` は macOS 26.0 から使える（`EVID-UI-006`）。
- 画面の側から注意を引かない原則（`REQ-UI-002`）に合わせ、揺れのない短い動きにする。
- HIG は、視差効果を減らす設定がオンのとき、拡大や移動をフェードに置き換えるよう求めている（`EVID-UI-004`）。そのときの動きは `SPEC-HUD-008` にある。

## 影響

- 「透明度を下げる」がオンのとき、`NSGlassEffectView` が自動で不透明になるかを実装時に確かめ、ならなければアプリが置き換える（`SPEC-HUD-008`）。

## 覆す条件

- 実機で、Regular のガラスの上の文字が読みにくいと分かったら（`SPEC-UI-008`）、素材を見直す。
