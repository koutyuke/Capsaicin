---
schema: hypothesis
id: HYP-BLK-004
title: disablesleep 1 はバッテリー駆動・外部ディスプレイなしでもディスプレイを閉じたときのスリープを止める
status: open
affects: ["REQ-BLK-004", "DEC-BLK-001", "SPEC-BLK-001"]
evidence: []
---

# HYP-BLK-004 disablesleep 1 はバッテリー駆動・外部ディスプレイなしでもディスプレイを閉じたときのスリープを止める

## 主張

`disablesleep 1` の状態で、電源アダプターと外部ディスプレイを外してディスプレイを閉じても、Mac はスリープしない。

## 外れたときに起きること

バッテリー駆動ではディスプレイを閉じたときのスリープを止められない。`REQ-BLK-004` に電源の条件を加えるか、`DEC-BLK-001` の方式を見直す。`SPEC-BLK-001` に条件が加わる。

## 確かめ方

1. 環境: 対応環境の MacBook。電源アダプターと外部ディスプレイを外す。
2. `sudo pmset -a disablesleep 1` を実行し、`pmset -g` に `SleepDisabled 1` が出ることを確かめる。
3. ディスプレイを閉じ、5 分後に別の端末から ping が通るかを確かめる。
4. 成功: ping が通る。失敗: ping が通らない、または `pmset -g log` にスリープの記録がある。

`pmset -a disablesleep` は再起動後も残る永続的なシステム変更である（`HYP-BLK-007`）。始める前に `pmset -g` の `SleepDisabled` の値を記録し、終わったら `sudo pmset -a disablesleep <記録した値>` で元に戻し、`pmset -g` で戻ったことを確かめる。

## 結果

未確認。
