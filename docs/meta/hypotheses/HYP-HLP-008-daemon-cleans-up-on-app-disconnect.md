---
schema: hypothesis
id: HYP-HLP-008
title: デーモンは、on を送ったアプリの強制終了による XPC 接続の切断を受け取り、off を実行できる
status: supported
affects: ["REQ-LCY-003", "SPEC-LCY-003", "SPEC-HLP-002", "DEC-LCY-008"]
evidence: ["EVID-HLP-010", "EVID-BLK-015", "EVID-HLP-013"]
---

# HYP-HLP-008 デーモンは、on を送ったアプリの強制終了による XPC 接続の切断を受け取り、off を実行できる

## 主張

アプリがヘルパーとの XPC 接続を開いたまま `on` を送り、その接続を保っている間、次のすべてが成り立つ。

1. デーモンは、接続が開いている間は終了しない（今は最後の要求から 30 秒で終了する）。
2. アプリが `SIGKILL` か `SIGSEGV` で終了すると、デーモンはその接続の切断（`XPC_ERROR_CONNECTION_INVALID`）を受け取る。
3. デーモンは切断を受けて `off` を実行し、`pmset -g` が `SleepDisabled 0` を示す。アプリの終了から数秒以内に起きる。

## 外れたときに起きること

クラッシュの後の `SleepDisabled` の後片付けを、agent による再起動なしで保てない。agent をやめる方針（クラッシュ時の再起動と抑止の再開の削除）を見直し、`DEC-LCY-008` の構成を残すか、別の後片付けを探す。

## 確かめ方

オーナーが、試作のアプリ（ブランチ `spike/daemon-cleanup-probe`、`TASK-114`）と、`docs/manual/verification/` の手順書で確かめる。抑止中にアプリを `kill -9` と `kill -SEGV` で終了させ、`pmset -g` とデーモンのログを見る。ヘルパーの登録は永続的なシステム変更で、`SleepDisabled` が 1 のまま残ったら `sudo pmset -a disablesleep 0` で戻す。

## 結果

実機で支持された（`EVID-HLP-010`）。`SIGKILL` の2回と `SIGSEGV` の1回のどれでも、デーモンは役目を持つ間アイドルで終了せず、切断を受けて `off` を実行した。`SleepDisabled` は終了の約1秒後に 0 で、アプリは再起動しなかった。
