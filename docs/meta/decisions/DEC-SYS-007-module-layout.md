---
schema: decision
id: DEC-SYS-007
title: モジュールとディレクトリを役割ごとに分け、境界の規則を決める
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-SYS-004"]
based_on: []
---

# DEC-SYS-007 モジュールとディレクトリを役割ごとに分け、境界の規則を決める

## 結論

| ディレクトリ | 中身 |
| --- | --- |
| `Sources/Capsaicin/` | アプリ。メニュー、設定、HUD、ホットキー、依存の組み立て |
| `Sources/capsaicin-cli/` | `capsaicin` コマンド |
| `Sources/capsaicin-helper/` | ヘルパー（C） |
| `Packages/CapsaicinKit/` | `CapsaicinCore`（副作用のない規則）、`CapsaicinIPC`（CLI とアプリの通信）、`CapsaicinPlatform`（macOS の API を呼ぶ部分） |
| `Tests/CapsaicinTests/` | アプリのテスト |

境界の規則:

- `CapsaicinCore` は AppKit と IOKit を参照しない。時刻、電源の状態、操作の結果は入力として受け取る。
- ヘルパーは UI、IPC、設定のコードに依存しない。
- CLI は既定値や抑止の状態を自分で判断せず、アプリに問い合わせる。
- 文字列はセクション・機能ごとの String Catalog に分ける。

## 背景

複数のエージェントが並行して実装する。規則（解除の条件、含意など）は、OS に触れずに速くテストしたい（`DEC-SYS-008`）。

## 選択肢

- 1つのアプリのターゲットにまとめる。規則のテストにアプリの組み立てが要り、並行作業で競合しやすい（不採用）。
- 役割ごとに分け、境界の規則を決める（採用）。

## 理由

- 副作用のない規則を分ければ、時刻や電源の状態を差し替えてテストできるため。
- root で動くヘルパーを、ほかのコードの変更から切り離すため。
- 文字列を分ければ、並行作業での String Catalog の競合を避けられるため。

## 影響

- 副作用のある処理は、テストで差し替えられるようにプロトコルの後ろに置く（`DEC-SYS-008`）。
- 設定の型と既定値の置き場所は `DEC-SET-002` にある。

## 覆す条件

- モジュールの分け方が、変更のたびに複数のモジュールをまたぐ原因になっていると分かったら見直す。
