---
schema: hypothesis
id: HYP-SET-001
title: IOPMrootDomain の AppleClamshellState の有無で MacBook を判定できる
status: open
affects: ["REQ-SET-006", "SPEC-SET-006", "DEC-BLK-006"]
evidence: []
---

# HYP-SET-001 IOPMrootDomain の AppleClamshellState の有無で MacBook を判定できる

## 主張

MacBook では `IOPMrootDomain` に `AppleClamshellState` プロパティがあり、MacBook 以外の Mac（Mac mini、iMac、Mac Studio、Mac Pro）にはない。外部ディスプレイの接続やディスプレイの開閉の状態によらず、この有無は変わらない。

## 外れたときに起きること

MacBook で「ディスプレイを閉じたとき」のポップアップが消える、または MacBook 以外の Mac で残る。`SPEC-SET-006` の判定の方法を変える。

## 確かめ方

1. 環境: 対応環境の MacBook と、MacBook 以外の Mac を1台以上。
2. 各 Mac で `ioreg -r -c IOPMrootDomain -d1 -w0 | grep AppleClamshellState` を実行する。MacBook では、ディスプレイを開いた状態と、外部ディスプレイにつないでディスプレイを閉じた状態でも実行する。
3. 成功: MacBook ではどの状態でもプロパティがあり、MacBook 以外の Mac にはない。失敗: どれかが合わない。

開発用の MacBook（Mac16,8）で、ディスプレイを開いた状態でプロパティを読めることは `EVID-BLK-003` にある。永続的なシステム変更は伴わない。

## 結果

未確認。
