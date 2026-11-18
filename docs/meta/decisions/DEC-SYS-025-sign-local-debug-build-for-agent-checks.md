---
schema: decision
id: DEC-SYS-025
title: 手元の Debug ビルドで agent とヘルパーを確かめるときは同じ Team ID で署名し直し、Debug のプロセスは実行ファイルの絶対パスで見つける
status: accepted
supersedes: []
superseded_by: []
requirements: []
based_on: ["DEC-SYS-021", "DEC-SYS-024", "DEC-HLP-005", "DEC-LCY-008", "EVID-LCY-004"]
---

# DEC-SYS-025 手元の Debug ビルドで agent とヘルパーを確かめるときは同じ Team ID で署名し直し、Debug のプロセスは実行ファイルの絶対パスで見つける

## 結論

- `just build` と CI のテストは、これまでどおり ad-hoc 署名のビルドを作る。
- 手元のビルドで agent やヘルパーを確かめるときは、ビルドした Debug アプリを `just sign-debug` で署名し直す。既定の証明書は「Apple Development」で、配布物と同じ Team ID を持つ。引数で「Developer ID Application」なども選べる。内側の実行コードから順に署名し、最後にアプリを署名する。署名の識別子、entitlements、フラグを保ち、タイムスタンプは付けない。`xcodebuild` の署名の設定は変えない。
- `just sign-debug` はオーナーのキーチェーンの鍵を使う。エージェントが実行するときは、`app` グループのレシピと同じくオーナーの承認を得る。
- `justfile` の `app` グループのレシピ（`start`、`stop`、`status`）は、Debug アプリのプロセスを、PID から引いた実行ファイルの絶対パスで見つける。コマンドラインでは照らさない。どのチェックアウトのビルドかも、この絶対パスで判断する。
- `just start` は、このチェックアウトの実行ファイルが launchd の子として動き出すのを待つ。動かなければ失敗を返し、署名し直しと、ログの `Launch Constraint Violation` の確かめ方を示す。

## 背景

#15 で、ログイン時の起動とクラッシュ時の再起動は、アプリに入れた SMAppService の agent になった（`DEC-LCY-008`）。agent の定義は `BundleProgram` で実行ファイルを相対パスで指す。

オーナーが手元で `just start` を試すと、ad-hoc 署名のビルドの agent は、launchd が起動の制約の違反で止めた（`EVID-LCY-004`）。BTM の agent の項目は bundle ID ごとに1つで、/Applications に置いた PR の公証したビルド（Team ID 付き）が作った項目を、手元のビルドも使い直していた。項目は、アプリを削除してゴミ箱を空にしても残った。同じ bundle ID の Debug ビルドが、ほかの worktree の `.build` にあるためと見ている。

同じ Team ID の証明書で署名し直すと、agent は起動した。一方で、agent から起動したアプリのコマンドラインは相対パスになり、`just` のレシピは動いているアプリを見つけられなかった。

## 選択肢

手元のビルドの署名:

- ad-hoc 署名のままにし、手元では agent を確かめない。PR のビルドだけで確かめる（不採用）。worktree を切り替える確認（`SPEC-LCY-005`）と、日々の開発で `just start` が使えない。
- `xcodebuild` の署名の設定で、ビルドのときに署名する（不採用）。KeyboardShortcuts のリソースバンドルの自動署名とぶつかって失敗した（`EVID-LCY-004`）。証明書を持たない人の `just build` も壊れる。
- ビルドの後に署名し直すレシピを置く（採用）。`just build` は変わらず、証明書を持つ人だけが使う。

プロセスの見つけ方:

- コマンドラインを `pgrep -f` で照らす（これまで）。agent から起動したものは相対パスになり、見つからない。
- `launchctl print` の `program` で照らす（不採用）。`BundleProgram` のジョブでは絶対パスが読めない見込みで、出力の形にも依存する。
- PID から実行ファイルの絶対パスを引く（採用）。どの起動の仕方でも同じ形になる。

## 理由

- 起動の制約が求めるのは、項目を作ったビルドと同じ Team ID の署名と見られる。手元で「Apple Development」を使うのは、`DEC-HLP-005` が手元でヘルパーを試すときに挙げた証明書と同じだからである。配布用の Developer ID は配布物にとどめる。
- 署名し直す方式なら、ビルドの設定と CI に手を入れずに済む。
- 実行ファイルの絶対パスは、Finder、`just start`、agent のどこから起動しても同じなので、チェックアウトの判断が起動の仕方によらない。

## 影響

- `DEC-SYS-021` の「Debug ビルド、`just build` … は ad-hoc 署名のままにする」は、`just build` の出力についてはそのまま保つ。手元の確認で署名し直すことは、この判断で認める。
- `DEC-HLP-005` が手元でヘルパーを試すときに挙げた「Apple Development の証明書で署名したビルド」は、`just sign-debug` で作る。
- `AGENTS.md` のレシピの表に `sign-debug` を足し、`start`、`stop`、`status` の説明を直す。
- 実機確認の手順書（`docs/manual/verification/`）の準備と、worktree を切り替える確認に、署名し直しと起動の制約の切り分けを書く。
- ad-hoc 署名のビルドは、同じ bundle ID の Team ID 付きのビルドが agent を登録した Mac では、agent を起動できない。項目がなければ ad-hoc でも起動するかは確かめていない。

## 覆す条件

- 「Apple Development」で署名し直しても agent が起動しないと分かったとき。既定の証明書を見直す。
- ad-hoc 署名のビルドでも、項目を作り直せば agent が起動すると分かり、署名し直す手間に見合わなくなったとき。
- Apple が `BundleProgram` のジョブの実行ファイルの絶対パスを、コマンドラインにも出すように変えたとき。
