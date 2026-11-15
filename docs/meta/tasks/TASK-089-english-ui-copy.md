---
schema: task
id: TASK-089
title: アプリの画面の英語の文言を String Catalog に入れる
status: in_progress
requirements: ["REQ-SYS-003", "REQ-SYS-004"]
depends_on: []
assignee: Gemini（Antigravity、gemini-3.8-flash、thinking_level high）
---

# TASK-089 アプリの画面の英語の文言を String Catalog に入れる

## 目的

`DEC-SYS-017` に従い、アプリの画面に表示するすべての文字列に英語の文言を用意する。英語を読む利用者が、macOS の標準のアプリと同じ感覚で、何の操作・設定かを一目で分かるようにする。

## 範囲

書いてよい:

- `Sources/Capsaicin/**/*.xcstrings`（8ファイル）の各キーへの `"en"` の追加だけ
- `.t3-code/drafts/copy/copy-deck.en.md`（新規。Git に入らない作業用の文言の定義書）

触らないもの: 上記以外のすべて。特に、キー、`"ja"` の値、`"sourceLanguage"`（`ja` のまま。`TASK-091` で `en` に替える）、`"extractionState"`、Swift のコード、`docs/`、`project.yml`。`git add`、`git stash`、`git commit` をしない。

同じ作業ツリーで、別の担当が `docs/` と `AGENTS.md` を直している（`TASK-090`）。そのファイルには触らない。

読むもの:

- `AGENTS.md`（String Catalog の書式の節）
- `docs/meta/decisions/DEC-SYS-017-english-and-japanese-ui.md`
- 文言が出る場所と伝えること: `docs/specs/menu.md`、`docs/specs/hud.md`、`docs/specs/settings.md`、`docs/specs/helper.md`、`docs/specs/hotkey.md`、`docs/specs/ui.md`
- 用語の判断: `docs/meta/decisions/DEC-UI-009-display-and-sleep-terms.md`、`DEC-UI-011-macos-sleep-terms.md`、`DEC-UI-012-sleep-prevention-feature-name.md`
- CLI の英語の出力（用語をそろえる相手）: `docs/meta/decisions/DEC-CLI-003-english-cli-output.md` の「出力の形」
- 日本語の文言の定義書: `/Users/koutyuke/Developer/github.com/koutyuke/capsaicin/.t3-code/drafts/copy/copy-deck.md`（読むだけ。書き換えない）
- キーを使うコード（どこにどう出るかを確かめるため。読むだけ）: `Sources/Capsaicin/MenuBar/`、`Sources/Capsaicin/HUD/`、`Sources/Capsaicin/Settings/`

## 作るもの

### 英語の値

8つのカタログのすべてのキーに、次の形で `"en"` を足す。キーの数は合計 161 である。

```json
    "menu.changeTime" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "…"
          }
        },
        "ja" : {
          …
        }
      }
    },
```

- `"en"` は `"ja"` の前に置く（Xcode は言語をアルファベット順に並べる）。インデントは2つの空白、`"key" : value` の形、ファイル末尾に改行を付けない形を保つ。JSON として壊さない。
- 書式指定子（`%@`、`%d`、`%%`、`%1$@`、`%2$@` など）の数・種類は日本語と同じにする。語順のために入れ替えるときは位置指定（`%1$@`）を使い、指定子の意味を変えない。
- 日本語の訳ではなく、英語として自然な文言にする。意味と、伝える条件（いつオフになるか、何が除かれるかなど）は日本語と同じにする。

### 文言の方針

- 用語は macOS の英語の画面（システム設定の「Battery」「Lock Screen」「Displays」など）と、`DEC-CLI-003` の CLI の英語にそろえる。例: 抑止は「Sleep prevention」、解除は「turn off」。日本語で使い分けている用語（ディスプレイスリープ、システムスリープ、手動スリープなど。`DEC-UI-009`、`DEC-UI-011`、`DEC-UI-012`）は、英語でも区別が残るようにする。
- 大文字の使い方は Apple の Human Interface Guidelines に従う。メニューの項目、ボタン、ウインドウとパネルのタイトル、設定のセクション名は title-style capitalization、設定の項目名・説明・副題・HUD の理由・アラートの本文は sentence-style capitalization にする。
- HUD の解除の条件・理由は、カプセルに収まる短さにする（`SPEC-HUD-004`。最大幅 420 pt で、超えた分は末尾で省略される）。メニューの項目も、日本語と同程度の長さを目安に短くする。
- 時刻と期間（`%@` に入る `3:53 PM` や `1h 30m` など）は、コードが OS の設定に従って書式化する。文言に時刻の形を埋め込まない。
- アプリ名「Capsaicin」とコマンドの書式（`capsaicin on` など）は訳さない。

### 定義書

`.t3-code/drafts/copy/copy-deck.en.md` に、次を書く。

- 用語集: 日本語の用語と英語の用語の対応、選んだ理由（macOS のどの画面に合わせたか）。
- 大文字の使い方の方針と、HUD・メニューの長さの方針。
- コードに直接書かれている次の終了時のアラートの英語（このアラートは `TASK-091` で String Catalog に移す。カタログはまだないので、定義書にだけ書く）。
  - 見出し: 「一部の制御を元に戻せませんでした」
  - 本文: 「スリープまたは LED の制御が残っています。次に Capsaicin を起動したときに戻し直します。」
  - ボタン: 「OK」

## 守ること

- 日本語の値を変えない。日本語に問題を見つけたら、直さずに報告する。
- 文言が出る場所が仕様とコードから分からないキーは、推測で埋めずに報告する。

## 完了条件

- 8つのカタログのすべてのキーに、`state` が `translated` の `"en"` がある。
- 書式指定子の数と種類が、すべてのキーで日本語と一致する。
- 各ファイルが JSON として読め、`"sourceLanguage"`、キー、`"ja"` の値が作業前と同じである。
- 定義書がある。

## 検証

次を実行し、どちらも成功することを確かめる。

```sh
nix develop --command python3 -c 'import json,glob,re
for f in sorted(glob.glob("Sources/Capsaicin/*/*.xcstrings")):
    d = json.load(open(f))
    for k, v in d["strings"].items():
        l = v["localizations"]
        spec = lambda s: sorted(re.findall(r"%(?:\d\$)?[@d%]", s))
        assert l["en"]["stringUnit"]["state"] == "translated", (f, k)
        assert spec(l["en"]["stringUnit"]["value"]) == spec(l["ja"]["stringUnit"]["value"]), (f, k)
print("ok")'
nix develop --command just fmt-check
```

## 報告してほしいこと

- 変えたファイルと、キーの数。
- 用語集の要点（特に、スリープの種類と抑止の呼び名）。
- 判断に迷ったキー、長くなりすぎたかもしれないキー、日本語の値に見つけた問題。

## レビュー

（PM が記入する）
