---
schema: decision
id: DEC-BLK-001
title: スリープの種類ごとに抑止の方式を使い分ける
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-BLK-001", "REQ-BLK-002", "REQ-BLK-003", "REQ-BLK-004"]
based_on: ["EVID-BLK-001", "EVID-BLK-002"]
---

# DEC-BLK-001 スリープの種類ごとに抑止の方式を使い分ける

## 結論

| 止めるスリープ | 方式 | root |
| --- | --- | --- |
| 自動スリープ | 電源管理アサーション `PreventUserIdleSystemSleep` | 不要 |
| 画面の自動消灯 | 電源管理アサーション `PreventUserIdleDisplaySleep` | 不要 |
| 手動スリープと蓋閉じスリープの両方 | ヘルパー経由で `pmset -a disablesleep 1`（`DEC-HLP-001`） | 必要 |

## 背景

止めたいスリープは4種類ある。電源管理アサーションは一般ユーザーの権限で使えるが、Apple の SDK の説明では、アサーションを作っていても蓋を閉じたとき、Apple メニューからのスリープ、低バッテリーではスリープする（`EVID-BLK-001`）。手動スリープと蓋閉じスリープを止めるには、別の方式が要る。

## 選択肢

- 4種類とも電源管理アサーションで止める。root は不要だが、手動スリープと蓋閉じスリープを止められない。
- 4種類とも `disablesleep` で止める。種類ごとに選べず、常に root が要る。
- 止められる種類はアサーションで止め、手動スリープと蓋閉じスリープは root で `disablesleep` を使う（採用）。

## 理由

- 自動スリープと画面の自動消灯は、root なしで止める公開の手段があるため。
- 手動スリープと蓋閉じスリープは、アサーションでは止まらないため、`disablesleep` を使う。`disablesleep` は `pmset` の man ページに記載のない設定である（`EVID-BLK-002`）。
- `disablesleep` はシステムのスリープ全体を止めるため、手動スリープと蓋閉じスリープの片方だけを止めることはできないと見込んでいる（`HYP-BLK-006`）。

## 影響

- `disablesleep` を使う場合は、ヘルパーの設置が要る。どの設定でヘルパーが要るかは `SPEC-HLP-001` にある。
- 片方だけを止める組み合わせは設けない（`DEC-BLK-006`）。
- `disablesleep` は文書化されていないため、macOS の更新で挙動が変わる可能性を引き受ける。
- 抑止中に自動スリープを常に止める扱いは `DEC-BLK-006` にある。

## 覆す条件

- `HYP-BLK-006` または `HYP-BLK-004` が外れ、`disablesleep` で手動スリープか蓋閉じスリープを止められないと分かったら見直す。
- `HYP-SYS-001` が外れ、対応環境の macOS で `disablesleep` が効かないと分かったら見直す。
- root なしで手動スリープや蓋閉じスリープを止める公開の手段が見つかったら見直す。
