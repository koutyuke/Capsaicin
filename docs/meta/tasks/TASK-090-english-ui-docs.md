---
schema: task
id: TASK-090
title: 英語と日本語の表示と、OS の設定に従う時刻の表記を、要件・仕様・手順書に反映する
status: done
requirements: ["REQ-SYS-003", "REQ-SYS-004"]
depends_on: []
assignee: Codex（OpenCode、openai/gpt-6.1-sol、variant high）
---

# TASK-090 英語と日本語の表示と、OS の設定に従う時刻の表記を、要件・仕様・手順書に反映する

## 目的

PM が書いた `DEC-SYS-017` を、要件・仕様・製品の文書・手順書・`AGENTS.md` の現在の状態に書く。

## 範囲

書いてよい:

- `docs/meta/requirements/system.toml`（`REQ-SYS-003`、`REQ-SYS-004` だけ）
- `docs/specs/ui.md`（`SPEC-UI-011`、新しい `SPEC-UI-012`、「未決のこと」だけ）
- `docs/specs/menu.md`、`docs/specs/hud.md`、`docs/specs/settings.md`（「未決のこと」の時刻の表記の論点の行と、時刻の表記や表示言語について `DEC-SYS-017` と食い違う記述だけ。なければ触らない）
- `docs/product/overview.md`（「非目標」の英語の UI の行だけ）
- `docs/meta/questions/` にある時刻の表記の論点（削除する）
- `docs/manual/verification.md`（「8. メニュー・設定・HUD・キーボード操作を確認する」への節の追加と、`SPEC-UI-011` の仮英訳試験に触れた記述だけ）
- `AGENTS.md`（String Catalog の段落だけ）

触らないもの: 上記以外のすべて。特に `docs/meta/decisions/`（読むだけ）、`docs/meta/tasks/`、`docs/documentation-management.md`、`docs/specs/cli.md`、`Sources/`、`Tests/`、`project.yml`。`git add`、`git stash`、`git commit` をしない。

同じ作業ツリーで、別の担当が `Sources/Capsaicin/**/*.xcstrings` に英語の文言を入れている（`TASK-089`）。そのファイルには触らない。

読むもの:

- `AGENTS.md`、`docs/documentation-management.md`（特に「書き方」と「記録の一生」の「論点を解決する」）
- `docs/meta/decisions/DEC-SYS-017-english-and-japanese-ui.md`（正はこれ）、`DEC-SYS-002`（置き換えられた判断）、`DEC-CLI-003`
- `docs/meta/questions/` にある時刻の表記の論点
- `docs/specs/ui.md` の全体、`docs/specs/menu.md` の `SPEC-MENU-004` と入力パネルの節、`docs/specs/hud.md` の `SPEC-HUD-004`
- 時刻と期間を表示しているコード（読むだけ）: `Sources/Capsaicin/MenuBar/MenuContent.swift`、`Sources/Capsaicin/MenuBar/StartPanel.swift`、`Sources/Capsaicin/HUD/HUDContent.swift`

## 作るもの

使ってよい新しい ID は `SPEC-UI-012` だけである。ほかの ID は振らない。

### 要件

- `REQ-SYS-003`: タイトルと内容を「アプリの画面に表示する文字列は英語と日本語で用意し、macOS の言語の設定に従ってどちらかを表示する。どちらでもない言語の設定では英語を表示する。画面の時刻は OS の地域と時刻の設定に従う。CLI の出力は英語だけである」にあたるものにする。振る舞いを持つので `kind` を `functional` にし、`specs = ["SPEC-UI-011", "SPEC-UI-012"]` にする。`reason` と `sources` の `DEC-SYS-002` を `DEC-SYS-017` に替える（`DEC-CLI-003` は残す）。
- `REQ-SYS-004`: 「あとから言語を追加できる」の趣旨は保ち、文字列を String Catalog で管理し、開発言語が英語であることを書く。`sources` の `DEC-SYS-002` を `DEC-SYS-017` に替える。

### 仕様

