---
schema: task
id: TASK-069
title: CLI の英語の出力、--help、--no-time-limit を、要件・仕様・手順書に反映する
status: done
requirements: ["REQ-CLI-001", "REQ-CLI-003", "REQ-CLI-007", "REQ-SYS-003", "REQ-SYS-004"]
depends_on: []
assignee: Codex（OpenCode、openai/gpt-6.1-sol、variant high）
---

# TASK-069 CLI の英語の出力、--help、--no-time-limit を、要件・仕様・手順書に反映する

## 目的

PM が書いた `DEC-CLI-003` を、要件・仕様・手順書の現在の状態に書く。

## 範囲

書いてよい:

- `docs/meta/requirements/cli.toml`、`docs/meta/requirements/system.toml`（`REQ-SYS-003`、`REQ-SYS-004` だけ）
- `docs/specs/cli.md`、`docs/specs/ui.md`（`SPEC-UI-011` だけ）
- `docs/specs/blocking.md`、`docs/specs/hud.md`、`docs/specs/settings.md`（CLI の書式・出力・オプションの記述が `DEC-CLI-003` と食い違う箇所だけ。なければ触らない）
- `docs/manual/verification.md`（「7. CLI の起動・書式・終了コードを確認する」の節だけ）

触らないもの: 上記以外のすべて。特に `docs/meta/decisions/`（読むだけ）、`docs/meta/tasks/`、`docs/documentation-management.md`、本番コードとテスト。`git add`、`git stash`、`git commit` をしない。

読むもの:

- `AGENTS.md`、`docs/documentation-management.md`（特に「書き方」と「記録の一生」）
- `DEC-CLI-003`（正はこれ）、`DEC-BLK-009`、`DEC-SYS-002`、`DEC-CLI-001`
- `docs/specs/cli.md` の全体、`docs/specs/blocking.md` の `SPEC-BLK-003`、`SPEC-BLK-011`、`docs/specs/menu.md` の `SPEC-MENU-004`、`docs/specs/ui.md` の `SPEC-UI-011`

## 作るもの

使ってよい新しい ID は `REQ-CLI-007` と `SPEC-CLI-008` だけである。ほかの ID は振らない。

### 要件

- `REQ-CLI-001`: `on` で、タイマー、指定時刻、時間の条件なしのどれかを指定できることにする。抑止中に指定した `on` は解除の時刻を置き換える（時間の条件なしなら解除の時刻をなくす）。`sources` に `DEC-CLI-003` を足す。
- `REQ-CLI-003`: `sources` に `DEC-CLI-003` を足す。内容は変えなくてよい。
- `REQ-CLI-007`（新規）: 利用者は `capsaicin --help` で、使い方、サブコマンド、`on` のオプション、終了コードを確かめられる。`specs = ["SPEC-CLI-008"]`、`sources = ["DEC-CLI-003"]`。
- `REQ-SYS-003`: アプリの画面に表示する文字列は日本語だけで、CLI の出力は英語だけであることにする。タイトルも合わせる。`sources` に `DEC-CLI-003` を足す。
- `REQ-SYS-004`: String Catalog で管理するのはアプリの画面に表示する文字列であり、CLI の出力は対象外であることにする。`sources` に `DEC-CLI-003` を足す。

### 仕様

- `docs/specs/cli.md` の冒頭: 出力が英語だけで、ロケールやアプリの表示言語で変わらないこと、文言の正本が CLI のコードにあること（`DEC-CLI-003`）にする。「出力の文言は日本語で、正本は String Catalog にある」をなくす。
- `SPEC-CLI-001`: 書式を `capsaicin on [--for <時間> | --until <時刻> | --no-time-limit]` にする。`--no-time-limit` は値を取らず、時間の条件なしの開始になる（停止中は設定のタイマーと指定時刻を使わずに開始、抑止中は解除の時刻をなくす）。3つのオプションのどの2つも同時に指定できないこと、同じオプションの2回の指定を拒むことにする。受け入れ例に、`--no-time-limit` で開始する例と、抑止中に `--no-time-limit` で解除の時刻をなくす例を足す。書式の誤りの例に `--for 30m --no-time-limit` と `--no-time-limit 1h` を足す。
- `SPEC-CLI-003`: 「1行」をやめ、`DEC-CLI-003` の形にする。1行目で抑止中か停止中かを示し、抑止中なら続く行で解除の条件（時間の条件とバッテリー残量の条件）を示す。時間の条件は解除の時刻（ローカルの24時間制）と残り時間、なければ自分でオフにするまで続くこと。残り時間の丸めは `SPEC-MENU-004` と同じ。合わせられていない制御と、再開用の記録を保存できていないことは、警告として標準エラー出力に出す。終了コードは今までどおり状態だけで決める。受け入れ例も合わせる。
- `SPEC-CLI-007`: 次を書く。
  - 結果と状態は標準出力、警告とエラーは標準エラー出力に出す。今の「終了コード 69 のときは結果を標準エラーに出す」に当たる記述があれば、`DEC-CLI-003` に合わせる。`off` で合わせられていない制御が残ったときは、結果を標準出力に、警告を標準エラー出力に出し、終了コード 69 にする。開始の拒否、CLI からの操作を受け付けない設定、接続の失敗は、標準エラー出力にエラーだけを出す。
  - 1行目の記号の使い分け（状態を変えた、変えなかった、`status` の抑止中・停止中）と、警告・エラーの始め方、使い方の誤りで `--help` を案内すること。
  - 抑止中に指定のない `on` を実行したときは、すでに抑止中であることと、オプションで解除の時刻を変えられることを伝える。
  - 色を付ける条件（出力先が端末、`NO_COLOR` が空でない値で設定されていない、`TERM` が `dumb` でない。標準出力と標準エラー出力で別々に判定する）。
  - 終了コードの表は今のまま。
