---
schema: hypothesis
id: HYP-BLK-003
title: 蓋の閉鎖を検知して disablesleep を解けば、手動スリープだけを止められる
status: open
affects: ["DEC-BLK-004"]
evidence: []
---

# HYP-BLK-003 蓋の閉鎖を検知して disablesleep を解けば、手動スリープだけを止められる

## 主張

`disablesleep 1` の状態で蓋の閉鎖を検知し、すぐに `disablesleep 0` に戻すと、Mac は蓋を閉じた状態でスリープに入る。

## 外れたときに起きること

`DEC-BLK-004` により、v1 ではこの方式を使わず、手動スリープだけを止めることは提供しない。そのため、成否は v1 の要件と仕様を変えない。成り立つと分かっても、検知の遅れや競合で蓋を閉じてもスリープしない危険が残るので、手動スリープだけを提供するかは `DEC-BLK-004` の覆す条件として改めて判断する。

## 確かめ方

1. 環境: 対応環境の MacBook。電源アダプターを接続した場合と外した場合の両方で試す。外部ディスプレイは外す。
2. `sudo pmset -a disablesleep 1` を実行する。
3. 試作プログラムで `AppleClamshellState` を監視し、閉じたら `sudo pmset -a disablesleep 0` を実行するようにする。
4. 蓋を閉じ、1 分後に別の端末から ping が通らないこと、蓋を開けると復帰することを確かめる。`pmset -g log` でスリープに入った時刻を見る。
5. 成功: 蓋を閉じてから短時間でスリープに入る。失敗: 蓋を閉じたままスリープに入らない、または蓋を開け直すまでスリープしない。

`pmset -a disablesleep` は再起動後も残る永続的なシステム変更である（`HYP-BLK-007`）。始める前に `pmset -g` の `SleepDisabled` の値を記録し、終わったら `sudo pmset -a disablesleep <記録した値>` で元に戻し、`pmset -g` で戻ったことを確かめる。

## 結果

未確認。
