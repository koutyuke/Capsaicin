---
schema: task
id: TASK-100
title: 開発用スクリプトの出力を英語にし、形を揃える
status: in_review
requirements: []
depends_on: []
assignee: Codex（OpenCode 経由の openai/gpt-6.1-sol）
---

# TASK-100 開発用スクリプトの出力を英語にし、形を揃える

## 目的

`just` から呼ぶ Python のスクリプトが出すメッセージは、日本語で書かれていて形もばらばらである。オーナーは、開発ツールの出力を英語にし、読みやすい形に揃えたい。justfile の出力は、実機確認のレシピを足す別の変更で英語にする。

## 範囲

書いてよいファイルは次のとおり。

- `scripts/check_docs.py`、`scripts/check_format.py`、`scripts/prepare_release.py`
- `scripts/tests/test_check_docs.py`、`scripts/tests/test_check_format.py`、`scripts/tests/test_prepare_release.py`
- `AGENTS.md`（規約の1文を足す）
- このチケット（「実装の報告」節だけ）

これ以外は変更しない。検査の判定（何をエラーにするか）、終了コード、`prepare_release.py` が書く JSON の中身は変えない。

## 作るもの

### 共通

- 利用者に見える文字列（`print`、`ReleaseError`・`ValueError` などのメッセージ、argparse の説明、使い方）を英語にする。docstring とコメントはプロジェクトの規約どおり日本語のままにする。
- 英語は短く平易にする。メッセージは小文字で始めず、文として完結させるか、`label: value` の形にする。末尾のピリオドの有無はスクリプトの中で揃える。
- エラーは標準エラー、成功の報告は標準出力に出す。今と違うところがあれば揃える。

### check_docs.py

- 成功: `Docs check passed.`
- 失敗: 1行目に `Docs check failed: N error(s).`（件数に合わせて `error`／`errors`）、続けてエラーを1行ずつ、2つの空白で字下げした `path: message` の形で出す。
- 各エラーの文言を英語にする。何が不正かと、問題の値が分かるようにする（今の文言に含まれる情報を落とさない）。

### check_format.py

- stale のキーがあるときの見出しを英語にし、続くキーの一覧を2つの空白で字下げする。見出しは、何が問題で、どう直すか（コードから動的に引くキーなら `extractionState` を `manual` にし、使っていないキーなら消す）が分かる1文にする。
- treefmt 自体の出力には手を入れない。

### prepare_release.py

- 止まるときのメッセージを、1行目に `error: <何が起きたか>`、2行目に `hint: <どう直すか>` の形に揃える。今の文言はほぼ「何が起きたか\nどう直すか」の2行なので、それを英語にして当てはめる。直し方がないものは `error:` の1行だけにする。
- 成功時の表示は `Version: <版>` と `Materials: <パス>` にする。
- 使い方は `usage: prepare_release.py [patch]` と、引数の説明の1行にする。

### AGENTS.md

「開発環境」の節の、スクリプトや justfile について述べている近くに、「just のレシピと `scripts/` のスクリプトが出すメッセージは英語で書く。コメントと docstring は日本語で書く」という趣旨の1文を足す。

## 守ること

- テストは、新しい文言に合わせて期待値を直す。検査を弱めない（文言の一致を部分一致に緩めるなどで、確かめている内容を減らさない）。メッセージを確かめていなかった箇所に新しくテストを足す必要はない。ただし、`check_docs.py` の件数付きの見出しと、`prepare_release.py` の `error:`／`hint:` の形は、それぞれ1つずつテストで確かめる。
- 新しいヘルパー関数や仕組みを作り込まない。文言の置き換えと、出力の形を揃えるのに要る最小限の変更にする。

## 完了条件

- 3つのスクリプトの利用者に見える文字列に日本語がない（docstring とコメントを除く）。
- `nix develop --command just test-scripts` と `nix develop --command just check` が通る。

## 検証

- `nix develop --command just test-scripts`
- `nix develop --command just lint-docs` で成功時の表示を見る。
- `nix develop --command just check`
- `prepare_release.py` は、テストの中だけで確かめる。実際に実行して、ブランチやコミットを作らない。

## 実装の報告

3つのスクリプトのメッセージと使い方を英語にした。`check_docs.py` は成功時に `Docs check passed.`、失敗時に件数付きの見出しと2空白で字下げした `path: message` を出す。構文解析エラーの改行は ` | ` に置き換え、1件を1行に収める。`check_format.py` の stale キーは、修正方法の見出しと2空白で字下げした一覧を標準エラーに出す。treefmt の出力には手を入れていない。

`prepare_release.py` は停止理由を `error:`、直し方を `hint:` に分け、成功時は `Version:` と `Materials:` を標準出力に出す。判断に迷ったのは、外部コマンドの失敗詳細を `hint:` にするかどうかである。詳細は直し方ではないため、情報を残して `error:` の1行にまとめた。検査の判定、終了コード、材料 JSON の構造と値は変えていない。

`AGENTS.md` に出力言語の規約を1文追加した。テストは既存の検査を保って期待文言を更新し、件数の単複、字下げ、出力先、`error:`／`hint:` と成功時の2行を確かめる。

## レビュー

PM が差分を読み、次を直した。

- `関連要件:` は仕様の文書に書く構文の記号なので、メッセージでも訳さずに `'関連要件:'` と書くようにした。英語の言い換えでは、何を書けばよいかが分からない。
- 双方向不一致の片方の文言が「its」で何を指すか曖昧だったので、仕様の ID を明示した。
- Ruff の整形を当てた。

外部コマンドの失敗を `error:` の1行にまとめた判断は妥当とした。検査の判定と終了コードは変わっておらず、テストの期待値は文言の置き換えと、件数・字下げ・出力先の確認の追加だけである。
