---
schema: decision
id: DEC-BLK-002
title: 蓋の開閉を監視し、閉じたら pmset displaysleepnow で画面を消す
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-BLK-005"]
based_on: ["EVID-BLK-002", "EVID-BLK-003"]
---

# DEC-BLK-002 蓋の開閉を監視し、閉じたら pmset displaysleepnow で画面を消す

## 結論

「蓋を閉じたら画面を消す」は、IOKit の `AppleClamshellState` で蓋の開閉状態を監視し、閉じたら `pmset displaysleepnow` を実行して実現する。

## 背景

蓋閉じスリープを止めると、蓋を閉じても画面が点いたままになりうる。閉じた蓋の中で画面を点けたままにしないために、蓋を閉じたときに画面を消す方式が要る。

## 選択肢

- `AppleClamshellState` を監視し、閉じたら `pmset displaysleepnow` を実行する（採用）。
- 移行元には、ほかの案の記録がない。

## 理由

- `pmset displaysleepnow` は、画面をすぐに消す操作として `pmset` の man ページに記載がある（`EVID-BLK-002`）。
- `AppleClamshellState` は一般ユーザーの権限で読める（`EVID-BLK-003`）。
- どちらも root なしで使えると見込んでおり、ヘルパーの処理を増やさずに済む（`HYP-BLK-001`、`HYP-BLK-008`）。

## 影響

- アプリは抑止中に蓋の開閉を監視し続ける。
- `pmset displaysleepnow` に root が要ると分かった場合は、ヘルパーにサブコマンドを足す必要があり、`SPEC-HLP-002` と `REQ-HLP-002` が変わる。

## 覆す条件

- `HYP-BLK-001` が外れ、`pmset displaysleepnow` に root が要ると分かったら見直す。
- `HYP-BLK-008` が外れ、一般ユーザーの権限で蓋の開閉の変化を検知できないと分かったら見直す。
