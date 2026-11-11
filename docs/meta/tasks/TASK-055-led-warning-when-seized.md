---
schema: task
id: TASK-055
title: Karabiner-Elements の案内を、キーボードが占有されているときだけに絞る方法を決める
status: done
requirements: ["REQ-LED-007"]
depends_on: ["TASK-054"]
assignee: Codex（Codex のハーネス、gpt-6-astra、推論 xhigh）
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

Codex（Codex のハーネス、gpt-6-astra、推論 xhigh）が調査した。PM は、実機の記録（`B3-1`・`B3-6`・`B3-7` の占有の印）と報告が一致することを確かめた。外部のソースの行は、PM では確かめ直していない。

- **占有の印の読み方:** `ClientOpened` が `true`、`ClientOptions` の占有のビット（`0x01`）が立ち、`ClientSeized` が `false` のクライアントが占有元である。`ClientSeized` が `true` なのは、締め出された側である（IOHIDFamily-2238.100.59 の `IOHIDLibUserClient.cpp`）。ほかのクライアントの占有を直接読む公開の API やキーは見つからなかった。
- **占有と LED の管理は別の状態:** 「Manipulate caps lock LED」をオフにしても占有の印は残る（`B3-6`）。Karabiner-Elements は LED の管理の状態を外に出しておらず、設定ファイルを読まずに見分ける手段は見つからなかった。
- **設定ファイルを読む場合:** `profiles[選択中].devices[].manipulate_caps_lock_led` を読む。省略時の既定は `true`、機器の照合は VID・PID だけでは足りず、保存先は `XDG_CONFIG_HOME` で変わり、コメント付きの JSON も受け付ける。ディスクの内容と適用済みの設定が食い違うこともある。
- **案の比較:** 仮想キーボードの有無（案2）は、機器ごとの占有も LED の設定も分からない。プロセスの検出（案3）は、いまの問題が残る。占有の印（案1）は、アプリの終了と「Modify events」のオフを見分けられるが、LED の管理をオフにしても案内が残る。
- **調査担当の推奨:** 占有の印と設定ファイルの読み取りを組み合わせる。読めないときは「競合なし」とせず、判定不能として扱う。

オーナーの判断: 案内を Karabiner-Elements に限らず、仮想キーボードがあるときに出し、LED が点灯しない可能性だけを伝える（`DEC-LED-006`）。占有の印と設定ファイルの読み取りは、実装の重さに見合わないので採らない。光らせるキーボードを選ぶ設定は、この問題を避けられないので作らない。実装は `TASK-056` で行う。
