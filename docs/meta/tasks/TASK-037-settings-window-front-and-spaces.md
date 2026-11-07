---
schema: task
id: TASK-037
title: 設定画面を確実に前面に出し、Space の振る舞いを決める
status: in_review
requirements: ["REQ-SET-002", "REQ-MENU-005"]
depends_on: []
assignee: PM（差分が数行のため PM が直接直した）
---

# TASK-037 設定画面を確実に前面に出し、Space の振る舞いを決める

## 目的

オーナーから、ステータスアイコンのメニューで設定画面を開いても前面に出ないことがあり、設定画面のあるデスクトップへも移らない、と報告があった。オーナーが求める振る舞いは次の2つである。

1. 設定画面がすでにあれば、そのデスクトップへ移って前面に出す。
2. なければ、いま見ているデスクトップの最前面に出す。

原因は、`NSApp.activate()` が協調的な有効化で、前面のアプリに断られうることだと推測した（`EVID-SET-001`）。Space の扱いはコードで何も決めておらず、macOS の既定の動きに任せていた。オーナーと相談し、一般的で安全な方法として `DEC-SET-003` に決めた。

## 範囲

書いてよい:

- `Sources/Capsaicin/Settings/SettingsWindowController.swift`
- `Sources/Capsaicin/App/AppComposition.swift`（Dock の表示を切り替えた直後に前面に戻す処理）
- `Tests/CapsaicinTests/Settings/SettingsTests.swift`
- `docs/specs/settings.md`（`SPEC-SET-001`）
- `docs/manual/verification.md`（8.4 の追加）
- `docs/meta/decisions/DEC-SET-003-settings-window-activation.md`、`docs/meta/evidence/EVID-SET-001-app-activation-for-menu-bar-apps.md`、`docs/meta/hypotheses/HYP-SET-003-forced-activation-follows-spaces.md`

触らない: 作業ツリーにある別の作業の変更（`project.yml`、`TASK-033`、`TASK-036` とヘルパー関連のステージ済みの変更）。

## 作るもの

1. `SettingsWindowController` に `bringToFront()` を置き、`NSApp.activate(ignoringOtherApps: true)`、`showWindow`、`makeKeyAndOrderFront` の順に呼ぶ。`open()` と、Dock の表示を切り替えた直後に前面に戻す処理（`AppServices.refresh`）の両方がこれを使う。
2. 設定画面の `collectionBehavior` に `.fullScreenAuxiliary` を足す。`.moveToActiveSpace` と `.canJoinAllSpaces` は付けない。
3. `SPEC-SET-001` に前面と Space の振る舞いと受け入れ例を足し、手動の確認手順を `docs/manual/verification.md` の 8.4 に足す。

## 守ること

- 遅延、Dock を経由した有効化、活性化の方針の一時的な切り替えなどのハックを足さない。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。

## 完了条件

- 設定画面を前面に出す処理が `bringToFront()` の1か所にまとまっている。
- 設定画面の `collectionBehavior` に `.fullScreenAuxiliary` があり、`.moveToActiveSpace` と `.canJoinAllSpaces` がないことをテストで確かめている。
- `nix develop --command just check` と `nix develop --command just build` が通る。
- 実機での確認（`docs/manual/verification.md` の 8.4）はオーナーが行い、結果で `HYP-SET-003` を更新する。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 前面に出るかと Space の移動は自動テストで確かめられないので、8.4 でオーナーが確かめる。

## レビュー

PM が直接直した。`nix develop --command just build` が通り、`activate(ignoringOtherApps:)` に廃止の警告が出ないことを確かめた。実機での確認が済むまで `in_review` にしておく。
