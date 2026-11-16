---
schema: task
id: TASK-099
title: 実機確認の操作を just のレシピに移し、手順書の変数を退避先だけにする
status: in_review
requirements: []
depends_on: []
assignee: Codex（OpenCode 経由の openai/gpt-6.1-sol）
---

# TASK-099 実機確認の操作を just のレシピに移し、手順書の変数を退避先だけにする

## 目的

[`DEC-SYS-020`](../decisions/DEC-SYS-020-manual-verification-just-recipes.md) を実装する。`scripts/manual/verify.sh` の操作を justfile の `manual` グループのレシピに移す。実機確認の手順書が持つシェル変数を退避先 `B` だけにする。

## 範囲

書いてよいファイルは次のとおり。

- `justfile`
- `scripts/manual/verify.sh`（削除する）
- `AGENTS.md`
- `docs/manual/verification.md`
- このチケット（「実装の報告」節だけ）

これ以外は変更しない。アプリ、CLI、ヘルパーのソース、`flake.nix`、`.envrc`、ほかの文書は触らない。範囲外の変更が必要だと分かったら、変更せずに報告する。

## 作るもの

### justfile

先頭の変数定義の近くに、次の2つを置く。

- `debug_id := "io.github.koutyuke.capsaicin.debug"`
- `debug_app := justfile_directory() / ".build/xcode/Build/Products/Debug/Capsaicin.app"`

`manual` グループ（`[group('manual')]`）に、次の4つのレシピを足す。`restart` 以外は `#!/usr/bin/env bash` と `set -euo pipefail` で始まる shebang レシピにする。各レシピの直前に、`just --list` に表示される英語の1行コメントを置く。

| レシピ | 振る舞い |
| --- | --- |
| `status` | 読み取りだけを行い、常に終了コード 0 で終わる。表示するのは、LaunchAgent のジョブ（`launchctl print gui/$UID/<debug_id>` の `state`、`pid`、`program`。読み込まれていなければその旨）、plist（`~/Library/LaunchAgents/<debug_id>.plist`）の `ProgramArguments` の先頭、このチェックアウトの実行ファイルのパスと、ジョブと plist がそれを指しているか、動いているすべての Debug プロセス（PID、開始時刻、実行ファイルの完全なパス）、`pmset -g` の `SleepDisabled`、`pmset -g assertions` のうち Capsaicin の行。 |
| `stop` | どのチェックアウトの Debug ビルドも対象にする。Debug プロセスがなければその旨を表示して 0 で終わる。あれば `osascript -e 'tell application id "<debug_id>" to quit'` を送り、最大10秒、すべての Debug プロセスが終わるのを待つ。残ったものだけに SIGTERM を送り、最大5秒待つ。それでも残れば PID を表示して 1 で終わる。 |
| `start` | Debug プロセスが1つでも動いていれば、`just stop` を先に実行するよう表示して 1 で終わる。`debug_app` がなければ、`just build` を先に実行するよう表示して 1 で終わる。ジョブが読み込まれていれば `launchctl bootout` で外す。`/usr/bin/open` で `debug_app` を開き、最大10秒、このチェックアウトの実行ファイルが Debug プロセスとして動くのを待つ。動いたら PID とパスを表示して 0、別の実行ファイルが動いた、または何も動かなければその事実を表示して 1 で終わる。 |
| `restart` | `restart: build stop start` とし、本体は持たない。ビルドに失敗したときに、動いているアプリを止めないためにこの順にする。 |

「Debug プロセス」は、コマンドラインが `/Build/Products/Debug/Capsaicin.app/Contents/MacOS/Capsaicin` で終わるプロセスとする。`pgrep -f` などで探し、チェックアウトのパスで絞らない。

守ること:

- レシピが出すメッセージ、`just --list` に出るコメント、レシピの本体として just が表示する行は、すべて英語にする。shebang レシピの本体のコメントは表示されないので、プロジェクトの規約どおり日本語で書く。
- 既存のレシピのうち、`just --list` に出る `dist` と `lint-build-tools` のコメント、`lint-code` の本体のコメント（just が表示する）、`lint-build-tools` のエラーメッセージも英語にする。意味は変えない。
- `sudo`、`pmset` の設定変更、LaunchAgents の plist の書き換えをしない。`launchctl` で使うのは `print`、`bootout` だけにする。
- コマンドは `/usr/bin/…`、`/bin/…` の絶対パスで呼ぶ。`verify.sh` と同じ方針である。
- `[confirm]` は付けない。
- 各レシピは短く保つ。起こりにくい場面への防御を重ねない。目安は、`status` が30行、`stop` と `start` がそれぞれ25行以内。

### scripts/manual/verify.sh

削除する。`scripts/manual/` が空になれば、ディレクトリも残さない。

