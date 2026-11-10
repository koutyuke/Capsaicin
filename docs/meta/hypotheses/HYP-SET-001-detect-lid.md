---
schema: hypothesis
id: HYP-SET-001
title: IOPMrootDomain の AppleClamshellState の有無で蓋のある Mac を判定できる
status: open
affects: ["REQ-SET-006", "SPEC-SET-006", "DEC-BLK-006"]
evidence: []
---

# HYP-SET-001 IOPMrootDomain の AppleClamshellState の有無で蓋のある Mac を判定できる

## 主張

蓋のある Mac（MacBook）では `IOPMrootDomain` に `AppleClamshellState` プロパティがあり、蓋のない Mac（Mac mini、iMac、Mac Studio、Mac Pro）にはない。外部ディスプレイの接続や蓋の開閉の状態によらず、この有無は変わらない。

## 外れたときに起きること

蓋のある Mac で「ディスプレイを閉じたとき」のポップアップが消える、または蓋のない Mac で残る。`SPEC-SET-006` の判定の方法を変える。

## 確かめ方

1. 環境: 対応環境の MacBook と、蓋のない Mac を1台以上。
2. 各 Mac で `ioreg -r -c IOPMrootDomain -d1 -w0 | grep AppleClamshellState` を実行する。MacBook では、蓋を開けた状態と、外部ディスプレイにつないで蓋を閉じた状態でも実行する。
3. 成功: MacBook ではどの状態でもプロパティがあり、蓋のない Mac にはない。失敗: どれかが合わない。

開発用の MacBook（Mac16,8）で、蓋を開けた状態でプロパティを読めることは `EVID-BLK-003` にある。永続的なシステム変更は伴わない。

## 結果

未確認。
