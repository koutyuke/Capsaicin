---
schema: task
id: TASK-059
title: 「明るさを0」を要件と仕様に反映し、解決した論点への参照を外す
status: done
requirements: ["REQ-BLK-014"]
depends_on: ["TASK-052"]
assignee: Codex（OpenCode、openai/gpt-6.1-sol、variant high）
---

# TASK-059 「明るさを0」を要件と仕様に反映し、解決した論点への参照を外す

## 目的

`DEC-BLK-007` で、「ディスプレイを閉じたとき」に「明るさを0」を加えると決めた。これを要件と仕様の現在の状態に書く。「明るさを0」を加えるかの論点は `DEC-BLK-007` で解決したので、ほかの文書からの参照を外す。論点のファイルは PM が削除する。

## 範囲

書いてよい:

- `docs/meta/requirements/blocking.toml`（`REQ-BLK-014` を加える）
- `docs/meta/requirements/settings.toml`、`docs/meta/requirements/lifecycle.toml`（`sources` などに `DEC-BLK-007` を足す必要があるときだけ）
- `docs/specs/blocking.md`、`docs/specs/settings.md`、`docs/specs/lifecycle.md`、`docs/specs/helper.md`（解除や終了の手順に輝度を戻す順序を書く必要があるときだけ）
- 論点への参照の置き換えだけ: `DEC-BLK-006`、`DEC-SET-004`、`DEC-SET-005`、`DEC-UI-009`、`DEC-UI-011`、`TASK-040`、`TASK-041`、`TASK-045`、`TASK-051`、`TASK-052`、`HYP-BLK-010`〜`HYP-BLK-012`、`docs/manual/lid-close-dimming-verification.md`

触らないもの: 上記以外のすべて。特に `DEC-BLK-007`（PM が書いた。読むだけ）、論点のファイル（PM が削除する）、根拠（`EVID-*`）、本番コードとテスト、`docs/manual/verification.md`。`git add`、`git stash`、`git commit` をしない。

読むもの:

- `AGENTS.md`、`docs/documentation-management.md`（特に「書き方」と「記録の一生」）
- `DEC-BLK-007`、`DEC-SET-005`、`DEC-BLK-006`、`DEC-BLK-002`、`DEC-UI-011`
- `docs/specs/blocking.md`（`SPEC-BLK-002`、`SPEC-BLK-007`、`SPEC-BLK-009`、`SPEC-BLK-012`）、`docs/specs/settings.md`（`SPEC-SET-002`、`SPEC-SET-003`、`SPEC-SET-005`、`SPEC-SET-006`）、`docs/specs/lifecycle.md`（`SPEC-LCY-002`、`SPEC-LCY-003`、`SPEC-LCY-006`、`SPEC-LCY-007`）、`docs/specs/helper.md`（`SPEC-HLP-005`）
- `EVID-BLK-010`〜`EVID-BLK-013`（実機で分かったこと）

## 作るもの

### 1. `REQ-BLK-014`

`kind = "functional"`、`priority = "should"`、`status = "accepted"`、`specs = ["SPEC-BLK-013"]`、`depends_on = ["REQ-BLK-004"]`、`sources = ["DEC-BLK-007"]`。内容は次のとおり。言い回しは整えてよい。

- 文: 抑止中に「ディスプレイを閉じたとき」を「明るさを0」にしていれば、蓋を閉じると、ディスプレイスリープさせずに内蔵ディスプレイの輝度を 0 にし、蓋を開けたときや抑止を解除したときに元の輝度に戻す。
- 理由: 閉じた蓋の中の光漏れを抑えながら、画面をロックさせずに画面収録や Computer Use を続けるため。

### 2. `SPEC-BLK-013 蓋を閉じたら輝度を 0 にする`（`docs/specs/blocking.md`、`SPEC-BLK-012` の後）

関連要件は `REQ-BLK-014`。方式と理由は `DEC-BLK-007` を参照し、繰り返さない。次を規則として書く。

- **暗くする条件**: 抑止中、蓋のある Mac で、`SPEC-BLK-012` で求めた閉じたときのディスプレイの設定が `zeroBrightness` のとき、蓋が閉じた通知を受けたら暗くする。閉じた通知でだけ暗くし、抑止を始めた時点ですでに閉じていた場合は暗くしない（「ディスプレイをオフ」と同じ）。
- **対象**: オンラインの内蔵ディスプレイ。なければ何もしない（外部ディスプレイをつないで閉じたときなど）。外部ディスプレイは変えない。
- **暗くする手順**: 輝度を読み、その値を記録に保存してから 0 を書く。読めない、保存できない、書けないときは明るいままにし、ログに残す。すでに記録があるときは、記録を書き換えない。
- **戻す場面**: 蓋が開いた通知、抑止の解除、アプリの終了（`SPEC-LCY-002` のすべての種類）、起動時の処理（`SPEC-LCY-006`）。どれも記録があるときだけ行い、その時点の設定の値によらない。解除と終了では、`disablesleep` を下ろす前に戻す。
- **戻す手順**: いまの輝度が 0 なら、記録した値を書き、記録を消す。0 でなければ、閉じている間に利用者か macOS が変えたものとして書かず、記録だけを消す。輝度を読めないときと書けないときは、ログに残して記録を残す（次の場面でもう一度戻す）。
- **使えない Mac**: DisplayServices の関数が見つからないか、内蔵ディスプレイの輝度を変えられないと分かったときの表示は `SPEC-SET-005` に書く。オンラインの内蔵ディスプレイがなく判定できないときは、使えないとはみなさない。
- 受け入れ例を、少なくとも次の4つ書く: 閉じて開ける、閉じたまま解除する、閉じている間に明るさのキーで明るくしてから開ける、暗くしたままアプリが落ちて再起動する。

