---
schema: task
id: TASK-007
title: CLI とアプリの通信路と、capsaicin コマンドを作る
status: todo
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

既存の `IPCMessages.swift`、`IPCCoding.swift`、`CLIArguments.swift`、`ExitCode.swift` は、通信路に必要な最小限の変更だけをしてよい。変更したら理由を報告する。

触らない: `CapsaicinCore`、`CapsaicinPlatform`、`Package.swift`、アプリ、ヘルパー、`docs/`、`project.yml`。ほかの場所の変更が必要なら、変更せずに報告する。

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

- たとえば、アプリのバンドルに CLI 用のテーブルを置き、CLI が自分を含む `.app` のバンドルから読む方法がある。
- 文言は仮のものでよい。最終の文言は別のチケットで入れる。
- カタログの置き場所が `project.yml` の変更を要するなら、変更せずに必要な変更を報告する。

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

未実施。
