---
schema: hypothesis
id: HYP-LED-009
title: キーボードを占有しないキーの割り当ては、HIDCapsLockLED の点灯を妨げない
status: supported
affects: ["REQ-LED-001", "REQ-LED-007"]
evidence: ["EVID-LED-010"]
---

# HYP-LED-009 キーボードを占有しないキーの割り当ては、HIDCapsLockLED の点灯を妨げない

## 主張

キーボードを占有せずにキーを割り当て直す仕組みは、Capsaicin が `"On"` にした LED を消さない。対象は次のものである。

- OS の割り当て: システム設定の修飾キーの割り当て（Caps Lock を Control にするなど）、`hidutil` の `UserKeyMapping`。
- イベントタップで入力を書き換えるアプリ: Raycast の Hyper Key、Keyboard Maestro、BetterTouchTool、Hammerspoon など。

`HIDCapsLockLED` を扱う OS のキーボードフィルターは、割り当ての後も LED のモードを持ち続けるためである。これは推測で、まだ確かめていない。

## 外れたときに起きること

占有しない仕組みでも LED が消えるなら、干渉はキー配列の変更全般で起きる。案内の条件を占有に絞れない（`REQ-LED-007`）。`REQ-LED-001` の点灯を保つ前提が、割り当ての有無に左右される。

## 確かめ方

1. 調査: 主なアプリが占有と仮想キーボード、イベントタップ、`UserKeyMapping` のどれを使うかを、公式の資料とソースで確かめる（`TASK-049` の A1）。
2. 実機: `docs/manual/led-remapper-verification.md`（コミット `14fd1f7`） の B4 で、Karabiner-Elements を止めた状態で、システム設定で Caps Lock を別のキーに割り当てる。Capsaicin で抑止を始め、10分間 LED を見る。途中で割り当てたキーを押す。Raycast の Hyper Key でも同じことをする。
3. 成功: どの割り当てでも LED が点いたままで、解除で通常の動作に戻る。失敗: 割り当ての操作や時間の経過で LED が消える。

## 結果

当たった。2026-11-11 に、システム設定の修飾キーの割り当て（内蔵、Lofree の USB）と Raycast の Hyper Key で、割り当てたキーを押した後も10分後も LED が点いたままだった（`EVID-LED-010`）。`hidutil` の `UserKeyMapping` と、ほかのアプリは確かめていない。調査（確かめ方の 1）は `TASK-049` に残っている。
