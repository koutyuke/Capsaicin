---
schema: task
id: TASK-121
title: agent と抑止の再開をなくし、保存する記録を輝度だけにする
status: in_progress
requirements: ["REQ-LCY-001", "REQ-LCY-002", "REQ-LCY-003", "REQ-HLP-006", "REQ-BLK-014"]
depends_on: []
assignee: OpenCode openai/gpt-6.2-sol（high）
---

# TASK-121 agent と抑止の再開をなくし、保存する記録を輝度だけにする

## 目的

`DEC-LCY-010` に合わせて、クラッシュ時に起動し直す agent、抑止の再開、保存する所有をなくす。実装を `docs/specs/` の現在の仕様（コミット `99689a5`）に合わせる。

## 範囲

変更してよいもの: `Packages/CapsaicinKit/`（ソースとテスト）、`Sources/Capsaicin/`（`.xcstrings` を含む）、`Sources/capsaicin-cli/`、`Tests/`、`project.yml`。

変更してはいけないもの: `Sources/capsaicin-helper/`（後片付けの役目は `57ab25a` で実装済み）、`docs/`、`AGENTS.md`、`justfile`、`scripts/`。必要だと分かったら変更せずに報告する。

この作業に含めないもの（後の作業で行う）: デーモンへの接続を保つこと、`on` の送り直し、バックグラウンドの項目のオフの検知と HUD（`SPEC-HLP-004`、`SPEC-HLP-005` の送り直しの段落）、単一インスタンス（`SPEC-LCY-009`）、justfile と `scripts/debug-app.sh` の整理。

## やること

仕様が正である。主に次の節を読む: `docs/specs/lifecycle.md`（`SPEC-LCY-001`、`SPEC-LCY-002`、`SPEC-LCY-003`、`SPEC-LCY-006`、`SPEC-LCY-008`）、`docs/specs/helper.md`（`SPEC-HLP-005`、`SPEC-HLP-007`）、`docs/specs/blocking.md`（`SPEC-BLK-007`、`SPEC-BLK-010`、`SPEC-BLK-013`）、`docs/specs/settings.md`、`docs/specs/menu.md`（`SPEC-MENU-004`）、`docs/specs/cli.md`（`SPEC-CLI-003`、`SPEC-CLI-007`）。

1. agent をなくす: バンドルの `Contents/Library/LaunchAgents/` の plist の生成（`project.yml`）、`SMAppService.agent` の登録と登録し直し、`launchctl kickstart` による引き渡しと起動の確認（`LaunchAgent+Confirmation.swift` を含む）を削る。「ログイン時に起動」の `SMAppService.mainApp` は残す。直接起動したアプリがそのまま動き続ける。開発機に残った agent の登録を外す処理は入れない（手作業で外す）。
2. 再開をなくす: 「スリープ防止の再開」の設定と画面の行、起動の理由の判定、連続クラッシュの上限、`kern.boottime` の読み取り（`BootTimeProvider`）、`LaunchRules` のうち再開のためのもの、記録の抑止のセッション・実行中の印・終了の理由・クラッシュ後の起動の時刻・最終更新の時刻のうち不要なものを削る。アプリはどう起動しても停止中で始まる。
3. 所有をメモリーだけに持つ（`SPEC-HLP-005`）: 保存をやめ、起動時は「立てていない」から始める。所有を保存できないことによる `on` の拒否をなくす。
4. 保存する記録を輝度だけにする（`SPEC-BLK-013`）: 記録を保存できたときだけ暗くする。保存できなければ暗くせず、警告を出す（`SPEC-MENU-004`、`SPEC-CLI-003`、`SPEC-CLI-007`）。記録の保存の失敗では開始を拒否せず、CLI の終了コードを 69 にしない。戻した後に記録を消せなければ、削除だけを 1 分ごとに試み直す。起動時は、いまの輝度が 0 のときだけ記録した値を書き、それ以外は記録を消すだけにする。前の版が保存した記録のファイル（`resume-record.json`）からも輝度の値を読めるようにし（`SPEC-LCY-008`）、ほかの値は捨てる。保存の形式とファイル名をどうするかは、互換を保つ最も単純な形を選び、報告に理由を書く。
5. 終了の扱い（`SPEC-LCY-002`）: どの終了でも停止中のあるべき状態に合わせ、エラーのダイアログは利用者の終了だけで出す。`TerminationReasonDetector` は、利用者の終了かどうかを見分ける分だけ残す。
6. 合わせられていない制御の一覧はメモリーだけに持つ（`SPEC-BLK-007`）。
7. 画面の文言: 設定の「一般」の、クラッシュ時に再起動されないことの案内と、「スリープ防止の再開」を消す。ヘルパーの説明（`status.help` など）から、クラッシュ時の自動再起動への言及を消し、`SPEC-HLP-004` の (i) の内容に合わせる。英語と日本語の両方を直し、使わなくなったキーは String Catalog から消す（`fmt-check` は `stale` のキーで失敗する）。新しい文言は既存の文体に合わせる。
8. テスト: 消した振る舞いのテストは消し、変わった振る舞いのテストは仕様 ID をテスト名に持たせて直す。自明でない新しい規則（起動時の輝度、記録の保存の失敗と削除の試み直し、所有の初期値）にはテストを足す。

ブランチ `spike/daemon-cleanup-probe` のコミット `1b42313` は、agent の登録を外して動かす試作である。参考にしてよいが、試作のための処理（`Spike` のログ、`unregisterAgent` など）は入れない。

## 完了条件

- 上の内容が実装され、仕様と食い違う振る舞いが残っていない。削った型・ファイル・設定キーへの参照が残っていない。
- `nix develop --command just check` と `nix develop --command just build` が通る。
- 報告に、消したもの、残したもの（とその理由）、記録の形式の選択、仕様と合わない点や判断に迷った点を書く。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- アプリを起動しない。`sudo`、`launchctl`、`pmset` の設定変更、SMAppService の登録をしない。

## レビュー

（PM が書く）
