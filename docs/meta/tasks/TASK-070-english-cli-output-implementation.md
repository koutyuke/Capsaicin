---
schema: task
id: TASK-070
title: CLI の英語の出力、--help、--no-time-limit を実装する
status: done
requirements: ["REQ-CLI-001", "REQ-CLI-003", "REQ-CLI-007", "REQ-SYS-003", "REQ-SYS-004"]
depends_on: []
assignee: Codex（OpenCode、openai/gpt-6.1-sol、variant high）
---

# TASK-070 CLI の英語の出力、--help、--no-time-limit を実装する

## 目的

`DEC-CLI-003` を実装する。仕様（`docs/specs/cli.md`）は別のエージェントが同時に直しているので、食い違えば `DEC-CLI-003` とこのチケットを正とする。

## 範囲

書いてよい:

- `Sources/capsaicin-cli/`
- `Packages/CapsaicinKit/Sources/CapsaicinIPC/CLIArguments.swift`
- `Sources/Capsaicin/CLI/CLI.xcstrings`（削除する）
- `Tests/CapsaicinTests/CLI/`
- `Tests/CapsaicinTests/Settings/SettingsTests.swift`（`CLI` テーブルを読む期待を消す分だけ）
- `Packages/CapsaicinKit/Tests/CapsaicinIPCTests/CLIArgumentsTests.swift`
- `project.yml`（CLI の String Catalog やソースの列挙に関わる記述があり、直す必要があるときだけ）

触らないもの: 上記以外のすべて。特に `docs/`（読むだけ）、アプリ本体の `Sources/Capsaicin/` の Swift ファイル、IPC の形式（`IPCMessages.swift`、`IPCCoding.swift`）。`git add`、`git stash`、`git commit` をしない。

読むもの:

- `AGENTS.md`
- `DEC-CLI-003`（正はこれ）、`DEC-BLK-009`
- `docs/specs/cli.md`、`docs/specs/menu.md` の `SPEC-MENU-004`（残り時間の丸め）
- `Sources/capsaicin-cli/` の全体、`Packages/CapsaicinKit/Sources/CapsaicinIPC/`、`Tests/CapsaicinTests/CLI/`、`Packages/CapsaicinKit/Tests/CapsaicinIPCTests/CLIArgumentsTests.swift`
- `Sources/Capsaicin/MenuBar/MenuContent.swift` の `time` と `duration`（時刻と残り時間の表し方。CLI はアプリのコードを使えないので、同じ規則で書く）

## 作るもの

### 引数

- `on` に `--no-time-limit` を足し、`.start(.noTimeLimit)` にする。値は取らない（`--no-time-limit 1h` は `1h` が受け付けない引数になる）。
- `--for`、`--until`、`--no-time-limit` のうち違う2つを指定したら `conflictingOptions`、同じものを2回指定したら `duplicateOption` にする。
- `-h` か `--help` が引数のどこかにあれば、解析せずにヘルプを出す。判定は `CLIRunner` で、引数の解析とバンドルの確認より前に行う。アプリに接続せず、`.app` の外でも出す。
- 引数の解析の誤りは、バンドルを確かめずに出す（文言をバンドルから読まなくなるため）。今の「バンドルを持たないコピーにだけ必要な bootstrap 診断」はなくす。
- IPC の形式とバージョンは変えない。`StartTimeOverride.noTimeLimit` は既に形式に含まれている。

### 言語と文言

- 文言はすべて英語で、CLI のコードに書く。`CLIText`、`CLITextKey`、`Sources/Capsaicin/CLI/CLI.xcstrings` を消す。`CLIApplication` の `bundle` は文言のためだけにあるので消し、接続先の決定に必要なものだけ残す。
- 時刻はローカルのタイムゾーンで `H:mm`（`en_US_POSIX`、24時間制）。残り時間は `SPEC-MENU-004` と同じく分に切り捨て、1時間以上なら `1h 29m`、分が0なら `2h`、1時間未満なら `45m`、60秒未満なら `under a minute` とする。ロケールに左右される `DateComponentsFormatter` は使わない。
- 今の時刻とタイムゾーンは `CLIRunner` に差し込めるようにし、テストで固定する。タイムアウトに使う単調時計（`CLIClock`）とは分ける。

