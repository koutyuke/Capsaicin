---
schema: task
id: TASK-057
title: 抑止中に接続したキーボードを点灯させる
status: in_progress
requirements: ["REQ-LED-004"]
depends_on: ["TASK-053"]
assignee: Codex（Codex のハーネス、gpt-6.1-sol、推論 high）
---

# TASK-057 抑止中に接続したキーボードを点灯させる

## 目的

抑止中に接続したキーボードが点灯しない（`EVID-LED-011`）。Capsaicin は接続の通知を受けてすぐに書くが、その時点の一覧に、接続したキーボードのサービスがまだない。サービスは、通知から約0.06秒〜約0.5秒遅れて一覧に入った。その後に書き直すきっかけがないので、点かないままになる。

`SPEC-LED-002` の「抑止中に接続したキーボードも点灯する」を満たす。`TASK-053` から引き継いだ完了条件である。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/CapsLockLEDController.swift`
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/HIDKeyboardMonitor.swift`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/LED/`

触らない: 上記以外のすべて。書き込みの対象の選び方と、仮想キーボードの検出（`VirtualKeyboardMonitor`）は変えない。

## 作るもの

- 接続・切断の通知を受けたら、いまと同じく、その場で書く。加えて、その後の5秒間、1秒ごとに書き直す。以下、これを「追いかけの書き込み」と呼ぶ。
  - 追いかけの途中で新しい通知が来たら、5秒を数え直す。追いかけは、同時に1つだけ動かす。通知が続けて届いても、通知の数だけ追いかけを増やさない。
  - 抑止の解除、`stopMonitoring()`、点灯の意図がなくなったときは、追いかけを止める。止めた後に書かない。
  - 追いかけの書き込みの失敗は、通知による書き込みの失敗と同じ扱いにする（`onReapplyFailure`）。
- 待つ仕組みは、テストで差し替えられる形にする。`VirtualKeyboardMonitor` の `Schedule` と同じ流儀でよい。テストは実時間を待たない。
- テストは次を確かめる。
  - 通知の時点では一覧になく、後から現れたサービスに、追いかけの書き込みで `"On"` を書く。
  - 追いかけの途中の通知で、5秒を数え直す。追いかけは1つだけである。
  - 抑止の解除と `stopMonitoring()` の後は、追いかけの書き込みをしない。
  - 通知がなければ、追いかけの書き込みをしない。

公開されている関数には、サービスが一覧に入った時点で届く通知がない。サービスの追加の通知を受ける非公開の関数は使わない。待つ時間を決め打ちにする代わりに、公開の関数だけで済ませる。5秒より遅れて現れるキーボードは点かないが、次のきっかけ（復帰、ロック、別の機器の抜き差し）で点く。

## 守ること

- 定期的な書き直しにしない。通知がない間は書かない（`SPEC-LED-002`）。
- `HIDCapsLockLED` に書く値、失敗の判定、`throw` するエラー、ログの書式を変えない。
- 非公開の関数を増やさない。入力監視の権限を求めない（`REQ-LED-008`）。
- 本番コードに `REQ-*`・`SPEC-*`・`HYP-*`・`DEC-*`・`EVID-*` を書かない。
- `git commit` をしない。アプリの起動や、`scripts/manual/` の実行をしない。

## 受け入れている振る舞い

- 接続の通知を登録すると、接続済みの機器の数だけ通知が届く（`EVID-LED-011`）。そのため、抑止を始めた直後にも追いかけが1回走る。
- Karabiner-Elements が LED を消しているキーボードでは、追いかけの間、LED が短く点いて消えることがある（`EVID-LED-012`）。

## 完了条件

- 上の「作るもの」を満たす。
- `nix develop --command just check` と `nix develop --command just build` が通る。
- オーナーの実機の確認で、`SPEC-LED-002` の「抑止中に接続したキーボードも点灯する」が、Lofree の 2.4 GHz と Bluetooth で満たされる。

## 検証

- PM が差分を読み、`just check` と `just build` を流す。
- 実機はオーナーが `docs/manual/led-fix-verification.md` の手順0と、手順2の操作1〜3で確かめる。接続から10秒以内に Lofree が点灯し、アプリのログの `targets` に Lofree のキーボードのサービスの登録 ID が入ることを見る。

## レビュー

実装中。
