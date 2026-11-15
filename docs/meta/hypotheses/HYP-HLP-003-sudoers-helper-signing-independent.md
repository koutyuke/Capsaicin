---
schema: hypothesis
id: HYP-HLP-003
title: sudoers とヘルパーの方式は、コード署名の状態によらず動く
status: supported
affects: ["DEC-HLP-001", "REQ-SYS-006"]
evidence: ["EVID-HLP-003"]
---

# HYP-HLP-003 sudoers とヘルパーの方式は、コード署名の状態によらず動く

## 主張

ヘルパーとアプリが ad-hoc 署名でも、別の Mac でビルドしたものでも、sudoers のルールでヘルパーの `on` と `off` をパスワードなしで実行でき、起動時の LaunchDaemon もヘルパーの `off` を実行できる。

## 外れたときに起きること

将来ほかの人に配った場合に、ヘルパーが動かない。`REQ-SYS-006` を満たせず、`DEC-HLP-001` を見直す。

## 確かめ方

1. 環境: 対応環境の Mac を2台。1台目でビルドし、配布の形（ダウンロードした状態、隔離属性付き）で2台目に持ち込む。
2. 2台目で `SPEC-HLP-001` の手順でヘルパーを設置し、`sudo -n` で `on` と `off` を実行する。
3. アプリを終了してから `sudo -n` でヘルパーの `on` を実行し、再起動の直前に `pmset -g` が `SleepDisabled 1` を示すことを確かめる。アプリの終了処理が `off` を実行するので、`on` はアプリの終了後に行う。
4. 再起動してログインし、アプリを起動せずに `pmset -g` を見て、`sudo launchctl print system/<LaunchDaemon のラベル>` で LaunchDaemon が起動後に実行されて正常に終了したことを確かめる。
5. 成功: 手順 2 が動き、手順 4 で `SleepDisabled 0` と LaunchDaemon の実行の記録がある。失敗: Gatekeeper などに止められ、どれかが動かない。

この確認は、承認を得た実機でだけ行う（`DEC-SYS-008`）。

ヘルパー、sudoers のルール、LaunchDaemon の設置と `disablesleep` の変更は、永続的なシステム変更である。終わったら `SPEC-HLP-004` の削除を行い、`pmset -g` の `SleepDisabled` を始める前の値に戻す。

## 結果

支持された（`EVID-HLP-003`）。CI でビルドした ad-hoc 署名の配布物を、隔離属性が付いた状態で別の Mac に入れた。その Mac で、`sudo -n` によるヘルパーの `on` と `off` がパスワードなしで終了コード 0 で終わった。再起動後には、アプリを起動しないまま `SleepDisabled` が 0 で、LaunchDaemon は終了コード 0 を残していた。確かめたのは1台の Mac、1つの macOS のバージョンだけである。
