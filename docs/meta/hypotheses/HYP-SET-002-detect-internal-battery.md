---
schema: hypothesis
id: HYP-SET-002
title: IOPSCopyPowerSourcesInfo で内蔵バッテリーの有無を判定でき、UPS と区別できる
status: open
affects: ["REQ-SET-006", "SPEC-SET-006"]
evidence: []
---

# HYP-SET-002 IOPSCopyPowerSourcesInfo で内蔵バッテリーの有無を判定でき、UPS と区別できる

## 主張

`IOPSCopyPowerSourcesInfo` の電源の一覧に、型が `kIOPSInternalBatteryType` の電源があれば内蔵バッテリーがあり、なければない。UPS をつないだデスクトップの Mac では、UPS は別の型として現れ、内蔵バッテリーとは判定されない。

## 外れたときに起きること

内蔵バッテリーのない Mac でバッテリーの行が残る、または内蔵バッテリーのある Mac で消える。`SPEC-SET-006` の判定の方法を変える。

## 確かめ方

1. 環境: 対応環境の MacBook、蓋のない Mac、可能なら UPS をつないだ蓋のない Mac。
2. 試作プログラムで電源の一覧と各電源の型を出力する。
3. 成功: MacBook だけが `kIOPSInternalBatteryType` を持ち、UPS は別の型になる。失敗: どれかが合わない。

永続的なシステム変更は伴わない。

## 結果

未確認。
