# 実機での確認手順

オーナーが承認済みの検証用 Mac で、Debug アプリの起動、抑止、復旧、画面を確かめる手順を置く。1つのファイルが1つの検証で、そのファイルだけを読めば始めから元に戻すまで実施できる。確かめたいことのファイルだけを開き、ほかのファイルの手順は行わない。

本文のコマンドは、実際に走らせた記録が残るまでソースとの静的照合しかしていない。ここに書いた期待値を「確かめた事実」として扱わない。確かめた結果は PM が根拠（`EVID-*`）にする。

## 進め方

1. 最初の1回だけ、[`prepare.md`](prepare.md) で開始前の状態を退避先 `B` に保存し、起動前ゲートを通る。ゲートを通らなければ、ほかのファイルを実施しない。
2. 確かめたいことのファイルを下の一覧から選び、そのファイルの「始める前に」から順に行う。
3. すべて終えたら、[`cleanup.md`](cleanup.md) で開始前の状態に戻し、結果を PM に渡す。

実行するのはオーナーである。justfile の `app` グループ（`start`、`stop`、`restart`、`status`）は、エージェントもオーナーの承認を得て実行できる（`DEC-SYS-024`）。それ以外の操作はオーナーが行う。

## 一覧

「システムを変える」は、管理者権限、SMAppService の登録や許可の変更、ログアウト・再起動のどれかを含むものである。アプリの起動自体も agent と mainApp の登録を伴うため、一覧の「なし」はその共通の操作に加える変更がないことを表す。

| ファイル | 確かめること | システムを変える |
| --- | --- | --- |
| [`assertions.md`](assertions.md) | 設定ごとのアサーション | なし |
| [`display-sleep-and-hardware-detection.md`](display-sleep-and-hardware-detection.md) | 画面消灯、スクリーンセーバー、MacBook とバッテリーの判定 | システム設定 |
| [`lid-close-setting.md`](lid-close-setting.md) | 「ディスプレイを閉じたとき」の表示と説明 | なし |
| [`manual-and-lid-sleep.md`](manual-and-lid-sleep.md) | 手動のスリープとディスプレイを閉じたときのスリープを止める | ヘルパーの設置 |
| [`disablesleep-persistence.md`](disablesleep-persistence.md) | Daemon がないときの `disablesleep` の永続性 | 管理者権限、再起動 |
| [`led-remapper.md`](led-remapper.md) | キー配列を変更するアプリの案内の出し入れ | なし |
| [`quit-and-crash-resume.md`](quit-and-crash-resume.md) | 利用者の終了とクラッシュの区別、再開 | なし |
| [`logout-restart-crash-limit.md`](logout-restart-crash-limit.md) | ログアウト・再起動・システム終了と再開、連続クラッシュの上限 | ログアウト、再起動 |
| [`cli-launch.md`](cli-launch.md) | 停止したアプリを CLI から起動し、出力と終了コードを見る | なし |
| [`cli-invalid-input.md`](cli-invalid-input.md) | CLI の不正な引数と、CLI を許可しない設定 | なし |
| [`cli-help-no-time-limit-color.md`](cli-help-no-time-limit-color.md) | CLI のヘルプ、`--no-time-limit`、色を付けない出力 | なし |
| [`menu-and-panels.md`](menu-and-panels.md) | メニューの並びと時間・時刻の入力パネル | なし |
| [`settings-and-appearance.md`](settings-and-appearance.md) | 設定画面の構成と外観 | システム設定 |
| [`hud-hotkey-accessibility.md`](hud-hotkey-accessibility.md) | HUD、複数画面、ホットキー、アクセシビリティ | システム設定 |
| [`settings-window-placement.md`](settings-window-placement.md) | 設定画面を開くデスクトップと前面 | システム設定 |
| [`change-time-while-active.md`](change-time-while-active.md) | 抑止を続けたまま時間を変更する | なし |
| [`menu-sleep-settings.md`](menu-sleep-settings.md) | クイック設定のスリープとディスプレイの項目 | なし |
| [`menu-battery.md`](menu-battery.md) | クイック設定のバッテリー残量の項目 | なし |
| [`localization.md`](localization.md) | 英語・日本語の表示と時刻の表記 | システム設定 |
| [`login-and-crash-restart.md`](login-and-crash-restart.md) | mainApp によるログイン時の起動と agent によるクラッシュ後の再起動 | 登録、ログアウト |
| [`helper-approval-guidance.md`](helper-approval-guidance.md) | 承認待ちで設定を選んだときのアラートと行の下の状態の文 | ヘルパーの登録、システム設定 |
| [`agent-unregister-cleanup.md`](agent-unregister-cleanup.md) | 試作の起動時に Debug agent の登録だけを外す | agent とヘルパーの登録、管理者権限 |
| [`debug-agent-worktree-switch.md`](debug-agent-worktree-switch.md) | `just start` による worktree 間の Debug agent の切り替え | agent の登録 |

