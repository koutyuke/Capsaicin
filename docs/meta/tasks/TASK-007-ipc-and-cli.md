---
schema: task
id: TASK-007
title: CLI とアプリの通信路と、capsaicin コマンドを作る
status: done
requirements: []
depends_on: [TASK-003]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-007 CLI とアプリの通信路と、capsaicin コマンドを作る

## 目的

CLI とアプリをつなぐ Unix ドメインソケットの通信路と、`capsaicin` コマンドの本体を作る。アプリの側で要求をコントローラーに渡す組み込みは、別のチケットで行う。このチケットでは、アプリが要求を受け取る口（要求を受けて応答を返す処理を渡せる型）までを用意する。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinIPC/` の通信路のためのファイル（新しいサブディレクトリにまとめる）
- `Packages/CapsaicinKit/Tests/CapsaicinIPCTests/` の通信路のテスト
- `Sources/capsaicin-cli/`
- `Sources/Capsaicin/CLI/CLI.xcstrings`（CLI 用カタログだけ）
- `Tests/CapsaicinTests/`（CLI のロジック・バンドル・カタログの検査）
- `project.yml`（CLI の package product 依存と、CLI ロジックをホストなしテストへ取り込む指定だけ）

既存の `IPCMessages.swift`、`IPCCoding.swift`、`CLIArguments.swift`、`ExitCode.swift` は、通信路に必要な最小限の変更だけをしてよい。変更したら理由を報告する。

触らない: `CapsaicinCore`、`CapsaicinPlatform`、`Package.swift`、上記カタログ以外のアプリ、ヘルパー、`docs/`。ほかの場所の変更が必要なら、変更せずに報告する。

## 作るもの

仕様は `docs/specs/cli.md` のすべて、`docs/specs/blocking.md` の `SPEC-BLK-011`、`docs/specs/lifecycle.md` の `SPEC-LCY-005` に従う。方式は `DEC-CLI-001`、`DEC-CLI-002`、`DEC-LCY-002`、`DEC-SYS-007` にある。

### 1. 通信路

`DEC-CLI-002` に従う。

- 利用者だけが読み書きできるディレクトリ（`0700`）に Unix ドメインソケットを置く。
  - 置き場所を決め、理由を報告する。
  - Debug ビルドはソケットの名前を分ける（`DEC-SYS-008`）。
  - アプリが異常終了して古いソケットが残っていても、次の起動で使えるようにする。
- 接続相手の uid を `getpeereid` で照合し、違えば応答せずに切る。
- 要求と応答は、既存のバージョン付きの JSON の型を使う。大きさの上限とタイムアウトを持つ。上限を超えた入力は読み続けない。
- アプリの側の口は、要求を受けて応答を返す処理を渡せる形にする。その処理はメインスレッドで呼ぶ（コントローラーが `@MainActor` のため）。

### 2. `capsaicin` コマンド

- 引数の解析は、既存の `CLIArguments` を使う。
- アプリに接続できないときは、自分を含む `.app` の起動を求め、接続できるまで期限付きで待つ（`SPEC-CLI-004`）。
  - 自分を含む `.app` は、自分の実行ファイルの実際のパスから求める。
  - 直接起動されたアプリは launchd に引き渡してから終わる（`DEC-LCY-002`）。そのため、最初に起動したプロセスではなく、ソケットに接続できたことで待ち終える。
- 出力と終了コードは `SPEC-CLI-003` と `SPEC-CLI-007` に従う。CLI は既定値や抑止の状態を自分で判断せず、アプリの応答をそのまま使う（`DEC-SYS-007`）。

### 3. CLI の文言

文言の正本は String Catalog にする（`SPEC-UI-011`）。CLI はバンドルを持たないので、カタログをどこに置き、どう読むかを決め、理由を報告する。

- `Sources/Capsaicin/CLI/CLI.xcstrings` をアプリのバンドルへ収録し、CLI が自分を含む `.app` のバンドルから `CLI` テーブルを読む。
- 文言は仮のものでよい。最終の文言は別のチケットで入れる。
- `project.yml` の変更は、上の「範囲」に示した依存・テスト指定に限る。

## 守ること

- ソケットのテストは、テストごとの一時ディレクトリで行い、アプリの本当のソケットの場所を使わない。
- テストで、アプリを起動しない。`launchctl` を実行しない。
- `AGENTS.md` の「破ってはいけないもの」を守る。

## 完了条件

- 上の 1〜3 がある。
- 次の場面に Swift Testing のテストがあり、テスト名に仕様の ID を含む。
  - 通信路の往復
  - uid が違う相手の拒否（相手の uid を偽物にして確かめる）
  - 上限を超えた入力
  - タイムアウト
  - バージョンの不一致
  - 古いソケットの扱い
  - 応答から終了コードと出力を決める処理
  - 自分を含む `.app` の求め方
- 本番コードに `REQ-*` と `SPEC-*` を書いていない。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just test-package`
- `nix develop --command just check`
- `nix develop --command just build`

