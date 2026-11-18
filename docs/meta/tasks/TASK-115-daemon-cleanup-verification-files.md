---
schema: task
id: TASK-115
title: デーモンによる後片付けの試作を確かめる手順書を作る
status: done
requirements: []
depends_on: ["TASK-114"]
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-115 デーモンによる後片付けの試作を確かめる手順書を作る

## 目的

`TASK-114` の試作のアプリで、`HYP-HLP-008`、`HYP-HLP-009`、`HYP-HLP-010`、`HYP-LCY-009`、`HYP-BLK-013`、`HYP-LCY-001` をオーナーが実機で確かめるための手順書を作る。

## 範囲

変更してよいもの: `docs/manual/verification/` の新しいファイル、`docs/manual/verification/background-off-while-blocking.md`（agent がある前提で書かれている。新しい前提で書き直す）、`docs/manual/verification/README.md` の一覧、`docs/manual/verification/prepare.md`（`.debug` の agent の項目の片付けを書き足す）。

触らないもの: ほかの `docs/`、コード。

## やること

1. `docs/manual/verification/README.md` の書き方の規則に従う。1つの確認を1ファイルにし、そのファイルだけで実施できるようにする。参照してよいのは `prepare.md` と `cleanup.md` だけである。コマンドは毎回その場に書く。
2. 画面の名前は String Catalog の `ja` の値をそのまま「」で書く（`AGENTS.md` の「画面とコマンドの名前」）。ログの絞り込みは `TASK-114` の報告にある文言とサブシステム、カテゴリを使う。
3. 作るもの:
   - アプリのクラッシュの確認: 抑止中に試作のアプリを `kill -9` と `kill -SEGV` で終了させ、`SleepDisabled`、デーモンのログ、LED（`HYP-LCY-001`）を見る。MacBook では「明るさを0」でディスプレイを閉じて暗くした状態でも行い、輝度のキーで戻せるか（`HYP-BLK-013`）を見る。
   - `background-off-while-blocking.md` の書き直し: 抑止中にバックグラウンドの項目をオフにし、デーモンの `SIGTERM` での `off`、アプリが終了しないこと、アプリのログの `SMAppService.daemon` の状態を見る（`HYP-HLP-009`）。
   - デーモンの停止の確認: 抑止中にデーモンのプロセスだけを `sudo kill -9` で止め、アプリの張り直しと `on` の送り直し、その後のアプリの `kill -9` での `off` を見る（`HYP-HLP-010`）。
   - agent の項目の片付け: 試作のアプリの起動時の unregister の前後を見る（`HYP-LCY-009`）。あわせて `prepare.md` に、`.debug` の SMAppService の agent の項目が残っているときの片付けの手順を書き足す。
4. 各ファイルに、目的、前提、手順、期待する結果（仮説の主張）、途中で止める条件、元に戻す方法を書く。期待する結果は仮説の主張どおりに書き、結果が違っても推測に寄せて解釈しないよう書き添える。`SleepDisabled` が 1 のまま残ったときの戻し方（`sudo pmset -a disablesleep 0`）は、各ファイルに書く。
5. 試作のアプリのビルドと署名は、試作の worktree（`/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe`）で `just build` と `just sign-debug` を使う手順にする。

## 守ること

- `AGENTS.md` を読んでから始める。手順をエージェント自身が実行しない。
- `git commit` と `git push` をしない。

## 完了条件

- 3 のファイルがあり、`nix develop --command just lint-docs` と `nix develop --command just fmt-check` が通る。

## 検証

- `nix develop --command just lint-docs`
- `nix develop --command just fmt-check`

## レビュー

PM がレビューした。5本（`app-crash-daemon-cleanup.md`、`brightness-crash-recovery.md`、`background-off-while-blocking.md`、`daemon-reconnect-cleanup.md`、`agent-unregister-cleanup.md`）と `prepare.md`、`README.md` を読んだ。画面の名前は String Catalog の値どおりで、ログの文言は `TASK-114` の試作と一致し、期待は仮説の主張どおりに書かれている。対象のプロセスを PID と実行ファイルのパスで確かめてから止め、`SleepDisabled` の戻し方を各ファイルに書いている。

`prepare.md` の既存の条件（アプリと別のプロセスで LED を戻す手段がなければ、どの検証もしない）のままでは、5本とも始められなかった（`EVID-HLP-006` でも同じ理由で見送った）。オーナーが 2026-11-18 に、アプリの起動し直し、`hidutil property --matching keyboard --set '{"HIDCapsLockLED":"Auto"}'`、Mac の再起動の順で戻すことを承認した。PM がこの順を `prepare.md` の操作4と、LED を点ける3本の「LED が点いたまま残ったとき」に書いた。`hidutil` で点灯を戻せるかは未確認である。
