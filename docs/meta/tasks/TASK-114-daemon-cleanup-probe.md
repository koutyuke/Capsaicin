---
schema: task
id: TASK-114
title: デーモンによるクラッシュ後の後片付けと、agent をやめた起動を試作する
status: todo
requirements: []
depends_on: []
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-114 デーモンによるクラッシュ後の後片付けと、agent をやめた起動を試作する

## 目的

クラッシュ時の再起動（SMAppService の agent）と抑止の再開をやめ、クラッシュの後の `SleepDisabled` の後片付けをヘルパーのデーモンに持たせる方針を検討している。方針を判断記録にする前に、前提の仮説を実機で確かめるための試作のアプリを作る。試作はブランチ `spike/daemon-cleanup-probe` に置き、`feature/smappservice` には取り込まない。

確かめる仮説（必ず読む）: `HYP-HLP-008`、`HYP-HLP-009`、`HYP-HLP-010`、`HYP-LCY-008`、`HYP-LCY-009`、`HYP-BLK-013`、`HYP-LCY-001`。今の構成は `DEC-LCY-008`、`DEC-LCY-009`、`DEC-HLP-005`、`docs/specs/helper.md`、`docs/specs/lifecycle.md` にある。

## 範囲

作業する場所: worktree `/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe`（ブランチ `spike/daemon-cleanup-probe`）。

変更してよいもの: `Sources/capsaicin-helper/`、`Packages/CapsaicinKit/Sources/CapsaicinPlatform/Helper/`、`Packages/CapsaicinKit/Sources/CapsaicinPlatform/Lifecycle/`、`Sources/Capsaicin/App/`、それらのテスト。

触らないもの: `docs/`、`project.yml`、`justfile`、`scripts/`、String Catalog、`feature/smappservice` の worktree。

## やること

1. デーモン（`Sources/capsaicin-helper/main.c`）
   - `on` が成功した接続を「後片付けの役目を持つ接続」として覚え、その接続で `off` が成功したら外す。
   - 役目を持つ接続がある間は、30 秒の無操作による終了をしない。ない間は今のまま 30 秒で終了する。
   - 役目を持つ接続が切れたら（`XPC_ERROR_CONNECTION_INVALID`）、`off`（`helper_set_sleep_disabled(false)`）を実行し、役目を外す。
   - `SIGTERM` を dispatch の signal source で受け、役目を持つ接続があれば `off` を実行してから終了する。
   - 受け付ける要求は `on` と `off` のままにする。要求の種類、引数、パス、環境変数を増やさない。
   - 試作の確認のため、次の場面を `os_log_create("io.github.koutyuke.capsaicin.debug.helper", "Spike")` のログに `%{public}` で残す: 役目を得た、役目を外した、切断を受けて `off` を実行した（成否）、`SIGTERM` を受けて `off` を実行した（成否）、無操作で終了した。
2. アプリのヘルパーへの接続（`HelperXPCClient` と呼び出し元）
   - `on` を送った接続を閉じずに保ち、同じ接続で `off` を送ってから閉じる。`off` 以外の場面（読み取りなど）は今のままでよい。
   - 保っている接続が中断（`XPC_ERROR_CONNECTION_INTERRUPTED`）したら、同じ接続で `on` を送り直す（`HYP-HLP-010`）。
   - 保っている接続の中断と無効化を受けたら、そのときの `SMAppService.daemon` の状態をログに残す（`HYP-HLP-009`）。
3. 起動（`Sources/Capsaicin/App/` と `Lifecycle/`）
   - agent を登録せず、`kickstart` による引き渡しもしない。直接起動したアプリがそのまま動く。ログイン時の起動（mainApp）は今のままでよい。
   - 起動時に一度だけ、`SMAppService.agent(plistName:)` の状態が `notRegistered` でなければ `unregister()` を呼び、前後の状態をログに残す（`HYP-LCY-009`）。agent の plist はバンドルに残したままにする。
   - 起動時に、同じ bundle ID の別のプロセス（`NSRunningApplication`）が動いていたら、ログを残して自分は終了する。
4. アプリ側のログは、サブシステム `io.github.koutyuke.capsaicin.debug`、カテゴリ `Spike` に `privacy: .public` で残す。
5. Sparkle のソースを読む（`HYP-LCY-008`）。プロジェクトが固定している版（`Package.resolved`）で、アップデートの後にアプリを起動し直すとき、元のアプリのプロセスの終了を待ってから新しい版を起動するかを、ファイルと行を挙げて報告する。コードは変えない。

## 守ること

- `AGENTS.md` を読んでから始める。アプリを起動しない。`sudo`、`launchctl`、`pmset` の設定変更、`sfltool`、SMAppService の登録を、自分で実行しない。
- 試作なので、テストは既存のものが壊れないことを優先し、変えた振る舞いのために落ちるテストは、意味が分かる最小限の変更で合わせるか、落ちる理由を報告する。新しい防御や設定は足さない。
- 本番のコードに `REQ-*`、`SPEC-*`、`HYP-*` を書かない。コメントは日本語で、コードを言い換えるだけのコメントを書かない。
- `git commit` と `git push` をしない。

## 完了条件

- 1〜4 を満たし、`nix develop --command just build` が通る。
- `nix develop --command just check` の結果（通らない場合は、落ちたものとその理由）を報告する。
- 報告に、変えたファイル、ログの文言（そのまま）、5 の結果を含める。

## 検証

- `nix develop --command just build`
- `nix develop --command just check`
- 実機（オーナー）: `TASK-115` の手順書で確かめる。

## レビュー

（未記入）
