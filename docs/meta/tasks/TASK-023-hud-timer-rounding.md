---
schema: task
id: TASK-023
title: HUD の開始時に出すタイマーの時間が1分少なくなるのを直す
status: done
requirements: ["REQ-HUD-001"]
depends_on: []
assignee: Claude（PM）
---

# TASK-023 HUD の開始時に出すタイマーの時間が1分少なくなるのを直す

## 目的

オーナーが実機で、タイマーを 1 時間にして開始すると HUD に「59分」、2 時間なら「1時間59分」と出ることを指摘した。

HUD は開始時の時間の条件を「解除の時刻 − HUD を作った時刻」で求めている。HUD を作るのは開始の数ミリ秒後なので、1 時間なら 3599.99 秒になり、`DateComponentsFormatter` が端数の分を切り捨てて 59 分になる。既存のテストは HUD を作る時刻を開始の時刻と同じにしていたため、このずれを捉えていなかった。

表示する時間を分に四捨五入して直す。`TimeLimit` にタイマーの長さを持たせる案は、Core と保存の形式まで変わるため採らない。

## 範囲

書いてよい:

- `Sources/Capsaicin/HUD/HUDContent.swift`
- `Tests/CapsaicinTests/HUD/HUDContentTests.swift`

## 完了条件

- 解除の時刻が開始から 1 時間・2 時間のとき、開始の直後に作った HUD が「1時間」「2時間」を出す。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 見た目は、オーナーが実機で確かめる。

## レビュー

PM が実装した。追加したテストは、解除の時刻を HUD を作る時刻の 3599.99 秒・7199.99 秒後にして、「1時間」「2時間」を期待する。変更前は「59分」「1時間59分」になり失敗することを確かめた。