### 出力

結果と状態は標準出力、警告とエラーは標準エラー出力に出す。終了コードは今の `IPCResponse.exitCode` のまま変えない。どの出力も末尾に改行を付ける。

ヘルプ（標準出力、終了コード 0。色は付けない）:

```text
Turn Capsaicin's sleep prevention on and off from the command line.

Usage: capsaicin <command> [options]

Commands:
  on        Turn on sleep prevention
  off       Turn off sleep prevention
  status    Show whether sleep prevention is on

Options for on:
  --for <duration>    Turn off after a duration: 30m, 2h, 1h30m (1m to 24h)
  --until <time>      Turn off at a time of day: 4:00, 23:30 (24-hour)
  --no-time-limit     Don't turn off at a set time
  Without these options, on uses the timer and time set in Settings.
  While on, these options change when it turns off.

Options:
  -h, --help          Show this help

Exit status:
  0   Success. For status, sleep prevention is on.
  1   For status, sleep prevention is off.
  64  Invalid command or option.
  69  The request couldn't be completed.
```

結果の1行目（標準出力）:

| 結果 | 1行目 |
| --- | --- |
| `started` | `✓ Sleep prevention on` |
| `timeLimitReplaced` | `✓ Turn-off time updated` |
| `alreadyBlocking` | `• Sleep prevention is already on` |
| `released` | `✓ Sleep prevention off` |
| `alreadyStopped` | `• Sleep prevention is already off` |
| `status`（抑止中） | `● Sleep prevention on` |
| `status`（停止中） | `○ Sleep prevention off` |

詳細の行（標準出力）: 応答の状態が抑止中（`session` がある）のときだけ、1行目に続けて出す。字下げは2文字、ラベルは `Turns off` の幅（9文字）に右を空白で埋め、続けて空白2文字の後に値を書く。

| 行 | 出す条件 | 値 |
| --- | --- | --- |
| `Turns off` | いつも | 解除の時刻があれば `15:53 (in 1h 29m)`、なければ `when you turn it off` |
| `Battery` | `batteryCondition` があるとき | `turns off below 20%`。`ignoresOnACPower` なら続けて `, except on AC power` |

`alreadyBlocking` だけは、詳細の行の後に `  Use --for, --until or --no-time-limit to change when it turns off.` を出す。

例:

```text
✓ Sleep prevention on
  Turns off  15:53 (in 1h 30m)
  Battery    turns off below 20%, except on AC power
```

警告（標準エラー）: 応答を受け取ったときは、結果によらず、合わせられていない制御を `Mechanism.allCases` の順に、続けて記録を保存できていないことを、1件1行で出す。

| 対象 | `leftApplied` | `notApplied` |
| --- | --- | --- |
| `systemSleepDisabled` | `warning: couldn't restore system sleep` | `warning: couldn't prevent system sleep` |
| `idleSleepAssertion` | `warning: couldn't restore idle sleep` | `warning: couldn't prevent idle sleep` |
| `displaySleepAssertion` | `warning: couldn't restore display sleep` | `warning: couldn't prevent display sleep` |
| `led` | `warning: couldn't turn off the Caps Lock LED` | `warning: couldn't light the Caps Lock LED` |

記録を保存できていない: `warning: couldn't save the state used to resume after a relaunch`

アプリが要求を受け付けなかった結果（標準エラー。標準出力には何も出さない。警告は上のとおり続けて出す）:

