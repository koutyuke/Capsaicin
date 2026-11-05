---
schema: task
id: TASK-008
title: 記録と設定の保存、LaunchAgent、終了の種類の判定を作る
status: todo
requirements: []
depends_on: [TASK-003]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-008 記録と設定の保存、LaunchAgent、終了の種類の判定を作る

## 目的

アプリの起動と終了にかかわる、macOS とつながる部分を作る。

- 再開用の記録と設定の保存
- launchd の管理下で動かすための LaunchAgent の扱い
- 利用者の終了とセッションの終了による終了の判定

アプリへの組み込みは別のチケットで行う。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Lifecycle/`
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Settings/`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/Lifecycle/`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/Settings/`

触らない: `CapsaicinCore`、`CapsaicinIPC`、ほかの `CapsaicinPlatform` のディレクトリ、`Package.swift`、アプリ、CLI、ヘルパー、`docs/`、`project.yml`。ほかの場所の変更が必要なら、変更せずに報告する。

## 作るもの

仕様は `docs/specs/lifecycle.md` のすべてと、`docs/specs/settings.md` の `SPEC-SET-002` に従う。方式は `DEC-LCY-001`、`DEC-LCY-002`、`DEC-LCY-003`、`DEC-SET-002`、`DEC-SYS-008` にある。

### 1. `ResumeRecordStoring` の実装

`SPEC-LCY-007` とポートのコメントに従う。

- 利用者のアプリケーションサポートの下に、bundle ID ごとのファイルとして置く。Debug と Release で分かれる。
- 利用者だけが読み書きできる権限にする。
- 書くときはファイルを置き換え、書きかけの状態を残さない。
- 読めないとき（壊れている、形式が違う）は nil を返し、`os.Logger` でログに残す。ログに記録の中身を出さない。

### 2. 設定の保存

アプリの `UserDefaults` に、`CapsaicinCore` の設定の型を読み書きする（`DEC-SET-002`）。既定値と検証は `CapsaicinCore` にあるものを使い、ここで持たない。

### 3. LaunchAgent の扱い

`DEC-LCY-002`、`SPEC-LCY-001`、`SPEC-LCY-003`、`SPEC-LCY-005` に従う。

- plist の中身を作る。
  - ラベル（Debug は分ける）
  - 実行するアプリのパス
  - 「ログイン時に起動する」に対応する `RunAtLoad`
  - `KeepAlive` の `{ Crashed = true }`
- `~/Library/LaunchAgents` への登録、`RunAtLoad` の切り替え、`launchctl kickstart` による起動の要求を行う。
- 登録か起動に失敗したことと、利用者がバックグラウンド項目を無効にしていることを判定し、アプリが「クラッシュ時に再起動されない」と示せる結果を返す。判定の方法を選び、理由を報告する。
- アプリが launchd から起動されたかを判定する（`HYP-LCY-003`）。

### 4. 終了の種類の判定

アプリが終了するとき、利用者の終了か、セッションの終了（ログアウト、再起動、システム終了）による終了かを判定する（`HYP-LCY-005`）。判定の方法を選び、理由を報告する。判定に使う AppKit の通知や Apple Event をアプリから渡す形でもよい。

## 守ること

- テストで、`~/Library/LaunchAgents`、`/Library/LaunchAgents`、`/Library/LaunchDaemons` に書き込まない。`launchctl` を実行しない（`AGENTS.md`）。
- 実行の部分は、テストで偽物に差し替えられる境界の後ろに置き、テストは一時ディレクトリで行う。ただし、実装が1つしかない抽象を増やさない。
- 記録のファイルのテストは一時ディレクトリで行い、アプリの本当の保存先を使わない。
- 設定のテストは、テスト用の `UserDefaults` のスイートで行い、終わったら消す。
- 実機でしか確かめられない振る舞い（`HYP-LCY-002`〜`HYP-LCY-005`、`SPEC-LCY-001`、`SPEC-LCY-003`、`SPEC-LCY-005` の受け入れ例）は、確かめる手順を報告に書く。手順は PM が承認を得て実行する。
- `AGENTS.md` の「破ってはいけないもの」を守る。

## 完了条件

- 上の 1〜4 がある。
- 次の処理に Swift Testing のテストがあり、テスト名に仕様の ID を含む。
  - 記録の往復
  - 壊れた記録の扱い
  - 書き込みの原子性（置き換えで書くこと）
  - ファイルの権限
  - 設定の往復と、欠けたキーを既定値で補うこと
  - plist の中身
  - `RunAtLoad` の切り替え
  - launchd から起動されたかの判定
  - 終了の種類の判定
- 本番コードに `REQ-*` と `SPEC-*` を書いていない。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just test-package`
- `nix develop --command just check`

## レビュー

未実施。
