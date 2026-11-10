---
schema: task
id: TASK-055
title: Karabiner-Elements の案内を、キーボードが占有されているときだけに絞る方法を決める
status: todo
requirements: ["REQ-LED-007"]
depends_on: ["TASK-054"]
assignee: 未定
---

# TASK-055 Karabiner-Elements の案内を、キーボードが占有されているときだけに絞る方法を決める

## 目的

案内は、Karabiner-Elements のプロセスがあれば出る。アプリを終了しても常駐プロセスが残るので、LED に影響しないときにも出続ける（`EVID-LED-007`、`EVID-LED-009`）。LED が点かなくなるのは、Karabiner-Elements がキーボードを占有しているときだけである。案内をその条件に絞れるかを調べ、方法を決める。

この作業は調査と提案までで、コードは変えない。実装は、PM が方法を決めてから別のチケットにする。

## 範囲

読んでよい: リポジトリのすべて、`~/capsaicin-led-check/20261111-010115/` の記録、IOHIDFamily と Karabiner-Elements の公開ソース。

書いてよい: なし。結果は PM への報告にする。

## 調べること

次の案を、確かさ、OS の版への依存、必要な権限、実装の重さで比べる。

1. **占有の印を読む:** IORegistry のキーボードのデバイスの下で、`DebugState` が `ClientOptions = 1` かつ `ClientOpened = Yes` のクライアントを探す。機器ごとに正確だが、`DebugState` はデバッグ用の値である（`EVID-LED-006`、`HYP-LED-008`）。
2. **仮想キーボードの有無を見る:** LED のクライアントの一覧に、`Transport` を持たないキーボードのサービスがあるかを見る。`TASK-054` の判定をそのまま使える。占有していない機器があっても案内が出る。
3. **いまのまま:** プロセスの検出を続け、文面で補う。

あわせて、「Manipulate caps lock LED」をオフにした機器では案内が要らないことを、Karabiner-Elements の設定ファイルを読まずに見分けられるかも調べる。

## 完了条件

- 3つの案の比較と、推奨する案、その根拠を報告する。
- 推奨する案で `REQ-LED-007` と `SPEC-LED-005` をどう変えるかを示す。

## 検証

PM が報告の根拠（ソースの行、記録のファイル）を確かめる。

## レビュー

未着手。
