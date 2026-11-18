# 準備: 開始前の状態を保存する

ほかの検証ファイルを始める前に、最初の1回だけ行う。開始前の状態を退避先 `B` に保存し、起動前ゲートを通る。ここを通せない環境では、ほかの検証ファイルを実施しない。確かめる仕様と仮説に先立ち、`SPEC-LCY-005`、`SPEC-LCY-007`、`SPEC-HLP-005`、`SPEC-SET-002`、`SPEC-LED-001` の確認で既存の環境を失わないようにする。

操作1〜3は状態を読むだけで、操作4でビルドし、起動前ゲートを通る。全体の所要時間は未実測である。

## 始める前に

- 実行者はオーナーである。Apple Silicon、macOS 26 以上、Xcode 27.2、flakes が有効な Nix、有効な管理者認証を用意する。
- 未保存の作業を保存する。
- `command -v trash` で `trash` が使えることを確かめる。なければ始めず PM に相談する。

## 操作と期待

### 1. 実行者と検証環境を固定する

1. Release と Debug の Capsaicin が両方とも停止している検証用 Mac を使う。既存のアプリが動作中なら終了させず中止する。検証中に Release を起動しない。
2. ターミナルでリポジトリのルートを開き、devShell に入る。以後のコマンドはこのシェルで実行する。

   ```sh
   cd <リポジトリのルート>
   nix develop
   ```

3. 環境を読む。

   ```sh
   /usr/bin/xcode-select -p
   /usr/bin/sw_vers
   /usr/bin/uname -m
   /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
   ```

   期待: Developer ディレクトリが Xcode 内を指し、CPU は `arm64` である。最後の検索でアプリが見つからない。Xcode の選択は変更しない。

### 2. 退避先を作り、読み取り結果を残す

1. 所有者だけが読める退避先を作り、チェックアウトのパスを記録する。

   ```sh
   umask 077
   B="$(/usr/bin/mktemp -d "$HOME/Capsaicin-verification.XXXXXX")"
   printf '%s\n' "$B"
   printf '%s\n' "$PWD" > "$B/repository-path.txt"
   ```

2. 表示した `B` の絶対パスを、別のメモに保存する。各検証ファイルとログアウト・再起動の後は、このパスを `B='…'` で入れ直す。`mktemp` を再実行しない。
3. 開始前の状態を保存する。

   ```sh
   /usr/bin/pmset -g > "$B/pmset.before.txt"
   /usr/bin/pmset -g custom > "$B/pmset-custom.before.txt"
   /usr/bin/pmset -g assertions > "$B/assertions.before.txt"
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" > "$B/agent.before.txt" 2>&1
   printf '%s\n' "$?" > "$B/agent-print.exit.txt"
   /bin/launchctl print-disabled "gui/$(id -u)" > "$B/disabled.before.txt"
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin" > "$B/release-agent.before.txt" 2>&1
   printf '%s\n' "$?" > "$B/release-agent-print.exit.txt"
   /usr/sbin/sysctl kern.boottime > "$B/boottime.before.txt"
   /bin/date '+%Y-%m-%dT%H:%M:%S%z' > "$B/date.before.txt"
   /usr/bin/awk '$1 == "SleepDisabled" {print $2}' "$B/pmset.before.txt" > "$B/sleep-disabled.before.txt"
   cat "$B/sleep-disabled.before.txt" "$B/agent-print.exit.txt" "$B/agent.before.txt"
   ```

   期待: `SleepDisabled` は1行の `0` または `1` である。Debug の LaunchAgent の照会は「サービスが見つからない」旨で失敗する。

   次の場合は止める。`SleepDisabled` が欠落・重複・不明。Debug・Release いずれかの LaunchAgent が読み込み済み（`release-agent.before.txt` と終了コードも読む）。`~/Library/LaunchAgents/io.github.koutyuke.capsaicin.plist` が存在する（ログイン時の同時起動を避けるため）。読み込み済みのジョブは plist だけでは完全に戻せないので、ここで `bootout` しない。権限不足を「存在しない」とみなさない。文言は macOS の版で変わるので、終了コードと本文の両方で判断する。

   開始値が `1` でも、ここでは下ろさない。その場合、`SleepDisabled = 0` を前提にする検証ファイルは実施しない。

### 3. 設定、再開用の記録、未読込の plist を退避する

