---
schema: decision
id: DEC-CLI-002
title: CLI とアプリは利用者専用の Unix ドメインソケットで通信する
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-CLI-001", "REQ-CLI-002", "REQ-CLI-003", "REQ-CLI-004", "REQ-SYS-006"]
based_on: []
---

# DEC-CLI-002 CLI とアプリは利用者専用の Unix ドメインソケットで通信する

## 結論

- 利用者だけが読み書きできるディレクトリ（`0700`）に置いた Unix ドメインソケットで通信する。接続相手の uid を `getpeereid` で照合する。要求と応答はバージョン付きの JSON にし、大きさの上限とタイムアウトを持つ。
- アプリが起動していないときは、CLI は自分を含む `.app` を起動の対象にする。振る舞いは `SPEC-CLI-004` にある。

## 背景

CLI は `on`、`off`、`status` をアプリに伝え、`status` では応答を受け取る必要がある。Apple Developer Program に加入せず、署名に依存しない方式を選ぶ（`DEC-SYS-004`）。

## 選択肢

- LaunchAgent の Mach サービスと XPC。安定した署名がないと、相手を確かめる手段がない（不採用）。
- Distributed Notifications。返事を受け取れず、誰でも送れる（不採用）。
- URL スキーム。`status` の応答を返せない（不採用）。
- AppleEvents。自動化の許可ダイアログが出る（不採用）。
- 利用者専用の Unix ドメインソケット（採用）。

## 理由

- 署名に頼らず、ファイルの権限と uid の照合で、同じ利用者のプロセスだけに限れるため。
- 応答を返せるので、`status` と終了コード（`SPEC-CLI-007`）を実現できるため。
- 自分を含む `.app` を起動するのは、bundle ID で探すと別の場所にある同じアプリを起動しうるため。

## 影響

- 同じ利用者のほかのプロセスも CLI と同じ要求を送れる。被害は抑止の開始と解除にとどまる。
- Debug ビルドはソケットの場所を分ける（`DEC-SYS-008`）。

## 覆す条件

- 安定した署名を前提にできるようになり、XPC で相手の署名を確かめられるようになったら見直す。
