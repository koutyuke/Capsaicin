---
schema: task
id: TASK-005
title: Caps Lock の LED と Karabiner-Elements の検出を macOS につなぐ
status: todo
requirements: []
depends_on: [TASK-003]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-005 Caps Lock の LED と Karabiner-Elements の検出を macOS につなぐ

## 目的

`CapsaicinCore` の `CapsLockLEDControlling` を macOS の API で実装する。あわせて、Karabiner-Elements の起動と終了を検出する部品を用意する。アプリへの組み込みと案内の表示は別のチケットで行う。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/LED/`
- 公開されていない関数の宣言を閉じ込める C のターゲット（`DEC-LED-003`）が要る場合は、`Packages/CapsaicinKit/Sources/` の下の新しいディレクトリと、そのための `Package.swift` の変更

触らない: `CapsaicinCore`、`CapsaicinIPC`、ほかの `CapsaicinPlatform` のディレクトリ、アプリ、CLI、ヘルパー、`docs/`、`project.yml`。ほかの場所の変更が必要なら、変更せずに報告する。

## 作るもの

仕様は `docs/specs/led.md`（`SPEC-LED-001`、`SPEC-LED-002`、`SPEC-LED-005`、`SPEC-LED-006`）に従う。方式は `DEC-LED-001`、`DEC-LED-002`、`DEC-LED-003` にある。

1. `CapsLockLEDControlling` の実装。
   - Passive 型の `IOHIDEventSystemClient` から、キーボードのサービスに `HIDCapsLockLED` を書く。点灯は `"On"`、通常の動作は `"Auto"` にする（`DEC-LED-001`、`HYP-LED-001`）。
   - 対象は、内蔵キーボードと、接続しているすべての外付けキーボードである（`SPEC-LED-002`）。
   - 点灯している間にキーボードが接続・切断されたとき、または Mac がスリープから復帰したときに、その時点の対象へ設定し直せるようにする。スリープからの復帰を受け取って呼ぶのはアプリでもよい。どちらにしたかを報告する。
   - `isAvailable` は、使う関数が OS にあるかで決める。ないときの振る舞いは `SPEC-LED-006` にある。
2. 公開されていない関数が要る場合は、`DEC-LED-003` のとおり、小さな C のモジュールに宣言を閉じ込め、弱いリンクにする。`dlsym` と、関数の型の手作業の変換は使わない。
3. Karabiner-Elements の起動と終了の検出（`SPEC-LED-005`）。
   - 検出の方法（実行中のアプリ、プロセス、仮想 HID デバイスなど）を選び、理由を報告する。
   - 状態が変わったら、登録された処理を呼ぶ。

## 守ること

- Caps Lock の入力状態を変えない。LED の表示だけを扱う（`AGENTS.md`、`DEC-KEY-001`）。
- テストで、実際の LED に書き込まない。点灯がプロセスの終了後に残りうる（`HYP-LCY-001`）ためである。書き込みは、テストで偽物に差し替えられる境界の後ろに置く。ただし、実装が1つしかない抽象を増やさない。
- 実機でしか確かめられない振る舞い（`HYP-LED-001`〜`HYP-LED-004`、`HYP-LCY-001`）は、確かめる手順を報告に書く。手順は PM が承認を得て実行する。
- `AGENTS.md` の「破ってはいけないもの」を守る。

## 完了条件

- 上の 1〜3 があり、`CapsaicinCore` のポートか、アプリが組み込める型として公開されている。
- 自明でない分岐（対象のキーボードの選び方、接続・切断のときに設定し直す処理、関数がないときの扱い、検出の判定）に Swift Testing のテストがあり、テスト名に仕様の ID を含む。
- 本番コードに `REQ-*` と `SPEC-*` を書いていない。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just test-package`
- `nix develop --command just check`

## レビュー

未実施。