| 結果 | 出力 |
| --- | --- |
| `startRejected(.batteryBelowThreshold)` | `error: couldn't turn on sleep prevention: the battery is below 20%`（しきい値は応答の `batteryCondition` から。なければ `the battery is below the threshold set in Settings`） |
| `startRejected(.helperNotInstalled)` | `error: couldn't turn on sleep prevention: the helper isn't installed; install or repair it in Settings` |
| `startRejected(.mechanismsFailed)` | `error: couldn't turn on sleep prevention: ` に続けて、失敗した対象ごとの上の表の `notApplied` の文（`warning: ` を除く）を `Mechanism.allCases` の順に `; ` でつなぐ |
| `startRejected(.recordNotSaved)` | `error: couldn't turn on sleep prevention: couldn't save the state used to resume after a relaunch` |
| `cliRequestsDisabled` | `error: commands from the CLI are turned off in Capsaicin Settings` |
| `unsupportedVersion` | `error: this command and the running Capsaicin are different versions` |

`released` と `alreadyStopped` で終了コードが 69 になるとき（警告が残ったとき）も、結果は標準出力、警告は標準エラーに出す。

接続の失敗（標準エラー、終了コード 69）:

| 失敗 | 出力 |
| --- | --- |
| 接続できない・通信が切れた（今の `.connection`） | `error: couldn't communicate with Capsaicin; the request may already have taken effect` |
| タイムアウト | `error: Capsaicin didn't respond in time; the request may already have taken effect` |
| アプリを起動できない | `error: couldn't launch Capsaicin` |
| 応答の形式が正しくない | `error: received an invalid response from Capsaicin` |
| 相手を確かめられない | `error: couldn't verify the connection to Capsaicin` |
| 応答のバージョンが違う | `error: this command and the running Capsaicin are different versions` |
| `.app` の中にない | `error: run this command from inside Capsaicin.app` |

使い方の誤り（標準エラー、終了コード 64）: `error: <理由>` の行に続けて `Run 'capsaicin --help' for usage.` の行を出す。入力の値は今と同じく `String(reflecting:)` で引用し、改行などをそのまま出さない。

| 誤り | 理由 |
| --- | --- |
| `missingSubcommand` | `missing command` |
| `unknownSubcommand` | `unknown command "foo"` |
| `unexpectedArgument` | `unexpected argument "foo"` |
| `missingValue` | `--for requires a value` |
| `duplicateOption` | `--for can only be used once` |
| `conflictingOptions` | `--for, --until and --no-time-limit can't be used together` |
| `invalidDuration` | `invalid duration "90" for --for; use 30m, 2h or 1h30m` |
| `durationOutOfRange` | `duration "25h" for --for is out of range; use 1m to 24h` |
| `invalidTime` | `invalid time "24:00" for --until; use H:MM, e.g. 4:00` |

### 色

- 標準出力と標準エラー出力のそれぞれで、出力先が端末（`isatty`）で、環境変数 `NO_COLOR` が空でない値で設定されておらず、`TERM` が `dumb` でないときだけ色を付ける。判定は環境変数と `isatty` の結果を引数に取る小さな関数にし、テストする。
- 付ける色（SGR。どれも直後に `\u{1B}[0m` で戻す）:
  - `✓`、`●`: 緑（`32`）
  - `•`、`○`、詳細の行のラベル、`alreadyBlocking` の案内の行: 淡色（`2`）
  - 1行目の記号の後の文: 太字（`1`）
  - `error:`: 太字の赤（`1;31`）、`warning:`: 太字の黄（`1;33`）
- ヘルプと、詳細の行の値には色を付けない。

### テスト

名前に仕様 ID を含める（`SPEC-CLI-001`、`SPEC-CLI-003`、`SPEC-CLI-007`、`SPEC-CLI-008`）。`SPEC-CLI-008` はヘルプの仕様として別のエージェントが足している。少なくとも次を確かめる。

