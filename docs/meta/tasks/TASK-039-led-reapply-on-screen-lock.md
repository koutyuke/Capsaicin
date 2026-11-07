---
schema: task
id: TASK-039
title: スクリーンセーバーと画面のロックの後に Caps Lock の LED を点灯し直す
status: in_review
requirements: ["REQ-LED-001", "REQ-LED-004"]
depends_on: ["TASK-038"]
assignee: PM（差分が小さいため PM が直接直した）
---

# TASK-039 スクリーンセーバーと画面のロックの後に Caps Lock の LED を点灯し直す

## 目的

`TASK-038` の確認で、スクリーンセーバーと画面のロックだけでも LED が消え、戻っても点灯し直さないことが分かった（`EVID-LED-004`）。どちらも画面が眠らないので、`screensDidWakeNotification` が来ない。`DEC-LED-004` のとおり、画面のロックの開始と終了を分散通知で受けて点け直す。

## 範囲

書いてよい:

- `Sources/Capsaicin/App/ScreenLockObserver.swift`（新規）
- `Sources/Capsaicin/App/AppComposition.swift`
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/CapsLockLEDController.swift`（メソッド名とコメント）
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/LED/LEDControllerTests.swift`（メソッド名の追従）
- `docs/specs/led.md`（`SPEC-LED-002`）、`docs/manual/verification.md`（5.1 の手順4）
- `docs/meta/decisions/DEC-LED-004-reapply-on-screen-lock.md`、`docs/meta/evidence/EVID-LED-004-screensaver-and-lock-reset-capslock-led.md`
- `docs/meta/tasks/TASK-038-led-reapply-on-screen-wake.md`（完了の記録）

触らない: 作業ツリーにある別の作業の変更（`project.yml`、`TASK-033`、`TASK-036` とヘルパー関連のステージ済みの変更）。

## 作るもの

1. `ScreenLockObserver` で `com.apple.screenIsLocked` と `com.apple.screenIsUnlocked` を `.deliverImmediately` で受ける。
2. `AppServices` の復帰時の処理を `systemStateChanged()` にまとめ、Mac と画面の復帰、ロックの開始と終了のすべてから呼ぶ。
3. ロックでも呼ぶので、`reapplyAfterWake()` を `reapply()` に改める。中身は変えない。
4. `SPEC-LED-002` と手動の確認手順 5.1 に、スクリーンセーバーとロックを足す。

## 守ること

- 定期的な書き直し、遅延、プロパティの変化の監視を足さない。

## 完了条件

- スクリーンセーバーとロックから戻ったとき、LED が点灯している。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 分散通知の購読は自動テストでは確かめられない。オーナーが `SPEC-LED-002` の受け入れ例「スクリーンセーバーやロックから戻ったら点灯している」を確かめ、ロック画面の間に LED が点いているかも記録する。

## レビュー

PM が直接直した。実機での確認が済むまで `in_review` にしておく。
