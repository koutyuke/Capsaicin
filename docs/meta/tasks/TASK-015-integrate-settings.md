---
schema: task
id: TASK-015
title: 設定ウインドウ・ホットキー・ヘルパーの操作をアプリにつなぐ
status: done
requirements: []
depends_on: [TASK-013, TASK-014]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-015 設定ウインドウ・ホットキー・ヘルパーの操作をアプリにつなぐ

## 目的

`TASK-014` で作った設定ウインドウとホットキーを、`AppModel` と `AppComposition` につなぎ、アプリとして一通り操作できる状態にする。

## 範囲

書いてよい: `Sources/Capsaicin/App/`、`Sources/Capsaicin/MenuBar/MenuBarController.swift`（「設定…」から開くつなぎだけ）、`Tests/CapsaicinTests/App/`。

触らない: `Sources/Capsaicin/Settings/`・`Hotkey/`・`HUD/` の中身（使うだけ。直す必要があれば報告する）、`Packages/`、`docs/`、`project.yml`。

## 作るもの

1. メニューの「設定…」で設定ウインドウを開く（`SettingsWindowController.open()`）。
2. サービスの開始時にホットキーを登録し、終了時に止める。押されたら `AppModel.toggleByHotkey()` を呼ぶ。
3. ヘルパーの削除の流れ（`SPEC-HLP-004`）をつなぐ。
   - `AppModel` に、Core の `resetsSleepDisabledOnHelperRemoval()`、`helperRemovalSucceeded()`、`helperRemovalFailed()`、`reconcile()` を呼ぶ口を足す。
   - 成功したときは、状態を更新して設定を保存する。
4. ヘルパーの設置と修復の後に、合わせ直しを試みる（`SPEC-HLP-001`、`SPEC-HLP-004`）。
5. 設定を戻したときのアラートは、`SettingsModel` がシートで出す。`AppComposition` の側では重ねて出さない。

## 守ること

- 短く素直に書く（`TASK-010` を参照）。テストでアプリを起動しない。ヘルパーの設置、`osascript`、`launchctl` を実行しない。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。`git commit` をしない。

## 完了条件

- 上の 1〜5 がある。削除の成功と失敗の流れと、設置の後の合わせ直しに、偽物を使ったテストがある。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`

## レビュー

PM が差分を読んでレビューした（本番コードの差分は 69 行）。設定ウインドウを「設定…」から開き、ホットキーをサービスの開始と終了に合わせて登録・解除し、ヘルパーの削除の成否と設置・修復の後の合わせ直しをモデルにつないでいる。設定を戻したときのアラートは `SettingsModel` のシートだけになった。`just check` と `just build` が通った。実機での操作は未確認である。