- 引数: `on --no-time-limit` が `.start(.noTimeLimit)` になる。`--for 30m --no-time-limit`、`--no-time-limit --until 4:00` などが `conflictingOptions`、`--no-time-limit --no-time-limit` が `duplicateOption`、`--no-time-limit 1h` が `unexpectedArgument("1h")` になる。既存の引数のテストは残す。
- ヘルプ: `--help`、`-h`、`on --help`、`status -h`、`on --for x --help` で、ヘルプが標準出力に出て終了コード 0。接続、起動、バンドルの確認を一度もしない（バンドルの確認が失敗する設定でも出る）。
- 使い方の誤り: バンドルの確認が失敗する設定でも、上の文言と `--help` の案内が出て終了コード 64。
- 出力: 上の表の各結果について、色なしの標準出力・標準エラー出力・終了コードを文字列全体で確かめる。少なくとも、`started`（時間の条件あり・バッテリー残量の条件あり・電源アダプタの設定あり）、`timeLimitReplaced`、時間の条件なしの抑止中の `status`、`alreadyBlocking`、`released`、`alreadyStopped`、停止中の `status`、警告がある `released`（終了コード 69 で、結果は標準出力、警告は標準エラー）、各 `startRejected`、`cliRequestsDisabled`。
- 残り時間: 1時間30分、2時間ちょうど、45分、59秒、59分59秒（`59m`）。時刻はタイムゾーンを固定して確かめる。
- 色: 色を付ける判定の組み合わせ（端末かどうか、`NO_COLOR` なし・空・値あり、`TERM=dumb`）と、色ありの1つの出力の全体。
- `CLICatalogTests` は消す。`SettingsTests` の `CLI` テーブルを読む期待は消す。

## 守ること

- 起こりにくい場合への防御を重ねない。既存の仕組みを使い、新しい仕組みを作らない。文言のための抽象化（プロトコル、ローカライズ用の層）を作らない。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。
- 判断にない振る舞いを決める必要があったら、推測で埋めずに報告する。
- サブエージェントを起動しない。
- アプリを起動しない。CLI の実行ファイルを実際に動かして確かめない（アプリが起動し、スリープ防止の状態が変わるため）。確かめるのはテストで行う。

## 完了条件

- 次のコマンドが通る。`lint-docs` は別のエージェントが仕様を直している途中で落ちることがあるので使わない。
  - `nix develop --command just fmt-check`
  - `nix develop --command just lint-code`
  - `nix develop --command just test`
  - `nix develop --command just build`
- `rg -n "CLIText|table: \"CLI\"" Sources Tests Packages` で何も出ない。

## 検証

上のコマンドの結果。報告に、変えたファイル、主な結果ごとの出力（色なし）、迷った点を書く。

## レビュー

- 範囲の漏れ（PM）: `Tests/CapsaicinTests/App/AppModelTests.swift` が `CLIOutput` の古い API と日本語の出力を期待していた。PM が該当の期待だけを直すことを認め、英語の標準出力の全体を確かめる形にした。
- 範囲の漏れ（PM）: `Tests/CapsaicinTests/CapsaicinTests.swift` が、埋め込んだ `capsaicin` を引数なし、`--help`、不正な引数で実行し、日本語の出力を期待していた。担当は実行をやめる案を出したが、埋め込んだ実物が動くことを確かめる唯一のテストで、どの引数もアプリに接続しないので、実行は残して期待（64 と `error:` の2行、`--help` は 0 とヘルプの全文）を直すよう PM が指示した。
- 実装は判断とこのチケットのとおりで、直す点はなかった。
- PM がメインの作業ツリーで `lint`、`test`、`build` が通ることを確かめた。`fmt-check` は、オーナーの未追跡ファイル `buildServer.json` が整形されていないことで落ちるため、それを含まない一時的な worktree に同じ変更を当てて通ることを確かめた。ビルドした `capsaicin` で、アプリに接続しない `--help` と使い方の誤りの出力を確かめた。
