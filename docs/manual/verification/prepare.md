# 準備: 開始前の状態を保存する

ほかの検証ファイルを始める前に、最初の1回だけ行う。開始前の状態を退避先 `B` に保存し、起動前ゲートを通る。ここを通せない環境では、ほかの検証ファイルを実施しない。`SPEC-LCY-006`、`SPEC-LCY-009`、`SPEC-BLK-013`、`SPEC-HLP-005`、`SPEC-SET-002`、`SPEC-LED-001` の確認で既存の環境を失わないようにする。

この手順は、試作の状態記録 `resume-record.json` の退避・復元と、開発機に残った Debug agent の片付けにも使う。試作の記録のキーや agent の plist の確認は、その検証用ビルドに固有のものである。製品の起動と保存する記録は `SPEC-LCY-006` と `SPEC-BLK-013` に従い、試作と製品を混同しない。

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
   /bin/date '+%Y-%m-%dT%H:%M:%S%z' > "$B/date.before.txt"
   /usr/bin/awk '$1 == "SleepDisabled" {print $2}' "$B/pmset.before.txt" > "$B/sleep-disabled.before.txt"
   cat "$B/sleep-disabled.before.txt" "$B/agent-print.exit.txt" "$B/agent.before.txt"
   ```

   期待: `SleepDisabled` は1行の `0` または `1` である。Release・Debug の agent とデーモンの照会は、どれも「サービスが見つからない」旨で失敗する。システム設定の「一般 > ログイン項目と機能拡張」の「ログイン時に開く」とバックグラウンドの一覧、`btm.before.txt` に、使用中の Capsaicin の登録がない。macOS の項目名は実装にないため、検証時の画面で照合して表示名を記録する。

   `SleepDisabled` が欠落・重複・不明、いずれかのジョブが読み込み済み、ログイン時に開く登録がある場合は止める。バックグラウンドの登録を既存のものと区別できない場合も止め、既存の登録は外さない。権限不足を「存在しない」とみなさず、各照会の終了コードと本文の両方で判断する。BTM の `[disabled, allowed, …]` は過去の OS の記録として残ることがあるため、それだけで現在の登録や稼働を判断しない（`EVID-LCY-003`）。

   例外は、オーナー自身の PR Preview または手元のビルドが残した `.debug` の SMAppService の agent だけを片付ける場合である。アプリの PID がなく、`SleepDisabled 0`、Release の登録・Debug デーモン・mainApp の登録なし、旧方式のファイルなしで、BTM の識別子とパスからその agent の持ち主を特定できる場合に限る。オーナーが登録解除を承認したら、起動前ゲートは未通過のまま、操作3の退避と操作4の署名・LED の戻し方の確認まで進め、「残った Debug agent の登録を片付ける」を行う。由来が分からない項目は対象にしない。

   開始値が `1` でも、ここでは下ろさない。その場合、`SleepDisabled = 0` を前提にする検証ファイルは実施しない。

### 3. 設定と試作の状態記録を退避し、旧方式の残留を調べる

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

2. 試作の状態記録を、存在しなかったことも含めて保存する。

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

   手元のビルドを使うファイルでは、代わりに次を実行する。`TASK-115` の試作や残った Debug agent の片付けでは、この通常版のビルドを使わず、後掲の「試作のビルドを選ぶ」のコマンドを実行する。agent、ヘルパー、ログイン時やクラッシュ後の起動を確かめるときは、`just build` の後に `just sign-debug` で署名し直す（`DEC-SYS-026`）。オーナーのキーチェーンに「Developer ID Application」の証明書と鍵が必要である。PR の Debug ビルドが agent の項目を作った Mac では、ad-hoc や「Apple Development」で署名したビルドの agent は起動の制約で止まる（`EVID-LCY-005`）。

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

   bundle ID が `io.github.koutyuke.capsaicin.debug`、実行ファイルが `capsaicin` と `capsaicin-helper` で、署名検査に成功し、最初の `Authority` が `Developer ID Application:` で始まり、`TeamIdentifier` が配布物と同じことを確かめる。agent は `BundleProgram = Contents/MacOS/Capsaicin`、`RunAtLoad = false`、`KeepAlive.Crashed = true`、デーモンは `BundleProgram = Contents/Helpers/capsaicin-helper`、`RunAtLoad = true`、`MachServices` のキーが `io.github.koutyuke.capsaicin.debug.helper` である。PR ビルドの取得元・署名を確かめられない、手元で同じ Team ID の署名を用意できない、既存アプリの上書きが要る場合は止める。

3. 結果用のメモ `"$B/result-prepare.txt"` を作り、実行日、macOS のビルド番号、Mac の機種、承認者を書く。認証情報や全プロセスの環境変数は保存しない。
4. LED が点いたまま残ったときの戻し方を確かめる。オーナーは 2026-11-18 に、次の順で戻すことを承認した。各検証ファイルの「LED が点いたまま残ったとき」に、コマンドとともに書いてある。

   1. アプリを起動する。起動時の処理が、停止中のあるべき状態（`"Auto"`）に合わせる。
   2. 戻らなければ、アプリを終了してから `/usr/bin/hidutil property --matching keyboard --set '{"HIDCapsLockLED":"Auto"}'` で書く。
   3. それでも戻らなければ、Mac を再起動する。

   期待: オーナーがこの順を承認したことを `"$B/result-prepare.txt"` に書いた。

   設定の「LED」の「スリープ防止中にCaps LockのLEDを点灯」をオフにするだけでは、起動時の `"Auto"` 書き込みを防げない。既存の LED 上書きモードを保つ必要がある環境では止める。

### 試作のビルドを選ぶ

`TASK-115` では、通常版や PR ビルドでなく、別 worktree の試作を使う。文書の worktree の devShell にいるまま、次を実行する。各コマンドが成功してから次へ進む。

```sh
(
  cd /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe &&
  git branch --show-current &&
  git rev-parse --short HEAD &&
  HELPER_LABEL_SUFFIX= nix develop --command just build &&
  nix develop --command just sign-debug
)
APP='/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe/.build/xcode/Build/Products/Debug/Capsaicin.app'
printf '%s\n' "$APP" > "$B/app-path.txt"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
/usr/bin/codesign -dv --verbose=4 "$APP" 2>&1
/usr/bin/codesign --verify --deep --strict "$APP"
/usr/bin/plutil -p "$APP/Contents/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist"
/usr/bin/plutil -p "$APP/Contents/Library/LaunchDaemons/io.github.koutyuke.capsaicin.debug.helper.plist"
```

ブランチが `spike/daemon-cleanup-probe`、コミットが `d76d393`、ヘルパーの plist が接尾辞なしの `io.github.koutyuke.capsaicin.debug.helper.plist`、bundle ID が `io.github.koutyuke.capsaicin.debug`、最初の `Authority` が `Developer ID Application:` で始まり、Team ID が配布物と同じであることを確かめる。agent の plist はバンドルに残すが、試作は登録せず、起動時に残った登録を一度だけ unregister する。クラッシュ後の自動再起動はない。「一般」の「クラッシュ時に自動再起動できませんでした」は試作の想定どおりである。

残った agent がなければ、準備ではまだアプリを起動しない。操作4の結果の記録を終えてから、選んだ検証へ進む。試作に `just start`・`just restart` は使わない。これらは agent の起動を待つ通常版向けの手順である。

### 残った Debug agent の登録を片付ける

これは、起動時に agent を unregister する試作を使った、オーナー向けの片付けである。製品のアプリはこの登録解除を行わない（`DEC-LCY-010`）。解除の実測と、BTM の無効な項目が残ることは `EVID-LCY-008` にある。システム設定のスイッチをオフにするだけでは、SMAppService の登録解除にはならない。`~/Library/LaunchAgents` のファイル削除や `sfltool resetbtm` は行わない。

1. この節に進めるのは、操作2の例外の対象だけである。`B` に設定と試作の状態記録の退避、開始前の登録の記録があり、起動できる署名の試作を用意し、操作4の LED の戻し方を記録していることを確認する。アプリを起動するため、通常は「ログイン時に起動」の保存値に応じて mainApp も登録される。今回の一時的な mainApp の登録解除もオーナーが承認する。

   ```sh
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /usr/bin/sfltool dumpbtm > "$B/btm.agent-cleanup.before.txt"
   ```

   アプリの PID がないこと、`SleepDisabled 0`、対象が Debug の既知の agent だけであることを読み直す。抑止・所有・未復旧の制御を含む試作の状態記録があれば起動しない。

2. 別のターミナルで、起動前からログを記録する。

   ```sh
   B='控えた退避先の絶対パスに置き換える'
   /usr/bin/log stream --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' | /usr/bin/tee "$B/log.prepare-agent-cleanup.stream.txt"
   ```

   操作用ターミナルで試作を起動する。

   ```sh
   /usr/bin/open "$APP"
   sleep 5
   /usr/bin/pgrep -x Capsaicin
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" > "$B/agent.cleanup-after.txt" 2>&1
   printf '%s\n' "$?" > "$B/agent.cleanup-after.exit.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.prepare-agent-cleanup.show.txt"
   ```

   `Agent cleanup before: status=<n>` と `Agent cleanup after: status=0`、agent の照会のサービスなしを確認する。`0=notRegistered`、`1=enabled`、`2=requiresApproval`、`3=notFound` である。起動前から `0` なら片付けの対象がなかったと記録する。`Agent cleanup failed: <error>`、`Duplicate instance; exiting: other_pid=<pid>`、照会の権限不足、解除後も `status` が `0` でない場合は止め、手作業の登録解除で回避せず PM に渡す。

3. 抑止は開始しない。メニューの「設定…」から「一般」の「ログイン時に起動」をオフにし、システム設定のログイン時に開く一覧から今回の mainApp が外れたことを確かめる。「Capsaicinを終了」で終了する。macOS の画面名は実画面で照合する。

   ```sh
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   /usr/bin/pmset -g assertions
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /usr/bin/sfltool dumpbtm > "$B/btm.agent-cleanup.after.txt"
   ```

   アプリと今回の登録がなく、`SleepDisabled 0`、Capsaicin のアサーションなし、LED が通常連動であることを確認する。LED が戻らなければ、試作を起動し直し、戻らなければ終了してから `/usr/bin/hidutil property --matching keyboard --set '{"HIDCapsLockLED":"Auto"}'` を実行し、それでも戻らなければ Mac を再起動する。予期せず `SleepDisabled 1` が残った場合は次で戻し、成功に数えず中止する。

   ```sh
   /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
   /usr/bin/pmset -g
   ```

4. アプリが停止し、登録と抑止が片付いている場合だけ、試作の起動で変わった Debug の設定と試作の状態記録を退避時に戻す。既存の退避物が読めなければ変更せず PM に渡す。

   ```sh
   if [ -f "$B/defaults.before.plist" ]; then /usr/bin/defaults import io.github.koutyuke.capsaicin.debug "$B/defaults.before.plist"; fi
   if [ -f "$B/defaults.absent" ]; then /usr/bin/defaults delete io.github.koutyuke.capsaicin.debug; fi
   if [ -f "$B/resume-record.before.json" ]; then cp -p "$B/resume-record.before.json" "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
   if [ -f "$B/record.absent" ] && [ -f "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then trash "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
   if [ -f "$B/resume-record.before.json" ]; then cmp "$B/resume-record.before.json" "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
   /usr/bin/defaults read io.github.koutyuke.capsaicin.debug
   ```

   設定を `B/defaults.before.txt` と照合する。ドメインが元からなかった場合は存在しない旨だけのエラーでよい。試作の状態記録も元からなかった場合は、今回作ったファイルがなくなったことを確認する。登録解除した agent は意図した片付けなので作り直さない。解除前へ戻す必要がある場合は、記録した元の同署名の通常版を起動すると agent が再登録されるが、その操作は PM と相談してから行う。

5. ログ用ターミナルを Control-C で止め、前後の状態と復元結果を `"$B/result-prepare.txt"` に残す。この `B` は片付け前の記録として保管する。**まだほかの検証は始めず、`prepare.md` を新しい退避先で最初から行い、登録なしの起動前ゲートを通す。** この節での登録解除だけをもって仮説を確認済みにしない。

## 中止するとき

残った Debug agent の片付けを始めていなければ、アプリはまだ起動しない。既存の登録とファイルは変えず、`B` を保管する。片付け中に止めた場合は、動いている対象アプリを「Capsaicinを終了」で終了し、今回の mainApp の登録、抑止と LED が残っていないかを読む。解除できない登録は手作業で外さず残す。止めた操作と理由、変更済みの対象を `"$B/result-prepare.txt"` に書いて PM に渡す。今回 `/Applications` に置いたアプリがあれば、その絶対パスも記録し、片付けは `cleanup.md` で行う。

## 元に戻す

通常の準備では既存の登録とデータは変えていない。今回置いたアプリの片付けを含め、最後に `cleanup.md` を行う。残った Debug agent を片付けた場合は、その節の復元と新しい退避先での再準備を終えてから検証へ進む。`B` は片付けを終えるまで残す。

## 記録

`"$B/result-prepare.txt"` に次を書く。

- macOS の版とビルド番号、機種、`xcode-select -p` の出力
- `SleepDisabled` の開始値、4つの `launchctl print` の終了コードと本文、BTM とシステム設定の Capsaicin の項目、`date`
- `defaults` の終了コード、`record.absent`・`defaults.absent` の有無、旧方式の8ファイルの有無。既存データがあった場合は中身の要約（認証情報は写さない）
- PR とコミット、アプリの絶対パス、ビルド番号、bundle ID、署名の Team ID、埋め込んだ実行ファイルと定義、LED の戻し方の承認
- 成功／失敗／判定不能、未実施の操作と理由
