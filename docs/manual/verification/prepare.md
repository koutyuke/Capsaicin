# 準備: 開始前の状態を保存する

ほかの検証ファイルを始める前に、最初の1回だけ行う。開始前の状態を退避先 `B` に保存し、起動前ゲートを通る。ここを通せない環境では、ほかの検証ファイルを実施しない。確かめる仕様と仮説に先立ち、`SPEC-LCY-005`、`SPEC-LCY-007`、`SPEC-HLP-005`、`SPEC-SET-002`、`SPEC-LED-001` の確認で既存の環境を失わないようにする。

操作1〜3で状態を読んで退避し、操作4で検証対象のアプリを用意して起動前の準備を終える。全体の所要時間は未実測である。

## 始める前に

- 実行者はオーナーである。Apple Silicon、macOS 26 以上、Xcode 27.2、flakes が有効な Nix を用意する。`sudo pmset` を使う検証では、その操作の承認と管理者認証も用意する。
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
   /usr/bin/pgrep -x Capsaicin
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
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper > "$B/helper.before.txt" 2>&1
   printf '%s\n' "$?" > "$B/helper-print.exit.txt"
   /bin/launchctl print system/io.github.koutyuke.capsaicin.helper > "$B/release-helper.before.txt" 2>&1
   printf '%s\n' "$?" > "$B/release-helper-print.exit.txt"
   /usr/bin/sfltool dumpbtm > "$B/btm.before.txt"
   /usr/sbin/sysctl kern.boottime > "$B/boottime.before.txt"
   /bin/date '+%Y-%m-%dT%H:%M:%S%z' > "$B/date.before.txt"
   /usr/bin/awk '$1 == "SleepDisabled" {print $2}' "$B/pmset.before.txt" > "$B/sleep-disabled.before.txt"
   cat "$B/sleep-disabled.before.txt" "$B/agent-print.exit.txt" "$B/agent.before.txt"
   ```

   期待: `SleepDisabled` は1行の `0` または `1` である。Release・Debug の agent とデーモンの照会は、どれも「サービスが見つからない」旨で失敗する。システム設定の「一般 > ログイン項目と機能拡張」の「ログイン時に開く」とバックグラウンドの一覧、`btm.before.txt` に、使用中の Capsaicin の登録がない。macOS の項目名は実装にないため、検証時の画面で照合して表示名を記録する。

   `SleepDisabled` が欠落・重複・不明、いずれかのジョブが読み込み済み、ログイン時に開く登録がある場合は止める。バックグラウンドの登録を既存のものと区別できない場合も止め、既存の登録は外さない。権限不足を「存在しない」とみなさず、各照会の終了コードと本文の両方で判断する。BTM の `[disabled, allowed, …]` は過去の OS の記録として残ることがあるため、それだけで現在の登録や稼働を判断しない（`EVID-LCY-003`）。

   開始値が `1` でも、ここでは下ろさない。その場合、`SleepDisabled = 0` を前提にする検証ファイルは実施しない。

### 3. 設定と再開用の記録を退避し、旧方式の残留を調べる

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

2. 再開用の記録を、存在しなかったことも含めて保存する。

   ```sh
   if [ -L "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then
     printf '%s\n' '中止: シンボリックリンクがある'
   else
     if [ -f "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/resume-record.before.json"; else touch "$B/record.absent"; fi
   fi
   ```

3. 既存の記録があれば、次で `session`、`ownsSleepDisabled`、`isRunning`、`misalignments` を読む。抑止・所有・実行中・戻していない制御が残っていたら、そのまま保管して止める。壊れた記録も消さない。

   ```sh
   cat "$B/resume-record.before.json"
   ```

4. v0.1.0 の方式のファイルが残っていないか、Release・Debug 両方の名前を読む。見つかっても、この手順では移動・削除しない。

   ```sh
   /bin/ls -ld /Library/PrivilegedHelperTools/io.github.koutyuke.capsaicin.helper{,.debug}
   /bin/ls -ld /etc/sudoers.d/capsaicin{,_debug}
   /bin/ls -ld /Library/LaunchDaemons/io.github.koutyuke.capsaicin.helper{,.debug}.plist
   /bin/ls -ld "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.plist" "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist"
   ```

   期待: 退避に成功し、旧方式の8ファイルはすべて存在しない。バンドル内の定義とは別の対象である。

   旧方式のファイルが1つでも存在する、アクセスが拒否される、退避に失敗する、既存の記録の意味を判断できない場合は止める。旧方式の片付けはリポジトリの外の専用手順書で済ませてから最初からやり直すか、残っていない別の検証用 Mac を PM と選ぶ。

### 4. アプリと署名を確かめ、起動前の準備を終える

1. 外観、アクセントカラー、アクセシビリティ、VoiceOver、バックグラウンド項目の開始値を画面写真で `B` に保存する。外付け機器の製品名と接続方式も記録する。
2. `/Applications` の PR ビルドを使うファイルでは、オーナーが `S-Preview` 付き PR のコメントから、対象コミットの署名・公証済み Debug ビルドを取得する（`DEC-SYS-023`）。展開して `/Applications/Capsaicin.app` に置く。既存のアプリには上書きしない。

   ```sh
   APP='/Applications/Capsaicin.app'
   printf '%s\n' "$APP" > "$B/app-path.txt"
   /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
   /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist"
   /usr/bin/codesign -dv --verbose=4 "$APP" 2>&1
   /usr/bin/codesign --verify --deep --strict "$APP"
   /bin/ls -l "$APP/Contents/Helpers/"
   /usr/bin/plutil -p "$APP/Contents/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist"
   /usr/bin/plutil -p "$APP/Contents/Library/LaunchDaemons/io.github.koutyuke.capsaicin.debug.helper.plist"
   ```

   期待: bundle ID が `io.github.koutyuke.capsaicin.debug`、埋め込んだ実行ファイルが `capsaicin` と `capsaicin-helper` である。署名検査に成功し、`TeamIdentifier` がある。agent は `BundleProgram = Contents/MacOS/Capsaicin`、`RunAtLoad = false`、`KeepAlive.Crashed = true`、デーモンは `BundleProgram = Contents/Helpers/capsaicin-helper`、`RunAtLoad = true`、`MachServices` のキーが `io.github.koutyuke.capsaicin.debug.helper` である。定義は `project.yml` のビルドフェーズが作る。

   手元のビルドを使うファイルでは、代わりに次を実行する。agent、ヘルパー、ログイン時やクラッシュ後の起動を確かめるときは、`just build` の後に `just sign-debug` で署名し直す（`DEC-SYS-025`）。オーナーのキーチェーンに、配布物と同じ Team ID の「Apple Development」の証明書と鍵が必要である。別の証明書を選ぶ場合は `just sign-debug 'Developer ID Application'` のように名前を渡す。

   `/Applications` の PR Debug ビルドと手元のビルドは bundle ID が同じで、BTM の agent の項目を共有する。手元のビルドを使う前に、PR ビルドをメニューの「Capsaicinを終了」で止める。`just stop` は `/Applications` の PR ビルドを対象にしない。この手順の開始時に動作中のアプリがあった場合は、操作1の条件どおり中止する。

   ```sh
   just build
   just sign-debug
   APP="$PWD/.build/xcode/Build/Products/Debug/Capsaicin.app"
   printf '%s\n' "$APP" > "$B/app-path.txt"
   /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
   /usr/bin/codesign -dv "$APP" 2>&1
   /usr/bin/codesign --verify --strict --deep "$APP"
   /bin/ls -l "$APP/Contents/Helpers/"
   /usr/bin/plutil -p "$APP/Contents/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist"
   /usr/bin/plutil -p "$APP/Contents/Library/LaunchDaemons/io.github.koutyuke.capsaicin.debug.helper.plist"
   ```

   bundle ID が `io.github.koutyuke.capsaicin.debug`、実行ファイルが `capsaicin` と `capsaicin-helper` で、署名検査に成功し、`TeamIdentifier` が配布物と同じことを確かめる。agent は `BundleProgram = Contents/MacOS/Capsaicin`、`RunAtLoad = false`、`KeepAlive.Crashed = true`、デーモンは `BundleProgram = Contents/Helpers/capsaicin-helper`、`RunAtLoad = true`、`MachServices` のキーが `io.github.koutyuke.capsaicin.debug.helper` である。PR ビルドの取得元・署名を確かめられない、手元で同じ Team ID の署名を用意できない、既存アプリの上書きが要る場合は止める。

3. 結果用のメモ `"$B/result-prepare.txt"` を作り、実行日、macOS のビルド番号、Mac の機種、承認者を書く。認証情報や全プロセスの環境変数は保存しない。
4. PM に、独立したプロセスから各対象キーボードへ `"Auto"` を書ける LED の復旧用実行ファイルと、その実行・成功判定の手順を用意してもらう。承認済みの手順を `B` に保管する。

   期待: 独立した LED 復旧手段と実行者が決まっている。

   復旧手段がない場合はここで止め、ほかの検証ファイルを実施しない。リポジトリには独立した復旧 CLI がない。設定の「LED」の「スリープ防止中にCaps LockのLEDを点灯」をオフにするだけでは、起動時の `"Auto"` 書き込みを防げない。既存の LED 上書きモードを保つ必要がある環境でも止める。

## 中止するとき

アプリはまだ起動しない。既存の登録とファイルは変えず、`B` を保管する。止めた操作と理由を `"$B/result-prepare.txt"` に書いて PM に渡す。今回 `/Applications` に置いたアプリがあれば、その絶対パスも記録し、片付けは `cleanup.md` で行う。

## 元に戻す

既存の登録とデータは変えていない。今回置いたアプリの片付けを含め、最後に `cleanup.md` を行う。`B` は片付けを終えるまで残す。

## 記録

`"$B/result-prepare.txt"` に次を書く。

- macOS の版とビルド番号、機種、`xcode-select -p` の出力
- `SleepDisabled` の開始値、4つの `launchctl print` の終了コードと本文、BTM とシステム設定の Capsaicin の項目、`boottime`、`date`
- `defaults` の終了コード、`record.absent`・`defaults.absent` の有無、旧方式の8ファイルの有無。既存データがあった場合は中身の要約（認証情報は写さない）
- PR とコミット、アプリの絶対パス、ビルド番号、bundle ID、署名の Team ID、埋め込んだ実行ファイルと定義、承認済みの LED 復旧手順の置き場所
- 成功／失敗／判定不能、未実施の操作と理由