ヘルパーの設置と承認、on と off、許可を外したときの表示、起動時の後片付け、削除、更新後の登録し直し、Finder からの起動の引き渡しは `EVID-HLP-006` で確認済みなので、専用の検証ファイルは置かない。残る検証の前提を作るための設置・許可と、最後の削除は各ファイルに書く。承認待ちの新しいアラートと状態の文は `helper-approval-guidance.md`、ログイン時の起動とクラッシュ後の再起動は `login-and-crash-restart.md` で確かめる。

`APP` を使うファイルでは、`prepare.md` で署名・公証済みの PR Debug ビルドか、Developer ID で署名し直した手元のビルドを選ぶ。`/Applications` の PR ビルドを対象に指定するファイルでは、PR ビルドを使う。`APP` を明記しないファイルと worktree 切り替えの検証は、手元の `.build/xcode/Build/Products/Debug/Capsaicin.app` を使い、agent やヘルパーを確かめる前に `just sign-debug` で署名し直す。実行するファイルの対象に合わせて準備し、途中で PR ビルドと手元のビルドを混ぜない。対象を変えるときは先に `cleanup.md` を終える。

## 共通の決まり

上から順に実行する。前提がそろわない手順は飛ばして判定不能とし、成功に数えない。失敗を無視して次へ進む一括実行はしない。

- **判定不能**: 前提がそろわない、測る手段がない、結果が他の要因と区別できない。試験そのものは安全に続けられる。
- **中止**: 状態が期待から外れ、このまま進むと元に戻せなくなるおそれがある。後続を止め、そのファイルの「中止するとき」と「元に戻す」に従う。

中止したときは、どの操作の直後に、何が、どう違ったかを書く。中止を「失敗」と混ぜない。製品の不具合が疑われる場合だけ失敗とし、根拠になる出力を添える。期待と実測が違ったら、まず実測をそのまま残す。期待の書き方が悪いのか製品が違うのかは PM が判断する。

記録は、生の出力を貼るのではなく「期待と照らした結論」で書く。たとえば `操作3: ログイン後 state=not running、pid なし` のように残す。生の出力、画面写真、録画は `B` に置き、結果にはその絶対パスを書く。結果は各ファイルの「記録」が指定する `B` のファイルに書く。

```text
成功／失敗／判定不能: 成功（操作4のクラッシュ後の再起動まで）
観測値: mainApp オフで再ログイン後 pid なし、手動起動 pid 2345、SEGV 後 pid 2456
復元: SleepDisabled 0、ヘルパー未インストール、ログイン時に起動オフ、アプリと登録の削除確認、LED 通常連動
未実施と理由: HYP-LCY-003 は経路別の環境記録機能がないため判定不能
写真・ログ: /Users/<user>/Capsaicin-verification.ab12cd/general-warning.png
```

### 用語

