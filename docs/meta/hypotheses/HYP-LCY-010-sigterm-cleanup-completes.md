---
schema: hypothesis
id: HYP-LCY-010
title: バックグラウンドの項目のオフで SIGTERM を受けたアプリは、SIGKILL を受ける前に終了時の後片付けを終えられる
status: open
affects: ["SPEC-LCY-002", "SPEC-HLP-004", "DEC-LCY-012"]
evidence: []
---

# HYP-LCY-010 バックグラウンドの項目のオフで SIGTERM を受けたアプリは、SIGKILL を受ける前に終了時の後片付けを終えられる

## 主張

loginwindow は `SIGTERM` を送った後、アプリが `applicationShouldTerminate` の後片付け（LED を連動に戻す、輝度を戻す、ヘルパーへの `off`、アサーションの解放）を終えるまで `SIGKILL` を送らない。後片付けの後、LED は Caps Lock の状態に連動し、「明るさを0」で下げた輝度は元に戻る。

## 外れたときに起きること

後片付けの途中で打ち切られ、LED や輝度が残る。`SPEC-LCY-002` の受け入れ例が満たせない。`DEC-LCY-012` を見直す。

## 確かめ方

`SIGTERM` を通常の終了の経路に流す実装（`78b6ffa`）を Developer ID で署名したビルドで、オーナーが項目をオフにする。抑止中（「ディスプレイを閉じたとき」が「オンのまま」）と、「明るさを0」で輝度を下げている間の2つで、LED、輝度、`pmset -g`、ログを読む。

## 結果

未確認。
