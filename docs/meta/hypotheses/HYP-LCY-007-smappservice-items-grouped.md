---
schema: hypothesis
id: HYP-LCY-007
title: SMAppService で登録した agent と daemon は、システム設定でアプリの1つの項目にまとまる
status: open
affects: ["DEC-HLP-004"]
evidence: []
---

# HYP-LCY-007 SMAppService で登録した agent と daemon は、システム設定でアプリの1つの項目にまとまる

## 主張

同じアプリが `SMAppService.agent` と `SMAppService.daemon` を登録すると、システム設定の「一般 > ログイン項目と機能拡張」の「バックグラウンドでの実行を許可」には、アプリの名前とアイコンの項目が1つだけ出る。スイッチはその1つで、オフにすると agent と daemon の両方が止まる。`SMAppService.mainApp` は「ログイン時に開く」に別に出る。

## 外れたときに起きること

表示をまとめる目的を、SMAppService だけでは満たせない。項目の名前や分かれ方を、設定画面の説明や手順書で補う。`DEC-HLP-004` の構成そのものは変えない。

## 確かめ方

オーナーが、試作のアプリ（`TASK-103`）で agent、daemon、mainApp を登録した状態で、システム設定の画面写真を残す。開発元の名前として何が出るかも記録する。片付けは `HYP-HLP-005` と同じである。

## 結果

未確認。
