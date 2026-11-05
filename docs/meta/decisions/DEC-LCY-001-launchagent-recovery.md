---
schema: decision
id: DEC-LCY-001
title: クラッシュ時の再起動とログイン時の起動を LaunchAgent で行う
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-LCY-001", "REQ-LCY-003"]
based_on: ["EVID-LCY-001"]
---

# DEC-LCY-001 クラッシュ時の再起動とログイン時の起動を LaunchAgent で行う

## 結論

launchd の LaunchAgent に `KeepAlive` の `Crashed` を指定し、アプリがクラッシュしたら再起動させる。ログイン時の自動起動も、この LaunchAgent で行う。再起動したアプリの処理は `SPEC-LCY-006` にある。

## 背景

アプリがクラッシュすると、終了時の後片付け（`SPEC-LCY-002`）が行われず、スリープできない状態や LED の点灯が残りうる（`HYP-LCY-001`）。

## 選択肢

- LaunchAgent の `KeepAlive` の `Crashed` で再起動し、起動時に後片付けをする（採用）。
- 移行元には、ほかの案の記録がない。

## 理由

- `KeepAlive` の `Crashed` を `true` にすると、クラッシュに伴うシグナルで終了したときだけ launchd がジョブを再起動するため（`EVID-LCY-001`）。利用者が正常に終了したときは再起動しない。
- ログイン時の起動も同じ LaunchAgent でまかなえ、仕組みを1つにできるため。

## 影響

- 「ログイン時に起動する」をオフにしたときに、クラッシュ時の再起動をどう保つかを決める必要がある（`DEC-LCY-002`）。
- Mac の起動時のスリープ設定の後片付けは、アプリではなくヘルパーの LaunchDaemon が持つ（`SPEC-HLP-003`）。

## 覆す条件

- LaunchAgent の再起動が、ad-hoc 署名のアプリや対応環境の macOS で動かないと分かったら見直す。
