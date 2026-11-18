---
schema: task
id: TASK-118
title: BTM のデーモンの項目が親を失う条件を確かめる手順書を作る
status: done
requirements: []
depends_on: ["TASK-117"]
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-118 BTM のデーモンの項目が親を失う条件を確かめる手順書を作る

## 目的

`HYP-HLP-011` をオーナーが実機で確かめるための手順書を作る。`TASK-117` の試作で、実験ごとに未使用のヘルパーのラベルを使う。

必ず読む: `EVID-HLP-007`、`HYP-HLP-011`、`TASK-117`、`docs/manual/verification/README.md`、`prepare.md`、`cleanup.md`、`app-crash-daemon-cleanup.md`（書き方の例）。

## 範囲

変更してよいもの: `docs/manual/verification/helper-orphan-reproduction.md`（新規）、`docs/manual/verification/README.md` の一覧。

触らないもの: ほかの `docs/`、コード。

## やること

1. `README.md` の書き方の規則に従う。1ファイルで実施できるようにし、参照してよいのは `prepare.md` と `cleanup.md` だけにする。コマンドはその場に書く。画面の名前は String Catalog の `ja` の値をそのまま「」で書く。
2. 試作のビルド: 試作の worktree で、実験ごとに `HELPER_LABEL_SUFFIX=<実験の名前> nix develop --command just build` と `nix develop --command just sign-debug` を行う。成果物の plist の `Label` が `io.github.koutyuke.capsaicin.debug.helper-<実験の名前>` であることを確かめてから使う。実験の名前は、まだ使っていないもの（例: `r1`、`r2`）にし、使った名前を記録する。
3. コピーの作り方: 成果物を `ditto` で、退避先の下の2つのフォルダー（コピー A と B）に複製する。各実験の前に、同じ bundle ID のアプリがほかに動いていないことを確かめる。
4. 実験1（消す）: A を起動してヘルパーを設置し、システム設定で許可し、ヘルパーが動く（抑止を始めて `SleepDisabled 1`、止めて `0`）ことを確かめる。`sfltool dumpbtm` で、デーモンの項目の親を記録する。A を終了し、A のフォルダーを `/bin/rm -rf` で消す（ゴミ箱を空にする操作は、ほかのファイルも消すので使わない）。もう一度 `dumpbtm` で親を記録する。B を起動し、ヘルパーの状態と、抑止を始めたときに動くか、launchd のログの `Invalid path` の有無、`dumpbtm` の親を記録する。B からヘルパーを「削除…」で外した後の `dumpbtm` も記録する（`HYP-HLP-011` の 4）。
5. 実験2（動かす）: 別の実験の名前でビルドし直し、A と B を作り直す。A から設置して動くことを確かめた後、A を終了して `mv` で別のフォルダーへ動かす。動かす前後と、動かした A を起動したとき、B を起動したときの `dumpbtm` の親、ヘルパーが動くか、launchd のログを記録する。
6. 各実験で、`sfltool dumpbtm` からは Capsaicin の項目（アプリ、デーモン、agent）だけを抜き出して見比べられるようにし、全体は退避先に保存する。期待は仮説の主張どおりに書き、違う結果を期待に寄せて解釈しないよう書き添える。
7. 片付け: 各実験の最後に、ヘルパーを「削除…」で外し、試作を終了し、コピーを消す。親を失って消せない BTM の項目が残りうることを、実施の前に承認を得る事項として「始める前に」に書く。`SleepDisabled` が 1 のまま残ったときの戻し方（`/usr/bin/sudo /usr/bin/pmset -a disablesleep 0`）を書く。LED は使わない（「スリープ防止中にCaps LockのLEDを点灯」をオフにする）。

## 守ること

- `AGENTS.md` を読んでから始める。手順をエージェント自身が実行しない。
- `git commit` と `git push` をしない。

## 完了条件

- 1〜7 を満たす手順書があり、`nix develop --command just lint-docs` と `nix develop --command just fmt-check` が通る。

## 検証

- `nix develop --command just lint-docs`
- `nix develop --command just fmt-check`

## レビュー

PM がレビューした。`helper-orphan-reproduction.md` は、実験1（A を消す）と実験2（A を動かす）で、A の終了、削除・移動、各コピーの起動、登録し直し、登録解除の段階ごとに BTM の UUID と親、`SleepDisabled`、launchd の `Invalid path` を記録し、仮説の 1〜4 を別々に判定できる。コピーの削除は表示したパスを確かめてから `/bin/rm -rf` で行い、ゴミ箱は空にしない。最初の登録の時点で親が既に `Unknown Developer` なら判定不能として止める。親を失った項目が残りうることを、実施前の承認事項にしている。`TASK-117` の成果物の plist の名前と `Label` が、手順書の `$LABEL` と一致することを確かめた。
