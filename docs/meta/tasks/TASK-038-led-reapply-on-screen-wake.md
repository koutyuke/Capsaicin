---
schema: task
id: TASK-038
title: 画面が復帰したときに Caps Lock の LED を点灯し直す
status: in_review
requirements: ["REQ-LED-001", "REQ-LED-004"]
depends_on: []
assignee: PM（差分が数行のため PM が直接直した）
---

# TASK-038 画面が復帰したときに Caps Lock の LED を点灯し直す

## 目的

オーナーから、「蓋を閉じたら画面を消す」をオンにして蓋を閉じ、開けると、Caps Lock の LED が消えている、と報告があった。

オーナーの実験で、原因は蓋ではなく画面のスリープだと分かった（`EVID-LED-003`）。画面だけのスリープで `HIDCapsLockLED` が `"Auto"` に戻り、Karabiner-Elements が内蔵キーボードを掴んでいなくても起きた。Mac 本体は眠らないので `NSWorkspace.didWakeNotification` は来ず、キーボードの接続・切断も起きないため、既存の再適用の経路では点灯し直されなかった。

## 範囲

書いてよい:

- `Sources/Capsaicin/App/AppComposition.swift`（復帰通知の購読）
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/CapsLockLEDController.swift`（メソッド名とコメント）
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/LED/LEDControllerTests.swift`（メソッド名の追従）
- `docs/specs/led.md`（`SPEC-LED-002`）
- `docs/manual/verification.md`（5.1 の手順4）
- `docs/meta/evidence/EVID-LED-003-display-sleep-resets-capslock-led.md`

触らない: 作業ツリーにある別の作業の変更（`project.yml`、`TASK-033`、`TASK-036` とヘルパー関連のステージ済みの変更）。

## 作るもの

1. `NSWorkspace.didWakeNotification` に加えて `NSWorkspace.screensDidWakeNotification` を購読し、どちらでも同じ処理（時間の解除条件の確認と LED の再適用）を行う。
2. 画面の復帰でも呼ぶので、`CapsLockLEDController.systemDidWake()` を `reapplyAfterWake()` に改める。中身は変えない。
3. `SPEC-LED-002` の再適用のきっかけに画面の復帰を足し、受け入れ例を足す。手動の確認手順の 5.1 に、画面だけのスリープからの復帰を足す。

## 守ること

- 定期的な書き直しや遅延を足さない。
- Karabiner-Elements が内蔵キーボードを掴んでいる間の上書き（`HYP-LED-002`）は、この作業では扱わない。

## 完了条件

- 画面の復帰で LED の再適用が呼ばれる。
- `nix develop --command just check` と `nix develop --command just build` が通る。
- 実機での確認（`SPEC-LED-002` の受け入れ例「画面が復帰したら点灯し直す」）はオーナーが行う。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 通知の購読は `AppServices` の配線で、自動テストでは確かめられない。オーナーが、ビルドしたアプリで抑止中に `pmset displaysleepnow` を実行し、復帰後に LED が点いていることを確かめる。

## レビュー

PM が直接直した。実機での確認が済むまで `in_review` にしておく。
