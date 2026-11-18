---
schema: hypothesis
id: HYP-HLP-010
title: 抑止中にデーモンが落ちても、アプリは接続を張り直して on を送り直し、後片付けの役目を戻せる
status: open
affects: ["SPEC-HLP-002", "SPEC-HLP-005", "SPEC-BLK-007"]
evidence: []
---

# HYP-HLP-010 抑止中にデーモンが落ちても、アプリは接続を張り直して on を送り直し、後片付けの役目を戻せる

## 主張

抑止中に、`on` を実行したデーモンのプロセスが終了する（`sudo kill -9` で模す）と、次のすべてが成り立つ。

1. アプリは接続の中断（`XPC_ERROR_CONNECTION_INTERRUPTED`）を受け取る。`SleepDisabled` は 1 のまま残る。
2. アプリが接続を張り直して `on` を送ると、launchd がデーモンを起動し、`on` が成功する。
3. その後にアプリを `kill -9` で終了させると、新しいデーモンが `off` を実行する（`HYP-HLP-008` と同じ）。

## 外れたときに起きること

デーモンが落ちた後は、アプリが動いていても後片付けの担い手がいない。張り直しをやめ、合わせられていない制御として警告する方式（`SPEC-BLK-007`）で扱う。

## 確かめ方

オーナーが、試作のアプリ（ブランチ `spike/daemon-cleanup-probe`、`TASK-114`）と、`docs/manual/verification/` の手順書で確かめる。`sudo kill` はデーモンのプロセスだけに向ける。`SleepDisabled` が 1 のまま残ったら `sudo pmset -a disablesleep 0` で戻す。

## 結果

未確認。