- `SPEC-CLI-008`（新規、`関連要件: REQ-CLI-007`）: `-h` か `--help` が引数のどこかにあれば、ほかの引数によらず、説明、書式、サブコマンド、`on` のオプション、終了コードを標準出力に出し、終了コード 0 で終わる。アプリに接続せず、アプリを起動しない。`.app` の外に置いたコピーでも出す。引数がないときは使い方の誤りになる（`SPEC-CLI-007`）。受け入れ例を1つ以上書く（アプリを終了した状態で `capsaicin --help` を実行し、使い方が出て終了コード 0、アプリが起動しないこと）。
- `SPEC-UI-011`: CLI の出力はこの仕様の対象外で、`SPEC-CLI-007` と `DEC-CLI-003` に従うことを足す。
- ほかの仕様で、CLI の出力を「1行」「日本語」「String Catalog」としている記述や、CLI に時間の条件なしの指定がないとしている記述があれば直す（`rg -n "CLI|capsaicin" docs/specs` で探す）。

仕様に出力の英語の文言を逐語で書かない。何を伝えるか、記号、出力先を書く。出力の例が必要なら `DEC-CLI-003` を参照する。

### 手順書

`docs/manual/verification.md` の「7. CLI の起動・書式・終了コードを確認する」を、今回の仕様に合わせて直す。既存の書き方（目的、前提、操作、期待、中止、復元、記録、結果欄）を保つ。

- 7.1 の期待を、英語の複数行の出力と、残り時間付きのローカル時刻に合わせる。
- 7.2 の不正な書式の例に `--for 1m --no-time-limit` と `--no-time-limit 1h` を足す。期待に、標準エラーに `error:` で始まる理由と `--help` の案内が出ることを足す。
- 新しい小節（7.3）で、次を確かめる手順を足す: アプリを終了した状態での `--help` と `-h`（使い方が出て終了コード 0、アプリが起動しない）、`on --no-time-limit` での開始と、抑止中の `--no-time-limit` で解除の時刻がなくなること、`status` をパイプに流したときと `NO_COLOR=1` のときにエスケープシーケンスが出ないこと（`| cat -v` で確かめる）。
- `sudo`、`pmset` の設定変更、`launchctl` を手順に入れない。

## 守ること

- `docs/documentation-management.md` の書き方に従う。常体、現在の状態だけ、同じ規則を2か所に書かず ID で参照する。「蓋」を書かない。
- 仕様に型名やファイルのパスなどの実装の詳細を書きすぎない。
- サブエージェントを起動しない。判断にない振る舞いを決める必要があったら、推測で埋めずに報告する。

## 完了条件

- `nix develop --command just lint-docs` が通る。
- `rg -n "String Catalog" docs/specs/cli.md` が、CLI の出力が String Catalog を使わないことを述べる箇所以外で何も出ない。
- `rg -n "1行" docs/specs/cli.md` で、`status` の出力を1行とする記述が出ない。

## 検証

- `nix develop --command just lint-docs`
- 報告に、変えた節の一覧と、判断と食い違いそうで迷った点を書く。

## レビュー

- 開始の拒否、CLI からの操作を受け付けない設定のときに警告を続けて出すかで、このチケットと `TASK-070` が食い違っていた（PM のチケットの不整合）。担当はこのチケットに合わせて「エラーだけ」と書いた。`TASK-070` と `DEC-CLI-003` の意図に合わせ、`SPEC-CLI-007` を「標準出力には何も出さず、警告があればエラーに続けて出す」に PM が直した。
- `SPEC-SET-002` の「CLI からの操作を受け付ける」の (i) の欄が、書式を仕様 ID で挙げる形になっていた。今の (i) の文言は書式を挙げていないので、(i) が伝えること（ターミナルから切り替えと状態の確認ができること、オフのときはエラーで何も変えないこと）に PM が直した。
- そのほかは判断どおりで、`lint-docs` が通ることを確かめた。
