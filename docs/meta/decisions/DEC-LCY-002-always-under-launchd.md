---
schema: decision
id: DEC-LCY-002
title: アプリは常に launchd の管理下で動かす
status: superseded
supersedes: []
superseded_by: ["DEC-LCY-008"]
requirements: ["REQ-LCY-001", "REQ-LCY-003", "REQ-LCY-005"]
based_on: ["DEC-LCY-001", "EVID-LCY-001", "EVID-LCY-002", "HYP-LCY-002", "HYP-LCY-003"]
---

# DEC-LCY-002 アプリは常に launchd の管理下で動かす

## 結論

`DEC-LCY-001` を補い、アプリは常に launchd の管理下で動かす。

- LaunchAgent は常に `~/Library/LaunchAgents` に登録し、「ログイン時に起動する」は `RunAtLoad` の値で切り替える。`KeepAlive` は `{ Crashed = true }` にする。
- 直接起動されたアプリは、`launchctl kickstart` で LaunchAgent からの起動を求めて自分は終了し、launchd が起動したアプリだけを動かす。引き渡せたかは `kickstart` の成否で決める。バックグラウンド項目の照会は、初めて登録した直後にはまだ記録がないので、この判断に使わない（`EVID-LCY-002`）。

登録や起動に失敗したとき、連続してクラッシュしたときの振る舞いは `SPEC-LCY-004` と `SPEC-LCY-005` にある。

## 背景

`KeepAlive` は、launchd が起動したプロセスにしか効かない（`EVID-LCY-001`）。「ログイン時に起動する」をオフにしたとき、LaunchAgent を外すとクラッシュ時の再起動もなくなる。

## 選択肢

- 「ログイン時に起動する」がオフなら LaunchAgent を外す。クラッシュ時の再起動がなくなり、スリープ設定と LED の復旧が次の起動か Mac の起動まで遅れる（不採用）。
- LaunchAgent を常に登録し、ログイン時にはアプリが設定を見て終了する。ログインのたびに一瞬起動する（不採用）。
- LaunchAgent を常に登録し、`RunAtLoad` で切り替え、直接起動されたアプリは launchd に引き渡す（採用）。

## 理由

起動の方法やログイン時の設定によらず、クラッシュからの復旧を同じ仕組みで効かせるため。

## 影響

- 直接起動したときに、一度起動したアプリが終了し、launchd が起動し直す分だけ、表示が遅れる。
- launchd から起動されたかを判定する必要がある（`HYP-LCY-003`）。
- 利用者がバックグラウンド項目を無効にすると、クラッシュ時の再起動は効かない。

## 覆す条件

- `HYP-LCY-002` か `HYP-LCY-003` が外れたら見直す。
- `SMAppService.agent` などで、同じことを署名に依存せずに実現できると分かったら比べ直す。
