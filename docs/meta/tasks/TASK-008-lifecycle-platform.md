---
schema: task
id: TASK-008
title: 記録と設定の保存、LaunchAgent、終了の種類の判定を作る
status: done
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
- `Packages/CapsaicinKit/Sources/CapsaicinCore/Controller/BlockingController+Lifecycle.swift`（判定不能の終了経路だけ）
- `Packages/CapsaicinKit/Sources/CapsaicinCore/Lifecycle/ResumeRecord.swift`（`exitReason` の説明だけ。保存形式は変えない）
- `Packages/CapsaicinKit/Tests/CapsaicinCoreTests/ControllerLifecycleTests.swift`（判定不能の終了と再開防止の検証）
- `Packages/CapsaicinKit/Tests/CapsaicinCoreTests/ControllerUnknownTerminationTests.swift`（追加の終了経路の検証）

触らない: 上記以外の `CapsaicinCore`、`CapsaicinIPC`、ほかの `CapsaicinPlatform` のディレクトリ、`Package.swift`、アプリ、CLI、ヘルパー、`docs/`、`project.yml`。ほかの場所の変更が必要なら、変更せずに報告する。

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

アプリが終了するとき、利用者の終了か、セッションの終了（ログアウト、再起動、システム終了）による終了かを判定する（`HYP-LCY-005`）。判定不能も結果として返し、`DEC-LCY-004` に従う Core の終了経路を用意する。判定に使う Apple Event は非同期処理前に採取し、その終了試行の情報として渡す。通知の順序を仮定した常設フラグは使わない。

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

保存部分の6ファイルを Astra / high が独立レビューし、完了を妨げる指摘はなかった。ファイル境界、原子的な置換、失敗時の旧記録保持、Core の復号契約の再利用を確認した。LaunchAgent は実装後に別途レビューする。

保存部分は未実装 API によるコンパイル失敗を RED とし、実行されたテストは0件だった。GREEN のログは18テスト・4スイート・46ケースで、対象6ファイルの整形・lint も成功している。ただし、最終ソースと実行済みバンドルの一致は未確認のため暫定の証拠とする。並行実装の終了後、PM が標準の `just check`・`just build` で最終ツリーを検証する。

終了理由判定と理由不明の終了経路の5ファイルも、Astra / high の独立レビューで完了を妨げる指摘はなかった。`terminateForUnknownReason()` のセッション消去と後片付けの順序、失敗時の所有・警告の保持、状態を持たない `TerminationReasonDetector.classify(explicitUserQuit:appleEvent:)` の厳密な型・理由判定を確認した。既存の24テスト成功ログも確認済みで、PM の最終 `check`・`build` を受け入れ条件とする。

終了部分の RED は新 API 不在によるコンパイル失敗で、テスト実行は0件だった。実装担当は、最終ソースでの対象24テスト（新規9、既存15。展開31ケース）と、対象5ファイルの整形・strict SwiftLint の成功を報告した。証跡は `.build/task008-termination-{red,green,final}.log` にある。

合成した Apple Event による検証を、実OSの descriptor 型・配置・到着順序の確認とは扱わない。`HYP-LCY-005` は未検証であり、アプリが非同期処理前にイベントを採取する接続も未実装である。

## 先行実装と保留事項

保存処理（上の 1・2）を先行し、その実装終了後に終了判定（4）を追加する。LaunchAgent（3）は方式の検証後に実装する。保存処理だけの完了を、このチケット全体の完了とは扱わない。

- 再開用の記録は Core の JSON 復号契約を使う。同一ディレクトリ内の一時ファイルを置き換え、置換成功を保存完了とする。電源断後の永続性は保証に含めない。
- 設定は Core の `Settings` を JSON の `Data` として `UserDefaults` の固定キーに保存する。個別値の既定値と検証は Core に委ねる。
- 保存担当は一時領域と専用スイートで往復・権限・保存失敗時の旧記録保持を検証する。独立レビュアーが境界と契約を確認し、PM が全体検証を担当する。

LaunchAgent は、`HYP-LCY-002` の非起動条件と `launchd.plist(5)` の KeepAlive に関する記述が整合するか未確認である。`TASK-009` で現行方式の手動検証を準備する。ログイン設定だけの変更は次回ログインへ反映し、実行中の自分を `bootout` しない。アプリの移動など、現在の監督対象の変更は別に判断する。

起動由来と終了理由は `HYP-LCY-003`・`HYP-LCY-005` の実機保証が未確認である。判定不能の扱いは利用者が承認した `DEC-LCY-004` に従う。調査・自動検証で `launchctl` や実機の登録・設定変更は実行しない。

2026-11-06: LaunchAgent（3）を実装し、PM がレビューした。読み込み済みのジョブで `bootstrap` が失敗しても `kickstart` が成功すれば起動できるよう、PM が直した。`HYP-LCY-002`、`HYP-LCY-003`、`HYP-LCY-005` の実機での確認は、アプリへの組み込みの後に、承認を得て行う。
