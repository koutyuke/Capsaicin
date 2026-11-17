---
schema: decision
id: DEC-HLP-001
title: root の処理を専用の小さなヘルパーに限り、sudoers と起動時の LaunchDaemon から呼ぶ
status: superseded
supersedes: []
superseded_by: ["DEC-HLP-005"]
requirements: ["REQ-HLP-001", "REQ-HLP-002", "REQ-HLP-004", "REQ-SYS-006"]
based_on: ["EVID-HLP-001"]
---

# DEC-HLP-001 root の処理を専用の小さなヘルパーに限り、sudoers と起動時の LaunchDaemon から呼ぶ

## 結論

Capsomnia と同じく、アプリ本体は一般ユーザーの権限で動かし、root 権限が必要な処理だけを Capsaicin 専用の小さなヘルパーに任せる。アプリは sudoers のルールでヘルパーを呼び、Mac の起動時の後片付けも LaunchDaemon から同じヘルパーを呼ぶ。ヘルパーが受け付ける処理と構成は `specs/helper.md`、実装と設置の手順は `DEC-HLP-003` にある。

## 背景

手動スリープとディスプレイを閉じたときのスリープを止める `disablesleep` には root が要る（`DEC-BLK-001`）。Apple Developer Program に加入しないので、Apple が発行した証明書で署名できない（`DEC-SYS-004`）。また、`disablesleep` は再起動後も残ると見込んでいる（`HYP-BLK-007`）ので、アプリが動いていない状態で起動してもスリープできない状態を残さない仕組みが要る。

## 選択肢

- `SMAppService.daemon` で root ヘルパーを登録する。無料の署名で動く確証がなく、ad-hoc 署名では不安定だと移行元は述べている（`HYP-HLP-001`）（却下）。
- 従来型の LaunchDaemon のヘルパーと XPC で通信する。ad-hoc 署名では通信相手を安定して検証できず（`HYP-HLP-002`）、書くコードも最も多い（却下）。
- sudoers で `pmset` を直接許可する。root で実行する処理が Capsaicin 専用の入口にまとまらず、sudoers のルールと起動時の LaunchDaemon が別の入口を使うことになる（却下）。
- 専用のヘルパーを sudoers と起動時の LaunchDaemon から呼ぶ（採用）。

## 理由

- root で実行する処理を、Capsaicin 専用のヘルパー1か所にまとめ、sudoers のルールと起動時の LaunchDaemon が同じ入口を使えるため。
- ヘルパーの受け付ける処理を2つに絞れば、パスワードなしで root として実行できる範囲が小さくなるため。
- sudo の許可はコード署名に依存しないため、将来ほかの人に配った場合でも同じ方式で動くと見込めるため（`HYP-HLP-003`）。

## 影響

- 設置に管理者認証が要り、設置と削除の手段を設定画面に用意する必要がある（`SPEC-HLP-001`、`SPEC-HLP-004`）。
- sudoers の書式を誤ると sudo 全体が使えなくなる危険を引き受け、設置の手順で防ぐ（`DEC-HLP-003`、`EVID-HLP-001`）。
- `pmset displaysleepnow` に root が要ると分かった場合は、ヘルパーのサブコマンドが増える（`HYP-BLK-001`）。

## 覆す条件

- `HYP-HLP-003` が外れ、sudoers とヘルパーの方式が署名の状態によって動かないと分かったら見直す。
- `HYP-HLP-001` が外れ、`SMAppService.daemon` が ad-hoc 署名でも安定して動くと分かったら、選択肢を比べ直す。
- Apple Developer Program に加入することになったら、`SMAppService.daemon` を比べ直す。
