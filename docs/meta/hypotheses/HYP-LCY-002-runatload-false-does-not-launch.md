---
schema: hypothesis
id: HYP-LCY-002
title: RunAtLoad が false で KeepAlive が Crashed だけなら、LaunchAgent を読み込んでもアプリは起動しない
status: open
affects: ["DEC-LCY-002", "REQ-LCY-001", "SPEC-LCY-001"]
evidence: []
---

# HYP-LCY-002 RunAtLoad が false で KeepAlive が Crashed だけなら、LaunchAgent を読み込んでもアプリは起動しない

## 主張

`RunAtLoad = false` と `KeepAlive = { Crashed = true }` の LaunchAgent は、ログイン時や `launchctl bootstrap` で読み込んだだけではアプリを起動しない。`launchctl kickstart` で起動したアプリがクラッシュしたら、launchd が起動し直す。

## 外れたときに起きること

「ログイン時に起動する」をオフにしても、ログイン時にアプリが起動してしまう。`DEC-LCY-002` の切り替え方を見直し、`SPEC-LCY-001` を満たす別の方法が要る。

## 確かめ方

`TASK-009` の専用プローブと [`LaunchAgent の非起動条件を調べる準備`](../../../scripts/manual/launchagent-probe/README.md) を使う。独立レビュー後、実行者が対象と影響を確認して実機操作を行う。エージェントは登録しない。

初回 bootstrap と再ログイン時の非起動を別々に観測し、kickstart で実際に起動できることも確かめる。起動不能や承認待ちを、非起動条件の成立とは扱わない。クラッシュは専用プローブの自己クラッシュで起こし、保存した数値 PID へ signal を送らない。対象ラベルの解除と専用ファイルの撤去は、同じ手順に従う。

成功は、初回 bootstrap と再ログインでは起動せず、手動起動後のクラッシュでは起動し直すこと。いずれかが異なれば失敗とし、登録や実行資格を確かめられなければ判定不能とする。専用プローブの観測を、本体アプリのバックグラウンド承認まで保証した結果には広げない。

## 結果

未確認。
