---
schema: task
id: TASK-014
title: 設定ウインドウとホットキーを作る
status: done
requirements: []
depends_on: [TASK-011]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-014 設定ウインドウとホットキーを作る

## 目的

設定ウインドウの全セクションと、ホットキーの登録・記録欄を作る。

## 範囲

書いてよい:

- `Sources/Capsaicin/Settings/`（新設。セクションごとの String Catalog を含む）
- `Sources/Capsaicin/Hotkey/`（新設）
- `Tests/CapsaicinTests/Settings/`、`Tests/CapsaicinTests/Hotkey/`
- `project.yml`（KeyboardShortcuts のパッケージの追加だけ）

触らない: `Sources/Capsaicin/App/`、`Sources/Capsaicin/MenuBar/`、`Sources/Capsaicin/HUD/`、`Packages/`、`docs/`。設定ウインドウを開く処理とホットキーの登録は、`AppModel` と `AppComposition` につなぐ口（型と関数）まで作る。実際につなぐのは PM が行う。つなぐのに必要な変更は、報告に書く。

## 作るもの

仕様は `docs/specs/settings.md` のすべて、`docs/specs/hotkey.md`、`docs/specs/helper.md`（`SPEC-HLP-001`、`SPEC-HLP-004`、`SPEC-HLP-006`）、`docs/specs/cli.md`（`SPEC-CLI-005`、`SPEC-CLI-006`）、`docs/specs/lifecycle.md`（`SPEC-LCY-001`、`SPEC-LCY-004`、`SPEC-LCY-005`）、`docs/specs/led.md`（`SPEC-LED-003`、`SPEC-LED-005`）、`docs/specs/ui.md` に従う。方式は `DEC-SET-001`、`DEC-BLK-004`、`DEC-UI-002`〜`DEC-UI-004`、`DEC-KEY-001`、`DEC-KEY-002` にある。デザインの補足は `.t3-code/drafts/design/design-spec.md` の「3. 設定ウインドウ」「6. ダイアログ」「7. ホットキーの記録欄」と `.t3-code/drafts/design/mockups/settings.html` にある。食い違うときは仕様を正とする。

1. **ウインドウとサイドバー**（`SPEC-SET-001`）。
2. **各セクションの行と既定値**（`SPEC-SET-002`〜`SPEC-SET-004`）。
3. **止めるスリープの見せ方**（`SPEC-SET-005`。変種 A・B、含意による無効、前提による無効）と、その Mac にない機能の行（`SPEC-SET-006`）。
   - 表示は Core の `SleepSettingsPresentation` を使い、規則をビューで書き直さない。
4. **ヘルパーのセクション**（`SPEC-HLP-004`）と、設置・修復・削除の確認とエラーのダイアログ（`SPEC-HLP-006`）。
   - Platform の `HelperInstaller` と `HelperSleepController.installationState` を使う。
   - 設定から設置を始める流れ（`SPEC-HLP-001`）を含める。
5. **設定の変更の反映**。
   - 変更は `AppModel.changeSettings` を通す。
   - 戻されたときは、スイッチを戻し、エラーのダイアログを出す（`SPEC-BLK-009`）。
6. **ホットキー**（`SPEC-KEY-001`、`SPEC-KEY-002`）。
   - KeyboardShortcuts を `project.yml` に、版を固定してアプリだけの依存として足す（`DEC-KEY-002`）。
   - 記録欄を「操作」セクションに置く。
   - 押されたら `AppModel.toggleByHotkey()` を呼ぶ口を作る。

文言はセクションごとの String Catalog に入れる。`.t3-code/drafts/copy/copy-deck.md` に文言があればそれを使い、なければ仮の日本語にする。

## 守ること

- テストでアプリを起動しない。ヘルパーの設置、`osascript`、`launchctl` を実行しない。
- 行の表示や操作できるかの判断は、モデルから作る関数にしてテストする。
- 見た目は、`DEC-SYS-008` のとおり、ビューを画像に描画して確かめる（ライトとダーク）。画像は `.build/` に置く。
- 短く素直に書く（`TASK-010` を参照）。本番コードに `REQ-*` と `SPEC-*` を書かない。`git commit` をしない。
- 同じ作業ツリーで、`TASK-013` の担当が `Sources/Capsaicin/MenuBar/` と `Sources/Capsaicin/App/` を並行して変更する。そちらには触らない。

## 完了条件

- 上の 1〜6 がある。
- 行の表示の判断と、設定から設置する流れの分岐にテストがある。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`

## レビュー

PM がレビューした。描画した 7 セクションの画像で、標準の `Form`、スイッチ、スライダー、ステッパー、タイトルバーを使っていることを確かめた（オフスクリーンの描画では、サイドバーの選択が黒く写る）。KeyboardShortcuts 3.1.0（MIT）を、アプリとアプリのテストだけの依存として固定した。`just check` と `just build` が通った。設定ウインドウとホットキーをアプリにつなぐ作業は、`TASK-015` で行う。
