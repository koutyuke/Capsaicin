---
schema: decision
id: DEC-SYS-026
title: 手元の Debug ビルドで agent とヘルパーを確かめるときは Developer ID で署名し直し、Debug のプロセスは実行ファイルの絶対パスで見つける
status: superseded
supersedes: ["DEC-SYS-025"]
superseded_by: ["DEC-SYS-027"]
requirements: []
based_on: ["DEC-SYS-021", "DEC-SYS-024", "DEC-HLP-005", "DEC-LCY-008", "EVID-LCY-004", "EVID-LCY-005"]
---

# DEC-SYS-026 手元の Debug ビルドで agent とヘルパーを確かめるときは Developer ID で署名し直し、Debug のプロセスは実行ファイルの絶対パスで見つける

## 結論

`DEC-SYS-025` を置き換える。変えるのは `just sign-debug` の既定の証明書だけで、ほかは引き継ぐ。

- `just build` と CI のテストは、これまでどおり ad-hoc 署名のビルドを作る。
- 手元のビルドで agent やヘルパーを確かめるときは、ビルドした Debug アプリを `just sign-debug` で署名し直す。既定の証明書は「Developer ID Application」にする。引数でほかの証明書も選べる。内側の実行コードから順に署名し、最後にアプリを署名する。署名の識別子、entitlements、フラグを保ち、タイムスタンプは付けない。`xcodebuild` の署名の設定は変えない。
- `just sign-debug` はオーナーのキーチェーンの鍵を使う。エージェントが実行するときは、`app` グループのレシピと同じくオーナーの承認を得る。
- `justfile` の `app` グループのレシピ（`start`、`stop`、`status`）は、Debug アプリのプロセスを、PID から引いた実行ファイルの絶対パスで見つける。どのチェックアウトのビルドかも、この絶対パスで判断する。
- `just start` は、このチェックアウトの実行ファイルが launchd の子として動き出すのを待つ。動かなければ失敗を返し、署名し直しと、ログの `Launch Constraint Violation` の確かめ方を示す。

## 背景

`DEC-SYS-025` は、配布物と同じ Team ID を持つ「Apple Development」を既定にした。PR の公証したビルドが agent の項目を作った Mac で、「Apple Development」で署名し直した手元のビルドの agent は、起動の制約で止まった（`EVID-LCY-005`）。同じ項目のまま「Developer ID Application」で署名し直したビルドの agent は起動した（`EVID-LCY-004`）。Team ID が同じだけでは足りない。

## 選択肢

- 既定を「Apple Development」のままにし、項目を作り直す手順を書く（不採用）。項目は bundle ID ごとに1つで、アプリを削除しても残った（`EVID-LCY-004`）。PR のビルドで確かめるたびに作り直すことになり、作り直す確かな手順もない。
- 既定を「Developer ID Application」にする（採用）。PR のビルドと手元のビルドを入れ替えても、同じ項目のまま agent が起動する。

## 理由

- 確認に使う PR のビルドは Developer ID で署名して公証する（`DEC-SYS-023`）。手元のビルドを同じ証明書で署名すれば、両者を行き来しても agent の項目の条件が変わらない。
- 署名し直したビルドは公証せず、配布しない。手元で使うだけなので、Developer ID の鍵を手元の確認に使っても、配布物の扱いは変わらない。

## 影響

- `AGENTS.md` のレシピの表と、実機確認の手順書の証明書の名前を「Developer ID Application」に直す。
- `DEC-HLP-005` の、手元でヘルパーを試すときの「Apple Development の証明書で署名したビルド」は、PR のビルドが項目を作っていない Mac にだけ当てはまる。
- ad-hoc や「Apple Development」で署名したビルドは、Developer ID で署名したビルドが agent を登録した Mac では、agent を起動できない。アプリはそのことを、起動を確かめられないときの扱い（`DEC-LCY-009`）で示す。

## 覆す条件

- 「Developer ID Application」で署名し直しても agent が起動しない事例が見つかったとき。
- 起動の制約の条件が分かり、手元のビルドで Developer ID の鍵を使わずに済むと分かったとき。
- Apple が `BundleProgram` のジョブの実行ファイルの絶対パスを、コマンドラインにも出すように変えたとき。