### AGENTS.md

- 「破ってはいけないもの」の1の最後の文（`scripts/manual/` はオーナー専用の補助…）を、「justfile の `manual` グループのレシピ（`start`、`stop`、`restart`、`status`）はアプリの起動とプロセスの停止を行うオーナー専用の操作なので、エージェントは実行しない」という趣旨に置き換える。
- 「検証」の表に、4つのレシピの行を足す。オーナー専用であることを書く。

### docs/manual/verification.md

方針:

- シェル変数として残すのは `B` だけにする。`ROOT`、`ID`、`JOB`、`PLIST`、`RECORD`、`APP`、`HELPER`、`RULE`、`DAEMON` はリテラルに置き換える。
  - `ID` は `io.github.koutyuke.capsaicin.debug`。
  - `JOB` は `gui/$(id -u)/io.github.koutyuke.capsaicin.debug`。
  - `PLIST`、`RECORD`、`HELPER`、`RULE`、`DAEMON` は、`verify.sh` の `print_env` と1.2の定義にある完全なパス。`$HOME` は展開せずに書き、空白を含むパスは引用符で囲む。
  - `APP` はリポジトリのルートからの相対パス `.build/xcode/Build/Products/Debug/Capsaicin.app`。手順はリポジトリのルートで実行する前提である。`pgrep -fx` など絶対パスが要る箇所は `"$PWD/.build/…"` と書く。
- `CLI` は、使う節（7節と8.5）の冒頭で `CLI="$PWD/.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/Helpers/capsaicin"` と定義し、その節の中だけで使う。
- `B` を使う行のうち、`sudo`、`mv`、`trash` を含む行は `"${B:?}"` で参照する。
- 1.2の変数ブロックは、`B` の作成と、`printf '%s\n' "$PWD" > "$B/repository-path.txt"` だけにする。
- 0節は次の形にする。リポジトリのルートで `nix develop` に入る。メモした退避先を `B='…'` で入れ、`test -f "$B/repository-path.txt"` と、記録したパスが今いるルートと同じかを確かめる。`env` による「いちばん新しい退避先」の推測の記述は消す。アプリを起動するかは各小節の前提に従い、0節では無条件に `just restart` しない（2.2、4.4、4.6 などは起動していないことが試験の条件である）。足場の確認には `just status` を使う。
- 状態を見るだけの手順（`launchctl print "$JOB" | grep …`、`pgrep -fx "$APP/…"` など）は、`just status` で読めるなら `just status` に置き換える。出力を `B` に保存する手順や、`just status` が出さない値を見る手順は、リテラルの直接のコマンドのまま残す。
- 起動と停止は、目的が「このチェックアウトのビルドを起動する／止める」だけの手順なら `just start`、`just stop`、`just restart` に置き換える。ジョブが読み込まれたままの起動、Finder からの起動、`bootout` や `kickstart` そのものなど、起動の経路やジョブの状態が試験の条件になっている手順は置き換えず、直接のコマンドで書く。`just start` はジョブを外すので、試験の条件を変えてしまうためである。
- 4節の表は「変数」列をなくし、パスと役割を残す。
- `verify.sh` への参照をすべて消す。冒頭の「実行するのはオーナーだけ」の段落は、`manual` グループのレシピを挙げる形に直す。
- 試験の目的、期待値、中止条件、復元の意味は変えない。変えないと書き換えられない箇所があれば、変更せずに報告する。
- 手順書は日本語のまま書く。文体は今の手順書に合わせる。

## 完了条件

- `scripts/manual/verify.sh` がなく、リポジトリ内に `verify.sh` への参照がない（`git grep -n 'verify\.sh'` で、`docs/meta/decisions/DEC-SYS-020-*` とこのチェックアウトの外以外に出ない）。
- `docs/manual/verification.md` に `$ROOT`、`$ID`、`$JOB`、`$PLIST`、`$RECORD`、`$APP`、`$HELPER`、`$RULE`、`$DAEMON`（`${…}` の形も含む）が残っていない。`$CLI` は7節と8.5の中にだけある。
- `just --list` に4つのレシピが `manual` グループで並び、justfile が出す文字列に日本語がない。
- `nix develop --command just check` が通る。

## 検証

エージェントは `start`、`stop`、`restart`、`status` を実行しない。`launchctl`、`osascript`、`open`、`pmset` も直接実行しない。代わりに次を行う。

- `nix develop --command just --list`
- `nix develop --command just --dry-run start` などで、各レシピの本体を表示する（実行はされない）。
- 各 shebang レシピの本体を `.build/tmp/` に書き出し、`shellcheck --shell=bash` を通す。
- `git grep -nE '\$\{?(ROOT|ID|JOB|PLIST|RECORD|APP|HELPER|RULE|DAEMON)\b' docs/manual/verification.md` が何も出さないこと。
- `nix develop --command just check`

