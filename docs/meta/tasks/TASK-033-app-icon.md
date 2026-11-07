---
schema: task
id: TASK-033
title: アプリアイコンを組み込む
status: in_progress
requirements: ["REQ-UI-004"]
depends_on: []
assignee: OpenCode / DeepSeek V4.1 Flash Free
---

# TASK-033 アプリアイコンを組み込む

## 目的

オーナーが作った Icon Composer のアプリアイコンをアプリバンドルに組み込み、Finder と設定画面の「このアプリについて」で表示されるようにする。仕様は `SPEC-UI-009` に従う。

## 範囲

書いてよい:

- `Sources/Capsaicin/Resources/capsaicin.icon/`（新規。オーナーが作った素材をそのまま置く）
- `project.yml`
- `treefmt.nix`
- `docs/meta/tasks/TASK-033-app-icon.md`（このファイル）

仕様、要件、既存の画面は変えない。

## 完了条件

- `nix develop --command just gen` で生成したプロジェクトの App Icon 名が `capsaicin` になる。
- `nix develop --command just build` が通り、`Capsaicin.app/Contents/Resources/` に `Assets.car` と `capsaicin.icns` ができる。
- ビルドしたアプリの `Info.plist` の `CFBundleIconName` が `capsaicin` になる。
- `nix develop --command just fmt-check` と `nix develop --command just check` が通る。
- 設定画面の「このアプリについて」に、組み込んだアイコンが表示される。

## 検証

- `nix develop --command just build`
- `/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' .build/xcode/Build/Products/Debug/Capsaicin.app/Contents/Info.plist`
- `nix develop --command just check`
- Finder と設定画面でアイコンを見る（オーナー）。

## レビュー

実装中。
