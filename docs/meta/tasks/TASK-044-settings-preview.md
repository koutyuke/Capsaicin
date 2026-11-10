---
schema: task
id: TASK-044
title: 設定画面を Xcode の Canvas で表示できるようにする
status: in_review
requirements: []
depends_on: ["TASK-032"]
assignee: Claude（PM）
---

# TASK-044 設定画面を Xcode の Canvas で表示できるようにする

## 目的

オーナーが、設定画面の見た目をアプリを起動せずに確かめたいと求めた。これまでは、変更のたびにアプリをビルドし直して起動し、メニューから設定画面を開く必要があった。

TASK-032 の HUD と同じく、Debug ビルドにだけ `#Preview` を置き、保存するたびに Canvas で設定画面を表示し直せるようにする。

## 範囲

書いてよい:

- `Sources/Capsaicin/Settings/SettingsPreview.swift`（新規）

仕様、String Catalog、`SettingsView` などの既存のファイルは変えない。Preview で起動されたときに起動処理を始めない対応は、TASK-032 で `AppDelegate` に入っている。

## 完了条件

- `#if DEBUG` の中だけに置き、Release ビルドには含まれない。
- Preview の表示や Live での操作で、電源管理アサーション、ヘルパー、Caps Lock の LED、再開用の記録、アプリの設定に触れない。OS に作用するポートは何もせずに成功を返す。
- 選んだセクションは、アプリとは別の UserDefaults の領域（`io.github.koutyuke.capsaicin.preview`）に書く。
- ノートでヘルパーがある構成と、デスクトップでヘルパーがなくバックグラウンドが無効な構成の2つを並べ、スリープ防止と一般の警告の行の出し分けを確かめられる。
- 寸法は `SettingsWindowController.makeWindow` と同じ 720×500 にする。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- Xcode で `SettingsPreview.swift` を開き、Canvas で各セクションを表示し、Live でスイッチを切り替えて表示が変わることを確かめる（オーナー）。

## レビュー

PM が実装した。

ツールバー、ウィンドウのタイトル、ヘルパーの確認と失敗のシートは `SettingsWindowController` の役割なので、Preview では再現しない。ヘルパーの設置は確認が既定で断られる扱いになり、何も起きない。
