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

「ログイン時に起動」をオフにしても、ログイン時にアプリが起動してしまう。`DEC-LCY-002` の切り替え方を見直し、`SPEC-LCY-001` を満たす別の方法が要る。

## 確かめ方

1. 環境: 対応環境の Mac。Debug ビルドのラベル（`DEC-SYS-008`）で試す。
2. 上の設定の LaunchAgent を `~/Library/LaunchAgents` に置き、`launchctl bootstrap gui/$(id -u) <plist>` で読み込む。アプリのプロセスがないことを確かめる。
3. ログアウトしてログインし、アプリのプロセスがないことを確かめる。
4. `launchctl kickstart gui/$(id -u)/<ラベル>` で起動し、`kill -SEGV` でクラッシュさせる。
5. 成功: 手順 2 と 3 で起動せず、手順 4 で起動し直す。失敗: 手順 2 か 3 で起動する、または手順 4 で起動し直さない。

LaunchAgent の登録は永続的なシステム変更である。承認を得て行い、終わったら `launchctl bootout gui/$(id -u)/<ラベル>` で外し、plist を削除する。

## 結果

未確認。
