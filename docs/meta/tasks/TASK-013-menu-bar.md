---
schema: task
id: TASK-013
title: メニューバーのメニューと入力パネルを作り、HUD をつなぐ
status: in_progress
requirements: []
depends_on: [TASK-011, TASK-012]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-013 メニューバーのメニューと入力パネルを作り、HUD をつなぐ

## 目的

ステータスアイコン、メニュー、時間・時刻の入力パネルを作る。あわせて、`AppModel` の出来事を HUD につなぐ。

## 範囲

書いてよい:

- `Sources/Capsaicin/MenuBar/`（`MenuBar.xcstrings` を含む）
- `Sources/Capsaicin/App/AppModel.swift`（HUD に渡すため、出来事の通知に解除の直前の状態を加える変更だけ）
- `Sources/Capsaicin/App/AppComposition.swift`（メニューと HUD をつなぐ変更だけ）
- `Tests/CapsaicinTests/MenuBar/`

触らない: `Sources/Capsaicin/HUD/` の中身（使うだけ）、`Sources/Capsaicin/Settings/`、`Packages/`、`docs/`、`project.yml`。

## 作るもの

仕様は `docs/specs/menu.md` のすべて、`docs/specs/hud.md` の `SPEC-HUD-001`、`docs/specs/ui.md`（`SPEC-UI-001`〜`SPEC-UI-007`、`SPEC-UI-010`）に従う。方式は `DEC-UI-001`（`NSMenu`）、`DEC-UI-002` にある。デザインの補足は `.t3-code/drafts/design/design-spec.md` の「4. メニューバー」と `.t3-code/drafts/design/mockups/menu.html` にある。食い違うときは仕様を正とする。

1. ステータスアイコン（`SPEC-MENU-005`、`SPEC-UI-010`）。仮のテンプレート画像でよい（正式な意匠は `Q-MENU-001` で決める）。
2. メニュー（`SPEC-MENU-001`〜`SPEC-MENU-004`）。
   - 開始・解除。
   - 時間を決めた開始。
   - 状態と解除の条件の表示。メニューを開いている間も 1 分ごとに更新する。
   - 警告の行。
   - Karabiner-Elements の案内（`SPEC-LED-005`）。
   - 「設定…」「終了」。「設定…」は、設定ウインドウを開く処理を後で差し込めるよう、`AppModel` を介さないクロージャで受けておく。
3. 時間・時刻の入力パネル（`SPEC-MENU-003`）。
4. HUD をつなぐ。
   - `AppModel` の出来事から、`SPEC-HUD-001` に従って出すかを決めて `HUDPresenter` に渡す。
   - 指定時刻で解除したときの表示に要る、解除の直前のセッションも渡す。
   - 「切り替えたときに画面に表示する」の設定がオフのときの VoiceOver の読み上げは、`SPEC-HUD-008` と `DEC-UI-005` に従う。

文言は `MenuBar.xcstrings` に入れる。`.t3-code/drafts/copy/copy-deck.md` に文言があればそれを使い、なければ仮の日本語にする。

## 守ること

- テストでアプリを起動しない。メニューを組み立てる処理は、`AppModel` と偽物から項目の並びを作る関数にして、テストする。
- 短く素直に書く（`TASK-010` を参照）。本番コードに `REQ-*` と `SPEC-*` を書かない。`git commit` をしない。
- 同じ作業ツリーで、`TASK-014` の担当が `Sources/Capsaicin/Settings/` と `project.yml` を並行して変更する。そちらには触らない。

## 完了条件

- 上の 1〜4 がある。
- メニューの項目の並び（停止中、抑止中、警告あり、Karabiner あり）と、HUD を出すかの判断にテストがある。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`

## レビュー

未実施。
