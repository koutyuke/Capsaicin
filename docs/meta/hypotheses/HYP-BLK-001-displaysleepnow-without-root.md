---
schema: hypothesis
id: HYP-BLK-001
title: pmset displaysleepnow は root なしで画面を消せる
status: open
affects: ["DEC-BLK-002", "DEC-HLP-001", "REQ-HLP-002", "SPEC-BLK-002", "SPEC-HLP-002"]
evidence: []
---

# HYP-BLK-001 pmset displaysleepnow は root なしで画面を消せる

## 主張

一般ユーザーの権限で `pmset displaysleepnow` を実行すると、エラーにならずに画面が消える。

## 外れたときに起きること

アプリから直接画面を消せないので、ヘルパーに画面を消すサブコマンドを足す必要がある。`REQ-HLP-002` と `SPEC-HLP-002`（受け付ける処理は `on` と `off` だけ）が変わり、`DEC-BLK-002` と `DEC-HLP-001` を見直す。`SPEC-BLK-002` はヘルパーがないと動かなくなる。

## 確かめ方

1. 環境: 対応環境の Mac（`REQ-SYS-001`、`REQ-SYS-002`）。管理者ではない一般ユーザーと、管理者のユーザーの両方で試す。
2. `sudo` を付けずに `pmset displaysleepnow` を実行し、終了コードを `echo $?` で見る。
3. 成功: 終了コードが 0 で、画面がすぐ消える。失敗: 権限のエラーが出る、または画面が消えない。

永続的なシステム変更は伴わない。

## 結果

未確認。
