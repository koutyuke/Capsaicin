---
schema: decision
id: DEC-HUD-001
title: HUD はアプリが自前で画面中央下に描く
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-HUD-001", "REQ-HUD-002"]
based_on: []
---

# DEC-HUD-001 HUD はアプリが自前で画面中央下に描く

## 結論

切り替えたときの HUD は、システムの HUD を呼び出さず、アプリが自前のパネルとして描く。位置、形、振る舞いは `specs/hud.md` にある。

## 背景

抑止の開始と解除を、画面の表示でも知らせたい。利用者が見慣れた macOS の明るさ表示や Revisual の表示に近いものが望ましい。

## 選択肢

- Apple の明るさ表示（システムの HUD）を呼び出す。公開 API がないと見込んでいる（`HYP-HUD-001`）（不採用）。
- アプリが自前でパネルを描く（採用）。

## 理由

Apple の明るさ表示を呼び出す公開 API がないため（`HYP-HUD-001`）。

## 影響

- パネルの見た目、表示時間、フォーカスとクリックの扱いをアプリが実装する（`SPEC-HUD-003`〜`SPEC-HUD-008`）。素材と動きの選択は `DEC-UI-004` にある。
- 見た目を macOS の更新に合わせて保守する手間を引き受ける。

## 覆す条件

- `HYP-HUD-001` が外れ、システムの HUD に任意の内容を表示できる公開 API が見つかったら見直す。
