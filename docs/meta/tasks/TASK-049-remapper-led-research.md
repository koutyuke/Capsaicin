---
schema: task
id: TASK-049
title: キー配列を変えるアプリと Caps Lock の LED の関係を、読み取りだけで調べる
status: todo
requirements: ["REQ-LED-003", "REQ-LED-004", "REQ-LED-007"]
depends_on: []
assignee: Codex（Codex のハーネス、推論 high 以上）
---

# TASK-049 キー配列を変えるアプリと Caps Lock の LED の関係を、読み取りだけで調べる

## 目的

Karabiner-Elements に限らず、キー配列を変えるアプリ全般に通用する LED の扱いを選ぶための材料を集める。書き込みの対象と案内の条件は、仮想キーボードを `Transport` の有無で見分けることに頼っている（`DEC-LED-006`、`HYP-LED-007`）。この見分け方と、書き込みのたびに一覧を取り直す方式（`TASK-053`）が、ほかのアプリや環境でも成り立つかを調べる。

## 調べること

- **A1 方式の分類**: 主なキー配列の変更の仕組みを、方式で分ける。占有と仮想キーボード、イベントタップ、OS の割り当て（`UserKeyMapping`、修飾キーの設定）、機器のファームウェアや専用ソフトである。対象は Karabiner-Elements、Kanata、Raycast の Hyper Key、Keyboard Maestro、BetterTouchTool、Hammerspoon、Logi Options+、Razer Synapse、システム設定の修飾キー、`hidutil` などとする。アプリごとに、占有するか、仮想キーボードを作るか、LED に書くか、Caps Lock の状態をどこから得るかを、公式の資料とソースで示す。
- **A2 実機と仮想の区別**: IOHIDFamily と DriverKit（HIDDriverKit）のソースで、仮想デバイスに付く属性と、実機のバスに付く属性を確かめる。`IOHIDUserDevice` と DriverKit の仮想デバイスの両方を対象にする。`Transport` の有無で足りるか、もっと確かな属性があるかを答える。
- **A4 一覧の追従**: Passive のクライアントの `IOHIDEventSystemClientCopyServices` が、作成後のサービスの増減を反映する条件を、公開ヘッダーと公開ソースで確かめる。run loop やキューへの登録、追加・削除の通知の API を含む。本体が非公開で確かめられない場合は、その旨を書く。

占有の検出（以前の A3）は、`DEC-LED-006` で案内の判定に使わないと決めたので、調べない。

## 範囲

書いてよい: なし（リポジトリのファイルを変更しない）。報告は PM への返答で行う。

読むもの:

- `HYP-LED-002`、`HYP-LED-005`〜`HYP-LED-010`、`EVID-LED-002`、`EVID-LED-005`〜`EVID-LED-010`、`DEC-LED-001`、`DEC-LED-006`
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/` と `Packages/CapsaicinKit/Sources/CapsaicinLEDShim/`
- 外部のソースと資料。リポジトリの外に clone してよい。

## 作るもの

A1、A2、A4 の問いへの答えを、次の形で返す。

1. 結論（問いごとに数行）
2. 根拠。ソースはコミット、ファイル、行で示す。Web の資料は実際に開いた URL だけを示す。確かめた事実、ソースからの推論、未確認の推測を分ける。
3. 根拠にできる事実の下書き。ID は付けず、PM が振る。

## 守ること

- 読み取りだけで行う。`HIDCapsLockLED` への書き込み、Caps Lock の操作、Capsaicin や `scripts/manual/` の実行、Karabiner-Elements の起動・停止・設定変更、`sudo`、`launchctl` をしない。
- `hidutil list`、`ioreg`、`log show` の読み取りと、`~/.config/karabiner/karabiner.json` の読み取りはしてよい。読んだ設定の内容を外部に送らない。
- サブエージェントを起動しない。
- アプリ名の一覧に頼る判定を、最初の答えにしない。汎用の判定が成り立たないと分かった場合に、その根拠とともに示す。

## 完了条件

- A1、A2、A4 のそれぞれに、根拠つきの答えか、確かめられなかった理由がある。
- A1 の表に、少なくとも Karabiner-Elements、Kanata、Raycast の Hyper Key、Keyboard Maestro、BetterTouchTool、Hammerspoon、システム設定の修飾キー、`hidutil` の `UserKeyMapping` がある。

## 検証

PM が報告の根拠を読み、主要な主張をソースで照合する。リポジトリの変更がないことを `git status --short` で確かめる。

## レビュー

未着手。
