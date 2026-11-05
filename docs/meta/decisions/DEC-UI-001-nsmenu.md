---
schema: decision
id: DEC-UI-001
title: メニューバーの項目には AppKit の NSMenu を使う
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-MENU-001", "REQ-MENU-003", "REQ-UI-003"]
based_on: ["EVID-UI-001", "EVID-UI-006", "HYP-UI-003"]
---

# DEC-UI-001 メニューバーの項目には AppKit の NSMenu を使う

## 結論

`NSStatusItem` に AppKit の `NSMenu` を付ける。SwiftUI の `MenuBarExtra` のウインドウ形式や、独自のポップオーバーは使わない。状態と解除の条件は、見出しの項目（`NSMenuItem.sectionHeader`）と副題（`NSMenuItem.subtitle`）で表示する。構成は `specs/menu.md` にある。

## 背景

Capsaicin の操作は、開始、解除、条件を選ぶ、設定を開く、終了だけである。抑止中は、メニューを開いている間も残り時間を更新したい（`SPEC-MENU-004`）。

## 選択肢

- SwiftUI の `MenuBarExtra` のウインドウ形式（`.window`）。フォーカスの扱いと閉じ方を自前で作る必要があり、ほかのメニューバーの項目と手触りが変わる（不採用）。
- `MenuBarExtra` の `.menu` 形式。中身の更新を細かく制御しにくい（不採用）。
- AppKit の `NSMenu`（採用）。

## 理由

- HIG は、メニューバーの項目をクリックしたらポップオーバーではなくメニューを表示するよう求めている（`EVID-UI-001`）。Capsaicin の操作はメニューで足りる。
- メニューは開くのが速く、選んだら閉じる。キーボード操作と VoiceOver の読み上げが最初から使える。
- 見出しの項目は macOS 14.0、副題は macOS 14.4 から使え（`EVID-UI-006`）、独自のビューなしに状態を表示できる。
- メニューを開いている間も、イベント追跡のランループで動くタイマーで項目を更新できると見込んでいる（`HYP-UI-003`）。

## 影響

- メニューに入力欄を埋め込まず、時間と時刻の入力は別のパネルで行う（`SPEC-MENU-003`）。

## 覆す条件

- `HYP-UI-003` が外れ、メニューを開いている間に項目を更新できないと分かったら、残り時間の表示の方法を見直す。
