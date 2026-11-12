---
schema: task
id: TASK-066
title: メニューの構成、入力パネル、時間の長さの入力欄を作り直す
status: done
requirements: ["REQ-MENU-002", "REQ-MENU-007", "REQ-LED-007", "REQ-SET-001", "REQ-UI-003"]
depends_on: ["TASK-063", "TASK-065"]
assignee: Codex（OpenCode、openai/gpt-6.1-sol、variant high）
---

# TASK-066 メニューの構成、入力パネル、時間の長さの入力欄を作り直す

## 目的

`DEC-MENU-004`、`DEC-LED-007`、`DEC-UI-013` を実装する。時間の置き換えの処理は TASK-065 で作ったものを使う。

## 範囲

書いてよい:

- `Sources/Capsaicin/MenuBar/`（`MenuBar.xcstrings` を含む）
- `Sources/Capsaicin/Settings/SettingsControls.swift`、`SettingsView.swift`、`SettingsModel.swift`（時間の長さの入力欄を共通にすることと、メニューから設定画面と同じ流れで設定を変えることに必要な分だけ）。共通の入力欄のために新しいファイルを1つ足してよい。
- `Sources/Capsaicin/App/AppComposition.swift`（メニューに設定の操作を渡すことに必要な分だけ）
- `Tests/CapsaicinTests/`

触らないもの: 上記以外のすべて。`Packages/` と CLI は TASK-065 で済んでいる。`docs/` は読むだけ。`git add`、`git stash`、`git commit` をしない。

読むもの:

- `AGENTS.md`
- `DEC-MENU-004`、`DEC-LED-007`、`DEC-UI-013`、`DEC-BLK-009`、`DEC-UI-012`（文言の用語）、`DEC-UI-001`
- `docs/specs/menu.md`（`SPEC-MENU-001`〜`SPEC-MENU-004`、`SPEC-MENU-008`）、`docs/specs/ui.md`（`SPEC-UI-005`、`SPEC-UI-007`）、`docs/specs/settings.md`（`SPEC-SET-002`、`SPEC-SET-005`、`SPEC-SET-006`）、`docs/specs/led.md`（`SPEC-LED-005`）
- `Sources/Capsaicin/MenuBar/`、`Sources/Capsaicin/Settings/`、`Sources/Capsaicin/App/AppComposition.swift`

## 作るもの

- メニューの構成を `SPEC-MENU-001`、`SPEC-MENU-002` のとおりにする。キー配列の案内の項目をなくす。
- 抑止中の「オフにする時刻を変更」のサブメニュー。選ぶと TASK-065 の置き換えの要求を送る。
- スリープとディスプレイのサブメニュー（`SPEC-MENU-008`）。項目名と選択肢は設定画面と同じ String Catalog のキーを使い、設定画面と同じ変更の流れ（ヘルパーの確認、エラー、巻き戻し）を呼ぶ。同じ処理を2つ書かない。
- 入力パネル（`SPEC-MENU-003`）: 停止中と抑止中でタイトルと確定のボタンを替え、時間のパネルにオフになる時刻を出し、抑止中の初期値と閉じる条件を仕様のとおりにする。
- 時間の長さの入力欄（`SPEC-UI-005`）を1つの部品にし、パネルと設定の「継続時間」の両方で使う。
- 文言は `MenuBar.xcstrings` に足す。案は次のとおり。`DEC-UI-012` に合わない点があれば報告する。

| 場所 | 文言の案 |
| --- | --- |
| 停止中のサブメニュー | 時間を指定してオン |
| 抑止中のサブメニュー | オフにする時刻を変更 |
| 抑止中のサブメニューの見出し | 今から |
| 任意の時間 | 時間を入力… |
| 時刻 | 時刻を指定… |
| 時間の条件なし | 時間指定なし |
| スリープとディスプレイのサブメニュー | スリープとディスプレイ |
| パネルのタイトル（停止中・時間／時刻） | 時間を指定してオン／時刻を指定してオン |
| パネルのタイトル（抑止中） | オフにする時刻を変更 |
| パネルの確定のボタン（停止中／抑止中） | オンにする／変更 |
| 時間のパネルのオフになる時刻 | %@にオフ |

- テスト: 名前に仕様 ID を含め、メニューの構成（停止中・抑止中・キー配列の案内がないこと）、サブメニューの中身、スリープとディスプレイのチェックの状態とハードウェアによる出し分け、入力欄の刻み・繰り上がり・範囲の端・不正な入力、パネルの初期値を確かめる。

## 守ること

- 標準の部品をそのまま使う（`SPEC-UI-005`）。見た目を自前で描かない。
- 起こりにくい競合への防御を重ねない。既存の仕組みを使い、新しい仕組みを作らない。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。
- 仕様にない振る舞いを決める必要があったら、推測で埋めずに報告する。
- サブエージェントを起動しない。

## 完了条件

- `nix develop --command just check` と `nix develop --command just build` が通る。
- 報告に、変えたファイル、メニューの構成を文字で書いたもの、迷った点を書く。

## 検証

上のコマンドの結果。実機での見た目と操作は、PM が手順を作ってオーナーに確かめてもらう。

## レビュー

- メニューの構成、時間のサブメニュー、スリープとディスプレイのサブメニュー、入力パネル、共通の `DurationField` が仕様どおりで、標準の部品だけを使っている。
- ヘルパーの確認とエラーの出し方は、作業中の質問に PM が答え、確認・エラーが要るときだけ設定画面を前面に出して既存のシートを使う形にした。仕様（`SPEC-MENU-008`）には PM が追記した。
- スリープとディスプレイの項目の注意の副題に、(i) の説明文がまるごと入っていた。PM が `SettingsSleepRow` に注意の文だけを持たせ、副題はそれだけにした。テストの期待も合わせた。
- PM が `just check` と `just build` を流し、通った。実機での見た目と操作は、手順書の 5.2、8.1、8.5、8.6 でオーナーが確かめる。
