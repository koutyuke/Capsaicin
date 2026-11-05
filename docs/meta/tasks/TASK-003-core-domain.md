---
schema: task
id: TASK-003
title: 抑止の中核となる型と規則を作る
status: todo
requirements: []
depends_on: [TASK-001, TASK-002]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-003 抑止の中核となる型と規則を作る

## 目的

設定、抑止の開始と解除、解除の条件、止めるスリープの含意、再開の判断を、副作用のない `CapsaicinCore` に実装する。macOS の API を呼ぶ部分（電源管理、LED、ヘルパー、launchd）と画面は、このあと別々のエージェントが並行して作る。その全員が使う型とポート（プロトコル）を、ここで決める。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinCore/` とそのテスト
- `Packages/CapsaicinKit/Sources/CapsaicinIPC/` の要求・応答の型（通信路は作らない）とそのテスト
- `Packages/CapsaicinKit/Package.swift`（必要な場合だけ）

触らない: アプリ、CLI、ヘルパー、`CapsaicinPlatform`、`docs/`、`project.yml`

## 作るもの

仕様は `docs/specs/blocking.md`（冒頭の「状態」と `SPEC-BLK-012` を含む）、`settings.md`、`lifecycle.md`（`SPEC-LCY-007`）、`cli.md`、`led.md`、`hud.md`、`helper.md`（`SPEC-HLP-005`）と、`docs/meta/decisions/` の判断（特に `DEC-BLK-*`、`DEC-LCY-*`、`DEC-SET-*`、`DEC-CLI-*`、`DEC-SYS-007`、`DEC-SYS-008`）に従う。

1. 設定の型と既定値。既定値は `docs/specs/settings.md` の設定表から写し、コードの中で1か所だけに置く。値の範囲（しきい値 0〜100% など）の検証を含む。保存の形式（`Codable`）を決め、未知のキーや欠けたキーを読んでも既定値で補える。
2. 抑止に使う設定値（`SPEC-BLK-012`）と、止めるスリープの含意（`DEC-BLK-004`）。設定と機器の能力（蓋の有無、バッテリーの有無、蓋閉じスリープをヘルパーなしで止められるか、ヘルパーが使えるか）から、次を求める純粋な関数:
   - 各項目の表示（自分の値、含意によるオン・無効と理由、前提による無効、非表示）
   - 実際に使う仕組みの集合（自動スリープのアサーション、画面のアサーション、蓋閉じスリープの制御、ヘルパーによる `disablesleep`）
3. 抑止の開始と解除の規則:
   - 開始の要求（どこから: メニュー、ホットキー、CLI、再開。時間の指定: なし、タイマー、指定時刻）から、解除の時刻とその由来を決める（`DEC-BLK-005`、`SPEC-BLK-003`、`SPEC-BLK-005`。暦とタイムゾーンを注入し、日付と夏時間の境目（存在しない時刻、2回来る時刻）をテストする）。
   - 開始を拒否する条件（バッテリーがすでにしきい値を下回っているなど）。
   - 解除の判定: 現在時刻と電源の状態（残量、電源アダプタの接続）から、解除の理由を返す。
   - 抑止中に設定が変わったときの扱い（時間の条件は変えない、ほかはその場で反映し、反映できなければ変更前に戻す。`SPEC-BLK-009`）。
4. 抑止を制御するコントローラー。`@MainActor` のクラスにし、OS への作用はすべてポート（プロトコル）越しに行う。ポートは少なくとも次を持つ: 電源管理のアサーション、蓋閉じスリープの制御、ヘルパーによるシステムのスリープの制御（`on`・`off` と `SleepDisabled` の読み取り）、Caps Lock の LED、電源の状態、Mac の起動時刻（`kern.boottime`）、再開用の記録の読み書き（保存の成否を返す。成否は `SPEC-LCY-007` と `SPEC-HLP-005` の分岐の入力になる）。開始・解除・設定の変更・電源の変化・時刻の経過（アプリが呼ぶ）を受け取り、ポートを操作し、状態の変化を通知する。通知には、HUD を出すかを画面側が決められる情報（きっかけと理由）を含める。開始は全部か無しか（`SPEC-BLK-010`）。LED はこの全部か無しかに含めない。解除は止めずに完了させ、合わせられなかった仕組みは「合わせられていない制御」として持ち、合わせ直しの規則に従う（`SPEC-BLK-007`）。`disablesleep` の所有は `SPEC-HLP-005` に従う。中途半端な状態を黙って残さない。
5. 再開用の記録と再開の判断（`DEC-LCY-003`、`SPEC-LCY-004`、`SPEC-LCY-006`、`SPEC-LCY-007`）。記録の値と出来事ごとの更新の順序、起動の理由（クラッシュ後、Mac の再起動・ログアウトの後、通常の起動）の判定、再開の設定と現在時刻から再開するかの判断。連続したクラッシュの扱いを含む。
6. CLI の引数の解析（時間 `30m` / `2h` / `1h30m`、時刻 `H:MM` / `HH:MM`。`docs/specs/cli.md`）。CLI とアプリの両方が使うので `CapsaicinCore` か `CapsaicinIPC` に置く。
7. `CapsaicinIPC` の要求と応答の型（`on`、`off`、`status`。プロトコルのバージョンを含む）。通信路は TASK で別に作る。

## 完了条件

- 上の規則の自明でない分岐すべてに Swift Testing のテストがあり、テスト名に仕様の ID を含む（`docs/documentation-management.md` の「コードとの対応」）。
- 本番コードに `REQ-*` と `SPEC-*` が書かれていない。AppKit、SwiftUI、IOKit を import していない。
- ポートのテスト用の偽物（fake）を、ほかのエージェントがアプリのテストでも使える形で用意する（テストターゲットに置くか、別の小さなターゲットにするかは理由を添えて決める）。
- `nix develop --command just check` が通る（文書の検査が、この作業の範囲外の理由で落ちる場合は報告する）。

## 検証

- `nix develop --command just test-package`
- `nix develop --command just check`

## レビュー

未実施。
