---
schema: task
id: TASK-120
title: ヘルパーのデーモンに、接続ごとの後片付けの役目と SIGTERM の処理を足す
status: in_progress
requirements: ["REQ-LCY-003", "REQ-HLP-002"]
depends_on: []
assignee: OpenCode openai/gpt-6.2-sol（high）
---

# TASK-120 ヘルパーのデーモンに、接続ごとの後片付けの役目と SIGTERM の処理を足す

## 目的

`SPEC-HLP-002` のとおり、デーモンが `on` を受けた接続に後片付けの役目を持たせ、`off` なしの切断と `SIGTERM` で `off` を実行するようにする。判断は `DEC-LCY-010`。

## 範囲

変更してよいもの: `Sources/capsaicin-helper/`、`Tests/` のうちヘルパーの実行ファイルを検査するテスト（あれば）。

変更してはいけないもの: アプリ、CLI、`Packages/`、`project.yml`、`docs/`。受け付ける要求の種類（`on` と `off`）、相手の照合、`execve` で `/usr/bin/pmset` を呼ぶ処理、起動時の後片付け（`boot.c`）の振る舞いは変えない（`AGENTS.md` の「破ってはいけないもの」3）。

## 参考

ブランチ `spike/daemon-cleanup-probe` のコミット `1b42313` の `Sources/capsaicin-helper/main.c` が、同じ振る舞いを試作したもので、実機で確かめてある（`EVID-HLP-010`、`EVID-HLP-012`、`EVID-HLP-013`）。そのまま写さない。`Spike` のログの分類や試作のための出力は製品に入れない。製品として読みやすく、最小の C にする。

## 完了条件

- `on` を受けた接続が役目を持ち、同じ接続の `off` で外れる。役目を持つ接続が `off` なしで切れたら `off` を実行する。
- `SIGTERM` を受けたら、役目を持つ接続があれば `off` を実行してから終了する。シグナルハンドラーの中で非同期シグナル安全でない処理をしない（dispatch source などを使う）。
- 役目を持つ接続がある間は、アイドルの時間で終了しない。役目がなくなれば、これまでどおりアイドルで終了する。
- 複数の接続が役目を持ちうる場合も、最後の役目が外れたときだけでなく、切れた接続ごとに `SPEC-HLP-002` どおりに扱う（単一インスタンスなので通常は1つ）。
- ログは既存の分類と書き方に合わせ、相手の PID や結果など、後で調べるのに要るものだけを残す。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- デーモンの実機の振る舞いは、実装の後に PM が手順書を作り、オーナーが確かめる。この作業ではヘルパーを登録しない、`sudo`・`launchctl` を実行しない。

## レビュー

（PM が書く）
