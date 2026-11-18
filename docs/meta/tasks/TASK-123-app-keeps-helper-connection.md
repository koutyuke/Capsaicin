---
schema: task
id: TASK-123
title: アプリがヘルパーへの接続を保ち、on を送り直し、バックグラウンドの項目のオフを検知する
status: todo
requirements: ["REQ-LCY-003", "REQ-HLP-006"]
depends_on: []
assignee: OpenCode openai/gpt-6.2-sol（high）
---

# TASK-123 アプリがヘルパーへの接続を保ち、on を送り直し、バックグラウンドの項目のオフを検知する

## 目的

デーモンは、`on` を受けた接続に後片付けの役目を持たせ、その接続が切れたら `off` を実行する（`SPEC-HLP-002`、実装済み）。アプリがその接続を抑止中に保ち、デーモンが落ちたら `on` を送り直し、システム設定でバックグラウンドの項目がオフになったらヘルパーが要る抑止を解除して HUD で知らせるようにする。判断は `DEC-LCY-010`。

## 範囲

変更してよいもの: `Packages/CapsaicinKit/`（ソースとテスト）、`Sources/Capsaicin/`（`.xcstrings` を含む）、`Tests/`。

変更してはいけないもの: `Sources/capsaicin-helper/`、`Sources/capsaicin-cli/`、`project.yml`、`justfile`、`scripts/`、`docs/`、`AGENTS.md`。単一インスタンス（`SPEC-LCY-009`）はこの作業に含めない。

## やること

仕様が正である。`docs/specs/helper.md` の `SPEC-HLP-002`、`SPEC-HLP-004`、`SPEC-HLP-005`（特に、接続の中断を受けたら張り直して `on` を送り直す段落と、受け入れ例）、`docs/specs/blocking.md` の `SPEC-BLK-007`、`docs/specs/hud.md` の `SPEC-HUD-001`、`SPEC-HUD-002` を読む。

1. 接続を保つ: 今は要求ごとに接続を作って閉じている。抑止中に `disablesleep` が要る間（所有が「立てた」の間）は、`on` を送った接続を保ち、`off` を送った後か不要になったら閉じる。要求の5秒の期限、期限を過ぎたら接続を取り消すこと（`SPEC-HLP-005`）は保つ。
2. 送り直す: 保っている接続で中断（`XPC_ERROR_CONNECTION_INTERRUPTED`）を受け、デーモンの状態が承認待ちでなければ、接続を張り直して `on` を送り直す。`SleepDisabled` が 1 のままでも送る。送り直せなければ合わせられていない制御として残し、合わせ直しで再び役目を戻そうとする（`SPEC-BLK-007`）。
3. 項目のオフを検知する: 接続が切れ、`SMAppService.daemon` の状態が承認待ち（`requiresApproval`）なら、ヘルパーが要る抑止を解除し（`SPEC-BLK-007`）、HUD で解除したことと理由を伝える（`SPEC-HUD-002` の行）。アプリは終了せず、設定の保存値は変えない。「ヘルパー」の状態の表示は読み直す。
4. HUD の文言を英語と日本語で足す。既存の HUD の文体に合わせる。
5. テスト: 上の規則（接続の保持と解放、送り直しの成功と失敗、承認待ちでの解除と HUD）を、`SPEC-*` をテスト名に持つ Swift Testing で確かめる。XPC そのものはポートの偽物で差し替える。

ブランチ `spike/daemon-cleanup-probe` のコミット `1b42313` の `HelperXPCClient.swift` に、接続の保持と送り直しの試作がある（実機で確かめた。`EVID-HLP-010`、`EVID-HLP-012`、`EVID-HLP-013`）。参考にしてよいが、`Spike` のログなど試作のための処理は入れない。

## 完了条件

- 上の振る舞いが実装され、仕様と食い違わない。
- `nix develop --command just check` と `nix develop --command just build` が通る。
- 報告に、接続の持ち方（どこで作り、どこで閉じるか）、中断と無効の扱い、並行性（actor、キュー）の設計と理由を書く。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- アプリを起動しない。`sudo`、`launchctl`、`pmset` の設定変更、SMAppService の登録をしない。実機の確認は PM が手順書を作り、オーナーが行う。

## レビュー

（PM が書く）