| 言葉 | この手順での意味 |
| --- | --- |
| ジョブ | バンドル内の定義を `SMAppService.agent` で登録した agent の launchd ジョブ。Debug のラベルは `io.github.koutyuke.capsaicin.debug` |
| 引き渡し | 直接起動したアプリが agent を登録し、`launchctl kickstart` で起動を求め、成功したら自分は終了する仕組み。動き続けるのは agent から起動した個体である |
| mainApp | `SMAppService.mainApp` によるログイン時の起動の登録。「ログイン時に起動」で切り替える。agent の登録とは別である |
| `SleepDisabled` | `pmset -g` に出るシステム全体の値。`1` ならスリープしない |
| `B` | `prepare.md` で作る退避先。開始前の設定、記録、画面写真、結果を置く。`cleanup.md` を終えるまで消さない |
| デーモン | `SMAppService.daemon` で登録するヘルパー。Debug のラベルと Mach サービス名は `io.github.koutyuke.capsaicin.debug.helper` |
| バンドル内の定義 | agent は `Contents/Library/LaunchAgents/<bundle ID>.plist`、デーモンは `Contents/Library/LaunchDaemons/<bundle ID>.helper.plist`。どちらも `project.yml` のビルドフェーズが作る |
| `APP` | `prepare.md` で選び、`B/app-path.txt` に保存した検証対象のアプリの絶対パス |
| BTM の記録 | `sfltool dumpbtm` が示す、ログイン項目とバックグラウンドの登録の記録 |

### `just` の app レシピ

- `just status`: agent のジョブの `state`・`pid` と、PID から引いた実行ファイルの絶対パスを `Job executable:` に表示する。`Job matches this checkout:` は、このチェックアウトの実行ファイルと一致すれば `yes`、異なれば `no`、ジョブが動いていなければ `unknown (job is not running)` になる。停止中はどのチェックアウトのジョブか判断しない。全チェックアウトの手元の Debug プロセスは、PID・開始時刻・PPID・実行ファイルの絶対パスを表示する。`SleepDisabled` と Capsaicin のアサーションも表示する。plist の有無や SMAppService の許可状態は調べない。終了コードは常に `0` なので、成否は表示で判断する。`/Applications` の PR ビルドはプロセス一覧の対象外なので、その不在の判定には使わない。
- `just stop`: どのチェックアウトの Debug アプリにもまず quit を送る。10秒たっても残るプロセスだけに `SIGTERM` を送り、さらに5秒待つ。`SIGTERM` で止めたプロセスは後片付けを通らないので、抑止中に残ったときは `just status` で `SleepDisabled` とアサーションを確かめる。
- `just start`: 全チェックアウトの手元の Debug アプリが動いていないことを実行ファイルの絶対パスで確かめ、読み込み済みのジョブを外してからこのチェックアウトのビルドを開く。ジョブの PID の実行ファイルがこのチェックアウトと一致し、PPID が `1` になるまで最大10秒待つ。成功時は `Started Debug PID <PID>: <絶対パス>` を表示する。直接起動したアプリだけが動き続けている場合も失敗する。ジョブを残した起動を試す手順では使わない。
- `just restart`: ビルドに成功してから `stop`、`start` の順に実行する。

`/Applications` の PR ビルドは、`/usr/bin/open "$APP"` で起動し、メニューから終了する。登録の状態は、アプリの「ヘルパー」、システム設定の「一般 > ログイン項目と機能拡張」、`sfltool dumpbtm`、`launchctl print` の読み取りを照合する。`launchctl print-disabled` だけで SMAppService の許可状態を判断しない。agent とデーモンは、バックグラウンドの一覧では1つの Capsaicin の項目にまとまる。

## つまずいたときの切り分け

当てはまらないときは、そのまま中止して記録する。

