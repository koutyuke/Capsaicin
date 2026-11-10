---
schema: task
id: TASK-033
title: アプリアイコンを組み込む
status: in_review
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

オーナーの承認を得て実装した。

- `capsaicin.icon` を `Sources/Capsaicin/Resources/` に置き、`project.yml` で親の `Sources/Capsaicin` から除外したうえで、`type: file` / `buildPhase: resources` として追加した。XcodeGen 2.44.1 は `.icon` をディレクトリとして再帰展開し、中の `icon.json` と SVG を個別のリソースにするため、そのままでは `actool` が走らない。
- `createIntermediateGroups: true` がないと、中間の `Resources` グループがプロジェクトに接続されず、アイコンのパスがリポジトリ直下に解決されて `actool` が失敗した。
- XcodeGen はアプリターゲットに既定で `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` を設定するため、`capsaicin` で上書きした。
- テストターゲットも `Sources/Capsaicin` を取り込むので、同じ `.icon` を除外した。除外しないと、テストバンドルへ `icon.json` と SVG をコピーしようとしてテストのビルドが落ちる。
- `treefmt.nix` の除外に `**/*.icon/**` を足した。`icon.json` は Prettier の整形対象で、そのままだと `just fmt-check` が落ちる。
- `just build` と `just test` は成功した。ビルドしたアプリの `CFBundleIconName` は `capsaicin`、`Contents/Resources/` に `Assets.car` と `capsaicin.icns` がある。
- `just fmt-check` は、この作業とは別の未コミット変更（9 個の `.xcstrings`）が整形されていないため失敗した。クリーンな HEAD の一時コピーに同じ変更を当てると成功することを確認した。範囲外なので直していない。
- Finder、Dock、設定画面の「このアプリについて」での見た目（ダーク、クリア、ティントを含む）はオーナーが確認する。
