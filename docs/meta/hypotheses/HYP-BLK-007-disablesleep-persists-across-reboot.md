---
schema: hypothesis
id: HYP-BLK-007
title: disablesleep の値は再起動後も残る
status: open
affects: ["DEC-HLP-001", "REQ-HLP-004", "SPEC-HLP-003"]
evidence: []
---

# HYP-BLK-007 disablesleep の値は再起動後も残る

## 主張

`pmset -a disablesleep 1` を実行した後に Mac を再起動しても、`pmset -g` は `SleepDisabled 1` を示し、Mac はスリープしない。

## 外れたときに起きること

再起動で `disablesleep` が自然に解けるので、起動時にヘルパーの `off` を実行する LaunchDaemon（`SPEC-HLP-003`、`REQ-HLP-004`）は不要になる。`DEC-HLP-001` の構成から LaunchDaemon を外せるかを見直す。

## 確かめ方

1. 環境: 対応環境の Mac。Capsaicin のヘルパーと LaunchDaemon は設置していない状態にする。
2. `pmset -g` の `SleepDisabled` の値を記録し、`sudo pmset -a disablesleep 1` を実行する。
3. Mac を再起動し、ログインして `pmset -g` を見る。
4. 成功: `SleepDisabled 1` が表示される。失敗: `SleepDisabled 0` が表示されるか、項目が表示されない。

これは永続的なシステム変更を伴う。終わったら `sudo pmset -a disablesleep <記録した値>` で元に戻し、`pmset -g` で戻ったことを確かめる。

## 結果

未確認。
