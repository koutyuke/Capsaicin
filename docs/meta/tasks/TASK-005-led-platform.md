---
schema: task
id: TASK-005
title: Caps Lock の LED と Karabiner-Elements の検出を macOS につなぐ
status: done
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
- `docs/meta/decisions/DEC-LED-003-led-api-and-karabiner.md`、`docs/meta/evidence/EVID-LED-002-hidcapslockled-in-ioreg.md`（SDK パスと観測の適用範囲の訂正）
- `docs/meta/hypotheses/` の `HYP-LED-001-hidcapslockled-passive-client.md`、`HYP-LED-002-led-survives-karabiner.md`、`HYP-LED-003-external-keyboard-led.md`、`HYP-LCY-001-led-on-persists-after-exit.md`（LED 復旧の確認手順）
- このチケット（PM の作業・レビュー・検証記録と、後続のアプリ統合への引き継ぎ）

触らない: `CapsaicinCore`、`CapsaicinIPC`、ほかの `CapsaicinPlatform` のディレクトリ、アプリ、CLI、ヘルパー、上記以外の `docs/`、`project.yml`。ほかの場所の変更が必要なら、変更せずに報告する。

## 作るもの

仕様は `docs/specs/led.md`（`SPEC-LED-001`、`SPEC-LED-002`、`SPEC-LED-005`、`SPEC-LED-006`）に従う。方式は `DEC-LED-001`、`DEC-LED-002`、`DEC-LED-003` にある。

1. `CapsLockLEDControlling` の実装。
   - Passive 型の `IOHIDEventSystemClient` から、キーボードのサービスに `HIDCapsLockLED` を書く。点灯は `"On"`、通常の動作は `"Auto"` にする（`DEC-LED-001`、`HYP-LED-001`）。
   - 対象は、内蔵キーボードと、接続しているすべての外付けキーボードである（`SPEC-LED-002`）。
   - 点灯している間にキーボードが接続・切断されたとき、または Mac がスリープから復帰したときに、その時点の対象へ設定し直せるようにする。スリープからの復帰を受け取って呼ぶのはアプリでもよい。どちらにしたかを報告する。
   - `isAvailable` は、使う関数が OS にあるかで決める。ないときの振る舞いは `SPEC-LED-006` にある。
   - 最初の `setLit(false)` は、前のプロセスから残った点灯を戻すため、`"Auto"` の書き込みを必ず試みる。失敗したらエラーを返す。成功済みの `false` の重複要求だけは何もせず成功とする。コントローラーは、点灯に失敗した後の状態を「分からない」とみなし、解除のときに戻す操作を1回試みるためである。
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

### 2026-11-06 の実装・検証記録

- Sol / high の実装は3スイート・28テストが成功した。クライアントの生成、列挙、通知登録、書き込み、プロセス走査、タイマーをすべて偽物に差し替えた検証である。実装者は Swift 8ファイルの strict lint が警告ゼロであること、C の警告をエラーとする検査と `nm` による弱い外部参照も確認した。
- Astra / high の独立レビューでは P0〜P2 の指摘はなく、root の UID と実行パスを調べる間の PID 再利用の競合が P3 として1件あった。
- PM が候補パス取得後にプロセスの同一性を再取得し、実効 UID・名前・開始時刻の秒とマイクロ秒を比較する修正を行った。旧実装がエラーではなく `true` を返すことを RED で確認した。修正後は、新規の `@Test` 3件（うち1件はパラメーター化）を含む Karabiner の17テストが GREEN となった。対象2ファイルの strict lint は警告ゼロで、SwiftFormat も実施済みである。

`TASK-004` と合わせた状態で `nix develop --command just check` と `nix develop --command just build` が成功した。追加テストを含めた結果は `TASK-004` の検証記録にある。完了を妨げる指摘は残っていない。

### 実機検証と対応範囲

偽物の検証は、実機での権限不要・LED 点灯・入力状態の不変を証明しない。元の HYP は未検証のまま残す。手動検証は各 HYP の復旧前提を満たし、PM が承認を得て行う。

`isAvailable` は関数の有無だけを表す。実行時のクライアント生成や書き込みの失敗を、API が存在しない状態と混同しない。

Karabiner の検出対象は、v15.6.0、v16.3.0 と配置移行を根拠とする次の既知の3パスに限る。未知の配置は検出を保証しない。

- `/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_grabber`
- `/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Core-Service.app/Contents/MacOS/Karabiner-Core-Service`
- `/Applications/Karabiner-Elements.app/Contents/Helpers/Karabiner-Core-Service.app/Contents/MacOS/Karabiner-Core-Service`

公開 HID マネージャーを初回開始直後に停止する場合、初期列挙の retain が釣り合わない可能性は未確認である。上流の挙動を確認せずに `CFRelease` の回避処理を追加しない。また、接続通知から actor を1回経由しても、Passive 側の列挙に新しい機器が見える保証は未確認である。外付けの接続・再接続は実機検証に残る。

### 後続のアプリ統合への引き継ぎ

復帰時はアプリから `systemDidWake()` を呼ぶ。この呼び出しのエラーと `onReapplyFailure` は、Core が観測済み LED 状態を無効化し、警告と再試行につなげる必要がある。Core にはそのための公開入口がなく、既知の成功状態なら操作を省くため、ログを出すだけでは足りない。

このチケットは部品からのエラー通知までを扱う。アプリ統合を完了するには、後続チケットの範囲に、必要な Core のポート変更とテストを含める。このチケットでは Core を変更しない。