実機での動作確認はオーナーが行う。

## 実装の報告

### 手順書の置き換え

| 節 | `just` に置き換えた箇所と理由 | 直接のコマンド・画面操作を残した箇所と理由 |
| --- | --- | --- |
| 用語・0節 | 状態確認を `just status` に統一した。通常の入れ替えは `just restart`、起動と停止は `just start`・`just stop` と説明した。0節では起動しない。 | devShell への入り直し、メモした `B` の入力、記録したルートとの一致確認は、退避先を推測せず試験対象を固定するため残した。 |
| 1.1〜1.4 | 既存のビルド入口 `just build` は維持した。 | 環境照会、Release を含むプロセス検索、開始前の出力と終了値の保存、設定・記録の退避、ヘルパー構成とバンドルの検査は、`status` が出さない値や復元材料が要るため残した。変数ブロックは `B` の作成・表示とルートの記録だけにした。 |
| 2.1 | ジョブ・Debug プロセス・パスの確認と異常時の再照会を `just status` にした。 | 初回と終了後の `open`、メニューからの終了は、Finder と同じ経路と読み込み済みジョブでの再起動そのものが試験対象なので残した。`ps` は Release の誤起動、plist 全体の照会は `KeepAlive`・`RunAtLoad` を読むため残した。 |
| 2.2 | プロセス消失、ジョブの読み込み、PID と絶対パス、ログイン後の起動の確認を `just status` にした。 | `bootout`・`bootstrap`・`kickstart`、ログアウト、`RunAtLoad`・`KeepAlive`・`runs`・`last exit code` の照会は試験条件と記録項目なので残した。`PID` 変数はなくし、毎回照合した PID を `ps` と `kill -SEGV` に同じ値で貼る手順にした。空・複数・別アプリへの送信禁止は維持した。 |
| 2.3 | 終了後と再起動後の状態確認を `just status` にした。 | バックグラウンド項目の操作、ジョブを残した `open`、メニューからの終了は、許可状態による登録・起動と警告の試験条件を変えないため残した。 |
| 3.1〜3.3 | 3.1の Capsaicin のアサーション確認を `just status` にした。 | 他アプリの行を数えるためのアサーション全体の照会、`pmset -g custom`、消灯、バッテリー、`ioreg` は `status` が出さない値や試験対象の操作なので直接のコマンドで読む。設定とハードウェアの操作も維持した。 |
| 4.1〜4.3 | 4.2の `SleepDisabled` の確認を `just status` にした。 | ヘルパーの直接呼び出しと終了値、不正引数、システムファイルの所有者・権限・plist、スリープログ、sudoers の退避と復元は固有の試験なので残した。`sudo`・`mv` を含む行の退避先は `${B:?}` にした。 |
| 4.4〜4.6 | 起動前のアプリ終了を `just stop`、`SleepDisabled` の確認を `just status` にした。再ログイン後も起動しない。 | 再起動、Daemon の照会、ヘルパー操作、外部値の設定と復旧、所有記録と構成ファイルの確認は試験条件なので残した。復元時の Finder 起動も維持した。 |
| 4.7・5節 | 4.7の `SleepDisabled` 確認の案内を `just status` にした。 | 輝度と LED の目視、記録の内部値、画面消灯・スクリーンセーバー・ロック、機器とキーの操作は `status` では確かめられないため残した。 |
| 6.1・6.2 | Capsaicin のアサーション、再ログイン後の状態、クラッシュ前のジョブとプロセスの照合を `just status` にした。 | メニュー終了と Finder 起動は終了・再開経路の試験なので残した。記録の保存と内部値、起動時刻、日付、`runs`・`last exit code`、照合済み PID へのクラッシュ送信も固有の記録・試験操作として残した。 |
| 7.1〜7.3 | 置き換えていない。CLI の `status` は試験対象そのものなので維持した。 | 試験対象の CLI 呼び出し、出力・終了値、ソケット、Finder 起動、画面操作は製品の試験なので残した。7.3の `ps` は Debug に加えて Release の誤起動も検出するため残した。`CLI` は7節冒頭で定義し、その節だけで使う。`NO_COLOR=1` は試験対象コマンドだけへの環境指定として維持した。 |
| 8.1〜8.8 | 8.2の終了ボタン試験後の通常起動を `just start`、8.8の通常の終了と再起動を `just stop`・`just start` にした。 | メニュー・設定・HUD・アクセシビリティ・言語・時刻の操作と目視は維持した。Finder 起動と終了ボタンは経路・操作自体を確認するため残した。8.5でだけ使う `CLI` を小節冒頭で定義した。 |
| 9.1〜9.4 | 終了後のプロセス・抑止・Capsaicin のアサーション確認と、ジョブ除去後のプロセス確認を `just status` にした。 | `bootout` 前後の直接照会はサービス不在と他のエラーを区別するため残した。緊急復旧は `BEFORE` 変数をなくし、保存値を `case` で `0`・`1` に検証して同じ値へ戻す。保存、削除、復元、比較、他アプリのアサーションと `runs` の最終照会は復元の意味を保つため残した。`trash` を含む行の退避先も `${B:?}` にした。 |
| 付録 A・B | 付録 A のプロセス切り分けを `just status` にした。 | `bootstrap` の失敗、`print-disabled`、警告後の `open` は経路や追加情報が必要なので残した。付録 B の結果記入例は変更していない。 |