1. Debug の設定をドメイン全体で保存する。ホットキーの値もこの退避に含まれる。

   ```sh
   /usr/bin/defaults read io.github.koutyuke.capsaicin.debug > "$B/defaults.before.txt" 2> "$B/defaults-read.error.txt"
   printf '%s\n' "$?" > "$B/defaults-read.exit.txt"
   cat "$B/defaults-read.exit.txt" "$B/defaults-read.error.txt"
   ```

   終了コードが `0` なら、次を実行する。

   ```sh
   /usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.before.plist"
   /usr/bin/plutil -lint "$B/defaults.before.plist"
   ```

   ドメインが存在しない旨だけが出た場合は、次を実行する。ほかのエラーなら止める。

   ```sh
   touch "$B/defaults.absent"
   ```

2. 再開用の記録と plist を、存在しなかったことも含めて保存する。

   ```sh
   if [ -L "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ] || [ -L "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist" ]; then
     printf '%s\n' '中止: シンボリックリンクがある'
   else
     if [ -f "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/resume-record.before.json"; else touch "$B/record.absent"; fi
     if [ -f "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist" ]; then cp -p "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist" "$B/agent.before.plist"; else touch "$B/agent.absent"; fi
   fi
   ```

3. 既存の記録があれば、次で `session`、`ownsSleepDisabled`、`isRunning`、`misalignments` を読む。抑止・所有・実行中・戻していない制御が残っていたら、そのまま保管して止める。壊れた記録も消さない。

   ```sh
   cat "$B/resume-record.before.json"
   ```

4. Release・Debug 両方のヘルパー構成を読む。

   ```sh
   /bin/ls -ld /Library/PrivilegedHelperTools/io.github.koutyuke.capsaicin.helper{,.debug}
   /bin/ls -ld /etc/sudoers.d/capsaicin{,_debug}
   /bin/ls -ld /Library/LaunchDaemons/io.github.koutyuke.capsaicin.helper{,.debug}.plist
   ```

   期待: 退避に成功し、ヘルパー構成の6ファイルはすべて存在しない。既存の plist があっても読み込まれておらず、元のファイルを保存できている。

   ヘルパー構成が1つでも存在する、アクセスが拒否される、退避に失敗する、既存の記録の意味を判断できない場合は止める。既存のヘルパーは修復も削除もせず、構成のない別の検証用 Mac を PM と選ぶ。

### 4. ビルドし、起動前ゲートを通る

1. 外観、アクセントカラー、アクセシビリティ、VoiceOver、バックグラウンド項目の開始値を画面写真で `B` に保存する。外付け機器の製品名と接続方式も記録する。
2. ビルドし、bundle ID と埋め込んだ実行ファイルを確かめる。

   ```sh
   just build
   /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' .build/xcode/Build/Products/Debug/Capsaicin.app/Contents/Info.plist
   /bin/ls -l .build/xcode/Build/Products/Debug/Capsaicin.app/Contents/Helpers/
   ```

   期待: bundle ID が `io.github.koutyuke.capsaicin.debug`、埋め込んだ実行ファイルが `capsaicin` と `capsaicin-helper` である。

3. 結果用のメモ `"$B/result-prepare.txt"` を作り、実行日、macOS のビルド番号、Mac の機種、承認者を書く。認証情報や全プロセスの環境変数は保存しない。
4. PM に、独立したプロセスから各対象キーボードへ `"Auto"` を書ける LED の復旧用実行ファイルと、その実行・成功判定の手順を用意してもらう。承認済みの手順を `B` に保管する。

   期待: 独立した LED 復旧手段と実行者が決まっている。

   復旧手段がない場合はここで止め、ほかの検証ファイルを実施しない。リポジトリには独立した復旧 CLI がない。設定の「LED」の「スリープ防止中にCaps LockのLEDを点灯」をオフにするだけでは、起動時の `"Auto"` 書き込みを防げない。既存の LED 上書きモードを保つ必要がある環境でも止める。

## 中止するとき

この手順ではシステムを変えていないので、戻すものはない。`B` を消さずに保管し、止めた操作と理由を `"$B/result-prepare.txt"` に書いて PM に渡す。

## 元に戻す

読み取り、退避先の作成、ビルドだけなので、システムの復元は不要である。`B` は `cleanup.md` を終えるまで残す。

## 記録

`"$B/result-prepare.txt"` に次を書く。

- macOS の版とビルド番号、機種、`xcode-select -p` の出力
- `SleepDisabled` の開始値、2つの `launchctl print` の終了コードと本文、`boottime`、`date`
- `defaults` の終了コード、`record.absent`・`agent.absent`・`defaults.absent` のどれができたか、ヘルパー構成6ファイルの有無。既存データがあった場合は中身の要約（認証情報は写さない）
- bundle ID、埋め込んだ実行ファイル2つ、承認済みの LED 復旧手順の置き場所
- 成功／失敗／判定不能、未実施の操作と理由