- `SPEC-UI-011`（`関連要件: REQ-SYS-003、REQ-SYS-004`）: 表示言語の選び方を書く。英語と日本語を用意し、macOS の優先する言語とアプリごとの言語の設定に従う。アプリの中に言語の切り替えは持たない。どちらでもない設定では英語を表示する。すべての文字列が両方の言語を持つ。アプリ名とコマンドの書式は訳さない。文言の正本が String Catalog にあること、CLI の出力が対象外であることは残す。受け入れ例は仮の訳の試験をやめ、次の2つにする。
  - アプリごとの言語の設定で英語を選んで起動すると、メニュー、入力パネル、HUD、設定画面、アラートが英語で表示される。日本語を選ぶと日本語で表示される。
  - 優先する言語が英語でも日本語でもない（例: フランス語だけ）とき、英語で表示される。
- `SPEC-UI-012 時刻と期間の表記`（新規、`関連要件: REQ-SYS-003`）: 画面に表示する時刻（解除の時刻、入力パネルの時刻と、確定したらオフになる時刻）は、OS の地域と時刻の設定に従い、12時間制・24時間制も OS の設定に従う。残り時間などの期間は、表示している言語で、時間と分の単位で示す（丸めは各画面の仕様のまま）。CLI は対象外で `SPEC-CLI-003` に従う。受け入れ例を、12時間制の英語、24時間制の日本語、24時間制に設定した英語の3つ書く（解除の時刻がメニューと HUD でその表記になることを観測する）。
- `docs/specs/ui.md`、`menu.md` の「未決のこと」から時刻の表記の論点の行を消す。ほかに時刻を `H:mm` 固定や24時間制と書いた画面の仕様があれば、`SPEC-UI-012` を参照する形に直す。受け入れ例の時刻（例: `14:00`）は24時間制の環境での例として読めるので、そのままでよい。

### その他

- 時刻の表記の論点のファイルを削除し、ほかの文書からの参照がなくなったことを確かめる（`docs/meta/tasks/` の過去のチケットにある参照は残す。文書の検査が落ちるなら報告する）。
- `docs/product/overview.md`: 「非目標」から英語の UI を外し、`DEC-SYS-002` への参照もなくす。Intel Mac と macOS 25 以前の行は残す。
- `docs/manual/verification.md`: 8節に、英語と日本語の表示と時刻の表記を確かめる節を足す（番号は 8.8）。既存の節と同じ形（目的、前提、手順、期待、戻し方）で書く。手順は、システム設定の「一般」→「言語と地域」→「アプリケーション」で Capsaicin の言語を English と日本語に切り替える方法と、時刻の24時間表示の切り替え、それぞれを元に戻す方法を含める。システム設定の操作はオーナーが行う。`SPEC-UI-011` の仮英訳試験に触れた既存の記述は、この節を指す形に直す。
- `AGENTS.md`: 「開発言語は `ja` である」を `en` にし、すべてのキーに英語と日本語の値を持たせることを書く。

## 守ること

- 製品と仕様には現在の状態だけを書く。「以前は日本語だけだった」のような経緯を書かない。
- 文言そのものを仕様に書かない（`SPEC-UI-011`）。
- 「蓋」は書かない（`docs/documentation-management.md` の「書き方」）。

## 完了条件

- 要件・仕様・製品の文書・手順書・`AGENTS.md` が `DEC-SYS-017` と一致する。
- `REQ-SYS-003` の `specs` と、`SPEC-UI-011`・`SPEC-UI-012` の `関連要件` が双方向で一致する。
- `nix develop --command just lint-docs` が通る。

## 検証

```sh
nix develop --command just lint-docs
rg -n "Q-UI|DEC-SYS-002|日本語だけ|開発言語" docs AGENTS.md
```

2つ目は、残っている箇所が `docs/meta/tasks/`、`docs/meta/decisions/`、または `DEC-SYS-017` に合った記述だけであることを確かめる。

## 報告してほしいこと

- 変えたファイルと節。
- `SPEC-UI-012` の受け入れ例の要約。
- 範囲外で `DEC-SYS-017` と食い違う記述を見つけたら、その場所。

## レビュー

PM が全差分を読み、`REQ-SYS-003`・`REQ-SYS-004`、`SPEC-UI-011`・`SPEC-UI-012`、手順書の8.8、`AGENTS.md` が `DEC-SYS-017` と一致し、経緯や文言を書いていないことを確かめた。担当の報告どおり、削除した時刻の表記の論点への参照が `DEC-SYS-017` とこのチケットに残って `lint-docs` が落ちたので、PM が ID を使わない書き方に直した。`just lint-docs` が通った。