### 3. ほかの仕様

- `SPEC-BLK-012` の表: 閉じたときのディスプレイの保存値を `keepOn`、`turnOff`、`zeroBrightness` にする。
- 解除と終了の手順を書いている箇所に、`disablesleep` を下ろす前に輝度を戻すこと（`SPEC-BLK-013`）を参照で足す。同じ規則を2か所に書かない。
- `SPEC-SET-002` の「ディスプレイを閉じたとき」の行: 選択肢を「スリープ（標準）」「ディスプレイをオフ」「明るさを0」「オンのまま」の順にし、振る舞いの列に `SPEC-BLK-013` を足す。(i) で伝えることに、「明るさを0」では閉じている間も画面は暗いだけでロックされていないこと、「ディスプレイを自動でオフにしない」がオフなら時間が来るとディスプレイがオフになり、ロックされうることを足す。
- `SPEC-SET-005`: 対応表に「明るさを0 | オン | `zeroBrightness`」を加える（ヘルパーが要るのは「オンのまま」と同じ）。保存値が `zeroBrightness` で、DisplayServices で内蔵ディスプレイの輝度を変えられないと分かったときは、ヘルパーがないときと同じ形（アイコンを `exclamationmark.triangle.fill` にし、(i) の先頭で伝える）で、輝度を変えられないので閉じても画面が点いたままになることを伝える。ヘルパーの注意と両方あるときは、(i) で両方を伝える。受け入れ例を1つ足す。
- `SPEC-LCY-002`、`SPEC-LCY-006`: 輝度を戻すことを `SPEC-BLK-013` への参照で足す。記録の置き場所は、既存の再開用の記録（`SPEC-LCY-007`）と同じ考え方で決め、仕様にはパスまで書かなくてよい。
- 「未決のこと」: `docs/specs/settings.md` から論点を外す。`docs/specs/blocking.md` に、輝度 0 のまま Mac が再起動したときにログイン画面が暗いまま残るかが未確認であることと、macOS 26 で同じ結果になるか（`HYP-SYS-001`）を足す。

### 4. 論点への参照

範囲に挙げたファイルの論点への参照を、文脈に合わせて `DEC-BLK-007` への参照に置き換える。採用済みの判断と完了した作業は、参照の言い換えだけにし、結論や記録の内容を変えない（例: 「論点を決めてから加える」→「のちに `DEC-BLK-007` で加えた」）。`HYP-BLK-010`〜`HYP-BLK-012` と手順書は、論点の目的や中身を指している箇所を `DEC-BLK-007` に置き換える。

## 守ること

- `docs/documentation-management.md` の書き方に従う。常体で書き、仕様には現在の状態だけを書く。同じ規則を2か所に書かず、ID で参照する。
- 新しく振る ID は `REQ-BLK-014` と `SPEC-BLK-013` だけにする。
- 仕様に型名やファイルのパスなどの実装の詳細を書きすぎない。
- サブエージェントを起動しない。迷ったら推測で埋めずに報告する。

## 完了条件

- `nix develop --command just lint-docs` が通る。
- 論点の ID を `grep -rlw` で探して、論点自身のファイル以外に何も出ない。
- `REQ-BLK-014` と `SPEC-BLK-013` が互いを指している。

## 検証

- `nix develop --command just lint-docs`
- 論点の ID の `grep -rlw`
- PM が差分を読み、`DEC-BLK-007` と食い違いがないかを確かめる。

## レビュー

PM が差分を読んだ。要件と仕様は `DEC-BLK-007` と食い違っていない。`disablesleep` を下ろす前に輝度を戻す順序は `SPEC-BLK-013` だけに書き、`SPEC-BLK-007`、`SPEC-LCY-002`、`SPEC-HLP-005` は参照にとどめていて、同じ規則を2か所に書いていない。

PM が直したこと:

- `SPEC-BLK-013` の暗くする条件と `SPEC-SET-005` の注意の条件が、`zeroBrightness` だけで決まるように読めた。「スリープ」を選んでも `lidCloseDisplay` は変わらないので、手動スリープの保存値がオンであること（「明るさを0」が選ばれていること）を条件に入れた。
- `DEC-BLK-007` と仕様が macOS 26 での確認に `HYP-SYS-001` を挙げているが、`HYP-SYS-001` の主張は LED と `disablesleep` だけだった。担当が報告したこの点を受けて、`HYP-SYS-001` の対象に `HYP-BLK-010`〜`HYP-BLK-012` と `DEC-BLK-007` を加えた。
- このチケット自身が論点の ID を書いていたので、論点のファイルを削除できるように言い換えた。

担当の判断で受け入れたこと:

- 設定の変更やヘルパーの削除で `disablesleep` を下ろすときは、輝度を戻さない。`DEC-BLK-007` が挙げた場面ではなく、閉じたまま暗い場合も蓋を開けた通知で戻る。

論点のファイルは PM が削除した。`nix develop --command just lint-docs` は PM の修正の後も通った。
