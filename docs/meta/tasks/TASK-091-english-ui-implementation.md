---
schema: task
id: TASK-091
title: 開発言語を英語にし、画面の文字列と時刻・期間の表記を英語と日本語に対応させる
status: todo
requirements: ["REQ-SYS-003", "REQ-SYS-004"]
depends_on: ["TASK-089"]
assignee: Codex（OpenCode、openai/gpt-6.1-sol、variant high）
---

# TASK-091 開発言語を英語にし、画面の文字列と時刻・期間の表記を英語と日本語に対応させる

## 目的

`DEC-SYS-017` を実装する。アプリが macOS の言語の設定に従って英語か日本語で表示され、英語でも日本語でもない設定では英語になり、画面の時刻が OS の地域と時刻の設定に従うようにする。

## 範囲

書いてよい:

- `project.yml`（`options` の `developmentLanguage` と `knownRegions` だけ）
- `Sources/Capsaicin/**/*.xcstrings`（`"sourceLanguage"` の行だけ。値とキーは変えない）
- `Sources/Capsaicin/App/App.xcstrings`（新規）
- `Sources/Capsaicin/App/AppComposition.swift`（終了時のアラートの文字列だけ）
- `Sources/Capsaicin/MenuBar/MenuContent.swift`、`Sources/Capsaicin/HUD/HUDContent.swift`、`Sources/Capsaicin/MenuBar/StartPanel.swift`（時刻と期間の書式化と、その呼び出しだけ）
- 時刻と期間の書式化を1か所にまとめる場合だけ、`Sources/Capsaicin/` の既存のフォルダーに置く新しい Swift ファイル1つ
- `Tests/CapsaicinTests/`

触らないもの: 上記以外のすべて。特に `docs/`、`AGENTS.md`、`Packages/`、`Sources/capsaicin-cli/`（CLI の出力は `DEC-CLI-003` のまま）、`Sources/capsaicin-helper/`、カタログの既存の値。`git add`、`git stash`、`git commit` をしない。

同じ作業ツリーで、別の担当が `docs/` と `AGENTS.md` を直していることがある（`TASK-090`）。そのファイルには触らない。

読むもの:

- `AGENTS.md`（String Catalog と検証の節）
- `docs/meta/decisions/DEC-SYS-017-english-and-japanese-ui.md`（正はこれ）
- `docs/specs/ui.md` の `SPEC-UI-011`、`SPEC-UI-012`（`TASK-090` が書く。まだなければ `DEC-SYS-017` に従う）、`docs/specs/menu.md` の `SPEC-MENU-004`
- 英語の文言の定義書: `.t3-code/drafts/copy/copy-deck.en.md`（終了時のアラートの英語がある）

## 作るもの

### 開発言語

- `project.yml` の `developmentLanguage` を `en`、`knownRegions` を `[en, ja]` にする。
- 8つのカタログの `"sourceLanguage"` を `"en"` にする。英語と日本語の値は `TASK-089` で入っている。

### 終了時のアラート

- `Sources/Capsaicin/App/App.xcstrings`（テーブル名 `App`）を作り、見出し・本文・ボタンの3つのキーを置く。キーは既存のカタログと同じ命名（例: `alert.terminationIncomplete.title`）にし、`"extractionState" : "manual"` を付ける。英語は定義書から、日本語は今のコードの文字列をそのまま使う。書式は既存のカタログ（Xcode の形、末尾の改行なし）に合わせる。
- `AppComposition.swift` の `showAlert` は、ほかの画面と同じく `Bundle.localizedString(forKey:value:table:)` で引く。

### 時刻と期間

- 画面に表示する時刻（`MenuContent.time` と `HUDContent.time`）を、`H:mm` の固定をやめて、OS の地域と時刻の設定（12時間制・24時間制を含む）に従う表記にする。午前・午後などの語は、表示している言語にそろえる。
- 期間（`MenuContent` の残り時間など）も、表示している言語で示す。英語の画面に日本語の単位が出たり、その逆が起きたりしないようにする。
- `Locale.current` が、アプリの表示言語（`Bundle.main.preferredLocalizations`）と、OS の12時間制・24時間制の設定の両方を反映するかは、OS の設定と組み合わせで変わりうる。小さな実験かドキュメントで確かめてから方法を選び、確かめたことを報告する。両方を反映しない場合は、表示言語の言語と、`Locale.current` の地域と時間の表記の設定を組み合わせたロケールを使う。
- 入力パネルの `DatePicker` は OS の設定に従うので、時刻の形を固定する指定があれば外す。
- 同じ書式化が `MenuContent` と `HUDContent` に重複しているので、1か所にまとめてよい。まとめる場合も、ロケールとカレンダーを引数で受け取り、テストから差し替えられるようにする。

### 直書きの文字列の確認

- `Sources/Capsaicin/` に、String Catalog を通らずに画面に出る文字列（日本語でも英語でも）が残っていないかを探す。ログ、SF Symbols の名前、アプリ名「Capsaicin」は対象外。見つけたら、範囲内ならカタログに移し、範囲外なら変えずに報告する。

### テスト

- アプリのバンドルの開発言語が `en` であり、`App`・`MenuBar`・`HUD`・各 `Settings*` のテーブルが `en.lproj` と `ja.lproj` の両方にあることを確かめる（`Tests/CapsaicinTests/CapsaicinTests.swift`、`Settings/SettingsTests.swift` の `ja` の前提を直す）。
- 全テーブルで、`en.lproj` と `ja.lproj` のキーの集合が一致し、値がキーそのものでないことを確かめるテストを1つ足す。
- 時刻の表記のテスト: 英語・12時間制（例: `en_US`）で午後の時刻が12時間制になり、日本語・24時間制（例: `ja_JP`）で `15:53` の形になり、英語で24時間制を指定したロケールで24時間制になる。
- 期間の表記のテスト: 英語と日本語で、それぞれの言語の単位で示される。
- テスト名には仕様の ID を入れる（`SPEC-UI-011`、`SPEC-UI-012` など）。本番コードには `REQ-*` と `SPEC-*` を書かない。

## 守ること

- 起こりにくい場面への防御や、独自の仕組みを重ねない。書式化はプラットフォームの API（`Date.FormatStyle`、`DateComponentsFormatter` など）をそのまま使う。
- アプリの中に言語の設定や切り替えを作らない。
- CLI の出力とその時刻の書式は変えない。

## 完了条件

- 英語・日本語・英語でも日本語でもない設定で、それぞれ英語・日本語・英語のリソースが選ばれるバンドルになっている（テストで確かめられる範囲はテストで、それ以外は報告で示す）。
- 終了時のアラートの文字列がカタログにあり、コードに直書きがない。
- 時刻と期間が、テストで示した表記になる。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

```sh
nix develop --command just check
nix develop --command just build
```

## 報告してほしいこと

- 変えたファイルと、その理由。
- `Locale.current` について確かめたことと、選んだ方法。
- 見つけた直書きの文字列と、その扱い。
- 画面で目で確かめる必要が残ること。

## レビュー

（PM が記入する）