### 検証結果

- `nix develop --command just --list`: `manual` グループの4レシピと英語の説明を確認した。
- `nix develop --command just --dry-run start`・`stop`・`status`・`restart`: すべて成功した。`restart` の表示が生成・ビルド・停止・起動の順であることも確認した。本体は実行していない。
- 各 shebang 本体を `.build/tmp/task099-{start,stop,status}.sh` に書き出し、devShell 内で `shellcheck --shell=bash` を実行した。3本とも成功した。本体は `status` が24行、`stop` が21行、`start` が22行である。
- devShell 内の Python の `assert` で、旧変数の除去、`CLI` の使用範囲、危険操作の `${B:?}`、英語の出力、依存順、全チェックアウトを対象にする Debug プロセスの正規表現、目的の節が変わっていないこと、旧スクリプトと空ディレクトリの除去を検査した。すべて成功した。変更前の文書には旧変数があり、変更前の justfile には `manual` グループがないことも比較した。
- 指定の `git grep -nE` は手順書に一致なしだった。`git grep -n 'verify\.sh'` も追跡ファイルには一致なしだった。開始時から未追跡の本チケットと判断文書は、このコマンドの対象に入らない点に注意する。
- `nix develop --command just check`: 成功した。整形・lint・文書検査、Python 41テスト、SwiftPM の計313テスト、アプリを起動しない140テストが通った。ログは `.build/tmp/task099-check.log` に残した。check 後の変更は手順書と本報告だけであり、devShell 内で実行した `just lint-docs` と `git diff --check` も成功した。
- `start`・`stop`・`restart`・`status` の実行、アプリの起動、実機操作は行っていない。動的な確認はオーナーが行う。

### 判断と範囲外の事項

- `status` は `runs`・`last exit code`、Release プロセス、他アプリのアサーションを出さず、ジョブの不在と照会エラーをまとめて表示するため、それらを記録・区別する直接照会は置き換えていない。
- 起動直後の引き渡しでは同じ実行ファイルのプロセスが複数になりうるため、`start` は検出した実行ファイルのパスを重複排除して照合する。実際の引き渡しと単一起動の判定はオーナーの実機試験で行う。
- 本チケットの指示本文にも削除対象スクリプトの名前が残る。編集許可は「実装の報告」節だけなので指示本文は変更していない。既存の判断文書も変更していない。
- 範囲外のアプリコードに到達不能コードのコンパイラー警告があり、テスト時には AppIntents のメタデータと `com.apple.linkd.autoShortcut` への接続に関する診断も出た。テストは成功しており、今回の範囲では修正していない。

## レビュー

PM が差分を読み、次を直した。

- `start` の成否を、最初に見つかった Debug プロセスではなく、launchd のジョブの `pid` と `program` で判定するようにした。直接起動した個体は引き渡しの後に終わるので、それを見て成功とすると、引き渡しの失敗を見逃すためである。上の報告の「起動直後の引き渡し…重複排除して照合する」は、この変更で当てはまらなくなった。
- Debug プロセスの正規表現が3か所にあったので、justfile の `debug_process` にまとめた。
- 2.2の4、6.2、6.3で、照合した PID を手で貼る形にしていたのを、その場で `launchctl print` から得る小節の中だけの `PID` に戻した。`B` だけを残す方針は、節をまたぐ変数を対象にしたもので、1回の照合とシグナル送信の間だけ使う値まで手で貼らせる理由はない。
- 3.1の2のアサーション確認を `just status` から `pmset -g assertions | grep -i -A2 capsaicin` に戻した。記録では Capsaicin の行を丸ごと写すので、続く行を出さない `just status` では足りない。
- 0節と1.1で `nix develop` の後に `bash` を重ねていたのを外した。`nix develop` は devShell の Bash に入る。

検証: `just --dry-run` で書き出した `start`、`stop`、`status` の本体に `shellcheck --shell=bash` を通した。`nix develop --command just check` を PM が実行した。

実機での `start`、`stop`、`restart`、`status` の動作は、オーナーの確認を待つ。確認できたら、このチケットを `done` にして削除する。
