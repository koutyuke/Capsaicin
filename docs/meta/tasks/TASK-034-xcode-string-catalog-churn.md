---
schema: task
id: TASK-034
title: Xcode で開いても String Catalog に差分が出ないようにする
status: done
requirements: []
depends_on: []
assignee: Claude（PM）
---

# TASK-034 Xcode で開いても String Catalog に差分が出ないようにする

## 目的

オーナーが Xcode で作業すると、Xcode が9つの String Catalog を書き直し、`fmt-check` が落ちる差分が毎回出ていた。原因は2つあった。

- Xcode は `"key" : value`、末尾の改行なしの形で書き出すが、treefmt が Prettier で `"key": value` の形に整形していた。
- キーの多くは `bundle.localizedString(forKey:)` でコードから動的に引いているため、Xcode がコードから見つけられず、全キーに `"extractionState" : "stale"` を付けていた。

Xcode が書き出す形を正とし、動的に引くキーは CLI の String Catalog と同じく `manual` にする。Xcode は手で管理する（`manual`）キーを `stale` にしない。

## 範囲

書いてよい:

- `Sources/Capsaicin/**/*.xcstrings`（Xcode が書き出した形への置き換えと、`stale` から `manual` への変更だけ。文言は変えない）
- `treefmt.nix`
- `scripts/check_format.py`、`scripts/tests/test_check_format.py`
- `AGENTS.md`
- `docs/meta/tasks/TASK-034-xcode-string-catalog-churn.md`（このファイル）

`Sources/Capsaicin/CLI/CLI.xcstrings` は Xcode が書き直しておらず、既に `manual` なので変えない。

## 完了条件

- String Catalog が treefmt の対象から外れている。
- 9つの String Catalog に `stale` のキーがなく、文言とキーの集合は変更前と同じである。
- `fmt-check` が、String Catalog に `stale` のキーがあると失敗し、どのファイルのどのキーかと直し方を表示する。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- オーナーが Xcode でプロジェクトを開いてビルドし、String Catalog に差分が出ないことを確かめる。

## レビュー

Xcode が `manual` のキーを `stale` にしないことは、WWDC23「Discover String Catalogs」の要約による。Xcode の画面上ではまだ確かめていない。
