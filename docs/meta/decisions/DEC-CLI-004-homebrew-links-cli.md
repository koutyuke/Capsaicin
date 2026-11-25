---
schema: decision
id: DEC-CLI-004
title: CLI はアプリの中に置き、Homebrew で入れたときだけ Cask がリンクを作る
status: accepted
supersedes: ["DEC-CLI-001"]
superseded_by: []
requirements: ["REQ-CLI-005", "REQ-CLI-006"]
based_on: ["DEC-CLI-001", "EVID-SYS-010"]
---

# DEC-CLI-004 CLI はアプリの中に置き、Homebrew で入れたときだけ Cask がリンクを作る

## 結論

- 「CLIからの操作を許可」の設定は、コマンドの有無ではなく、アプリが CLI からの要求を受け付けるかどうかを切り替えるものにする（`DEC-CLI-001` と同じ）。
- CLI はアプリの中の `Contents/Helpers` に置き、アプリはシェルから使うためのリンクを作らない（`DEC-CLI-001` と同じ）。
- Homebrew の Cask（`DEC-SYS-031`）は、`binary "#{appdir}/Capsaicin.app/Contents/Helpers/capsaicin"` で、Homebrew の `bin` に `capsaicin` のリンクを置く。`brew uninstall` でリンクも消える。
- GitHub Release の DMG から入れた利用者は、今までどおり「コマンドの場所」のパスを使うか、自分でリンクやエイリアスを作る。

## 背景

`DEC-CLI-001` は、アプリがリンクを作ると管理者権限が要るので、リンクは利用者が作ることにした。覆す条件に「Homebrew の tap などで配り、配布の仕組みがリンクを作れるようになったら、リンクの扱いを見直す」と書いていた。`DEC-SYS-031` で Homebrew の tap を作ることにし、Cask の `binary` で、アプリの中の実行ファイルへのリンクを Homebrew の `bin` に置ける（`EVID-SYS-010`）。

## 選択肢

- Cask でもリンクを作らない。Homebrew で入れた利用者も、自分でリンクを作る必要がある（不採用）。
- Cask の `binary` でリンクを置く（採用）。
- アプリがリンクを作る。`DEC-CLI-001` の理由（管理者権限が要る）は変わらない（不採用）。

## 理由

- リンクは Homebrew が自分の `bin` に置くので、アプリが管理者権限を求めずに済み、Homebrew で入れた利用者はすぐ `capsaicin` を使える。
- リンクの作成と削除を Homebrew が受け持つので、アプリを消したのにリンクだけが残ることがない。
- アプリの振る舞い（`SPEC-CLI-006`）は変わらない。

## 影響

- Homebrew で入れたときは、`capsaicin` のリンクが Homebrew の `bin` にある。README の Homebrew の手順でそのことを伝える。
- 利用者が PATH の別の場所に自分でリンクを作っていると、同じ名前のコマンドが2つになる。

## 覆す条件

- 大文字小文字を区別しない APFS での衝突が問題にならない置き場所や名前の規則に変えるときは、置き場所を見直す（`DEC-CLI-001` と同じ）。
- Homebrew 以外の配布の仕組みがリンクを作れるようになったら、その仕組みでのリンクの扱いを決める。