## レビュー

初回の独立レビューで P2 が2件あり、修正後の独立再レビューで両方の解消を確認した。

- クライアントが要求と応答の種類を照合していない。`off` に `.status` が返る場合などをプロトコルエラーとして拒否し、CLI は69と標準エラー出力で失敗を伝える。失敗後に再接続・再送しない。
- 未対応バージョンを通常の handler へ渡している。元の実装は `Result.failure` として渡しており、実際に Core 操作が実行されたことを示す指摘ではない。PM は境界を明確にするため、通常の handler は検証済みの `IPCRequest` だけを受け取る契約とし、未対応版は handler を呼ばず接続を閉じる。拒否応答のための偽の状態や、別の状態取得 API は追加しない。

実ソケットの不一致応答と未対応版で回帰を検証した。ヘルパーの独立した警告と wire version 2 の追補は、Core の追補後に `TASK-006` で実装した。追補の独立レビューは初回実装と分けて行う。

修正担当は2件を6ファイルで修正した。実ソケットによる RED は26ケース中13ケース失敗、15 assertion であり、並列待ちによる別の失敗とは分けて取得した。最終ソースの SwiftPM 39テスト・8スイートと、生成後のホストなし CLI テスト10件が成功した。対象6ファイルの整形差分と strict SwiftLint の違反は0件で、証跡は `.build/task007-fixes-{red,green,style}.log` にある。

Astra / medium の独立再レビューはブロッカーなしだった。全24組の応答照合、不一致時の切断とエラー伝播、未対応版・未知コマンドの handler 予約0回・実行0回、CLI の再接続・再送なしを確認した。期限・generation・MainActor の開始判定も維持されている。PM の最終 `check`・`build` が受け入れ条件として残る。

## 実装の検証

実装担当は、SwiftPM の対象38テスト・8スイートと、生成後のホストなしアプリテスト21件の成功を報告した。対象 Swift の整形差分はなく、strict SwiftLint は違反0件だった。初期 RED は未実装型と共有 CLI ソースの不足によるコンパイル・生成失敗である。証跡は `.build/task007-{final,ipc-test,cli-test,lint}.log` にある。

標準の全体 `just check`・`just build` は、全 writer の終了後に PM が実行する。実機のアプリ起動・launchd 引き渡しと、Gemini による仮文言の検討は未実施である。

## 実装と検証の分担

通信路と CLI は同じ担当が実装し、公開 API の不一致を避ける。通信路は一時ソケット、CLI は偽の接続・起動処理で検証する。CLI のエントリーポイント以外のソースをホストなしテストへ取り込み、新しいモジュールは増やさない。

既存バンドル検査の不正引数と終了コード 64 は維持する。テスト名の「雛形」は実装後の内容に合わせて直す。ヘルパーへ有効な `on`・`off` を渡す検査には変えない。

実装担当が対象テストと整形・lint、独立レビュアーが認証・資源所有・期限・再送禁止の契約、PM が全体の `check`・`build` を担当する。CLI の日本語は仮文言とし、後続の Gemini による文言検討へ引き継ぐ。

2026-11-06: 通信路は TASK-010 でブロッキングの実装に簡素化し、PM が `just check` と `just build` を通して完了とした。CLI の最終の文言は文言の統合のチケットで入れる。