| 症状 | まず確かめること |
| --- | --- |
| Debug プロセスが0本、または2本以上 | `just status` でジョブの PID と全 Debug プロセスを読み直す。5秒待って再確認する |
| `just start` が失敗する | 直接起動したアプリが残っていても成功に数えない。`just status` のジョブの PID・`Job executable:` と全 Debug プロセスを読む。署名の `Authority` と次のログを照合し、起動を繰り返さない |
| ログに `Launch Constraint Violation` がある | `/usr/bin/log show --last 5m --predicate 'process == "launchd"' \| grep 'Launch Constraint Violation'` で読む。同じ bundle ID の Developer ID 署名のビルドが登録した agent は、ad-hoc や「Apple Development」で署名したビルドでは起動できない（`EVID-LCY-005`）。手元のビルドを止め、`just sign-debug` で「Developer ID Application」の証明書を使って署名し直す（`DEC-SYS-026`） |
| agent の登録や起動が失敗する | アプリの「一般」の警告、システム設定の許可、BTM の識別子とアプリのパス。手作業の登録で回避しない |
| ログイン時に起動しない | 「ログイン時に起動」、mainApp の登録とシステム設定の「ログイン時に開く」、バックグラウンドの許可。agent の `RunAtLoad` は `false` のままである |
| ヘルパーが「システム設定での許可待ち」になる | システム設定で Capsaicin の項目を許可する。agent も同じ項目なので両方の状態を見る |
| ヘルパーが「このビルドでは使用不可」になる | ad-hoc 署名では使えない。手元では停止後に `just sign-debug` で Developer ID で署名し直すか、署名に Team ID がある PR Debug ビルドを使う |
| `SleepDisabled` が戻らない | 承認済みの復旧操作 `/usr/bin/sudo /usr/bin/pmset -a disablesleep 0` の直後に `/usr/bin/pmset -g` で読む。成功しても設定変更のコマンド自体は何も出力しない。戻らなければ PM に報告する |
| LED が通常連動に戻らない | `B` にある承認済みの LED 復旧手順を実行する。読み戻した値だけで合格にしない |

## 手順書を書くときの決まり

新しく確かめることができたら、既存のファイルに書き足さず、新しいファイルを作って上の一覧に載せる。ファイル名は確かめることを表す短い英語にする。検証を終え、PM が結果を根拠（`EVID-*`）に移したら、そのファイルと一覧の行を削除する。同じことを確かめ直すときは、そのときの実装に合わせて新しく作る。

1つのファイルで完結させる。始め方、状態を作る操作、中止したときの戻し方、元に戻す操作を、そのファイルの中にコマンドで書く。「上記の」「操作2と同じ」「別のファイルの手順で」のようにコマンドを参照させない。読み手が上へ戻ったり別のファイルを開いたりせずに済むよう、同じコマンドが何度出ても書く。参照してよいのは、最初に1回だけ行う `prepare.md` と、最後に行う `cleanup.md` だけである。

画面の項目名、選択肢、メニュー項目、ボタン、CLI のサブコマンドとオプション、ファイルやキーの名前は、記憶や古い文書から写さず、実装から引いて書く。名前は実装の変更で変わるので、書くたびに引き直す。

| 名前 | 引く場所 |
| --- | --- |
| 画面の文言（設定、メニュー、パネル、HUD、アラート） | `Sources/Capsaicin/**/*.xcstrings` の `ja` の値。英語表示の確認では `en` |
| CLI のサブコマンド、オプション、終了コード | `Packages/CapsaicinKit/Sources/CapsaicinIPC/CLIArguments.swift`、`ExitCode.swift` |
| 再開用の記録のキー | `Packages/CapsaicinKit/Sources/CapsaicinCore/Lifecycle/ResumeRecord.swift` |
| ヘルパーの識別子、登録、要求と起動の記録 | `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Helper/HelperRegistration.swift`、`HelperSleepController.swift`、`Sources/capsaicin-helper/request.c`、`boot.c` |
| agent とデーモンの plist のパスとキー | `project.yml` の `postBuildScripts`（`BundleProgram`、`MachServices`、`RunAtLoad`、`KeepAlive.Crashed`） |
| agent と mainApp の登録、引き渡し | `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Lifecycle/LaunchAgent.swift` |
| `just` のレシピ | `justfile` |

macOS のシステム設定の項目名は実装にないので、検証に使う macOS の画面で確かめる。確かめられなかった名前は、そのことを手順に書く。

ファイルは次の節で構成する。

1. 冒頭: 何を確かめるか、対応する仕様・仮説の ID
2. 始める前に: 前提、devShell と `B` の入れ方、開始時の状態を作るコマンド
3. 操作と期待: 番号付きの操作と、その操作ごとの期待
4. 中止するとき: 止める条件と、そのとき実行するコマンド
5. 元に戻す: 開始時の状態へ戻すコマンド
6. 記録: 残す観測値と、結果を書く `B` のファイル
