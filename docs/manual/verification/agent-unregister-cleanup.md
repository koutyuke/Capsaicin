# 試作の起動時に Debug agent の登録だけを外す

`feature/smappservice` のアプリが作った Debug agent を、同じ bundle ID と agent の plist を持つ試作のアプリが起動時に unregister することを確かめる。対象は `HYP-LCY-009` である。agent の状態が `notRegistered` となり、ジョブがなくなっても、デーモンの登録とバックグラウンドのスイッチが変わらないという主張を調べる。期待は未確認であり、違う結果を期待に寄せて解釈しない。

最初の準備は [`prepare.md`](prepare.md)、最後の片付けは [`cleanup.md`](cleanup.md) で行う。それ以外の検証ファイルには依存しない。所要時間は未実測である。

## 始める前に

- 実行者はオーナーである。確認用の Debug agent とヘルパーの登録・登録解除、復旧用の `/usr/bin/sudo /usr/bin/pmset -a disablesleep 0` を承認し、管理者認証を用意する。
- `prepare.md` の退避と起動前ゲートを終え、開始時の `SleepDisabled` は `0`、Release・Debug とも停止、既存の登録なしである。このファイル内で確認用の登録を作る。使用中の登録を流用しない。
- 通常版は文書の worktree の `feature/smappservice`、試作は別 worktree の `spike/daemon-cleanup-probe`、コミット `d76d393` である。どちらもオーナーのキーチェーンの同じ Team ID の Developer ID で署名する。

文書の worktree で devShell に入り、`B` を入れる。`OK` が出なければ止める。

```sh
cd /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-smappservice
nix develop
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
git branch --show-current
git rev-parse HEAD
nix develop --command just build
nix develop --command just sign-debug
OLD_APP="$PWD/.build/xcode/Build/Products/Debug/Capsaicin.app"
/usr/bin/codesign -dv --verbose=4 "$OLD_APP" 2>&1
/usr/bin/codesign --verify --deep --strict "$OLD_APP"
```

ブランチが `feature/smappservice` で、各コマンドが成功したことを確認する。試作も用意する。

```sh
(
  cd /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe &&
  git rev-parse --short HEAD &&
  HELPER_LABEL_SUFFIX= nix develop --command just build &&
  nix develop --command just sign-debug
)
APP='/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe/.build/xcode/Build/Products/Debug/Capsaicin.app'
printf '%s\n' "$APP" > "$B/app-path.txt"
printf '%s\n' "$OLD_APP" > "$B/agent-unregister.old-app-path.txt"
/usr/bin/codesign -dv --verbose=4 "$APP" 2>&1
/usr/bin/codesign --verify --deep --strict "$APP"
/usr/bin/plutil -p "$APP/Contents/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist"
/usr/bin/pmset -g
/usr/bin/pgrep -x Capsaicin
```

試作のコミットが `d76d393`、ヘルパーの plist が接尾辞なしの `io.github.koutyuke.capsaicin.debug.helper.plist`、両アプリの bundle ID が `io.github.koutyuke.capsaicin.debug`、最初の `Authority` が `Developer ID Application:` で始まり、同じ Team ID であることを確認する。試作には agent の plist が残っている。`SleepDisabled 0`、アプリの PID なしである。違えば起動しない。

## 操作と期待

1. 通常版を起動し、確認用の agent とデーモンを作る。抑止は開始しない。

   ```sh
   /usr/bin/open "$OLD_APP"
   sleep 5
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /usr/bin/pgrep -x Capsaicin
   ```

   agent のジョブが動き、アプリは1本で、PID の実行ファイルが `$OLD_APP/Contents/MacOS/Capsaicin` と一致することを確認する。

   ```sh
   OLD_PID="$(/usr/bin/pgrep -x Capsaicin)"
   /usr/sbin/lsof -a -p "$OLD_PID" -d txt -Fn
   ```

   メニューの「設定…」を開き、設定と登録の開始値を `"$B/result-agent-unregister-cleanup.txt"` に控える。「一般」の「スリープ防止の再開」を「再開しない」、「ログイン時に起動」をオフにする。「LED」の「スリープ防止中にCaps LockのLEDを点灯」をオフにし、MacBook では「スリープ」の「ディスプレイを閉じたとき」を「システムスリープ（標準）」、MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオフにする。

   「ヘルパー」が「未インストール」なら「インストール…」と確認の「インストール」を押す。承認待ちなら「システム設定を開く」から許可し、「有効」にする。今回作ったデーモンの登録を結果に控える。

   ```sh
   /usr/bin/pmset -g
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper > "$B/helper.agent-unregister.before.txt" 2>&1
   /usr/bin/sfltool dumpbtm > "$B/btm.agent-unregister.before.txt"
   ```

   システム設定の「一般 > ログイン項目と機能拡張」とバックグラウンドの項目名は、実画面で未確認である。実施時に表示名を記録し、BTM の Debug の識別子・パスと照合する。agent とデーモンがまとまった Capsaicin の項目のスイッチがオンであることを写真に残す。区別できなければ変更しない。

2. 通常版をメニューの「Capsaicinを終了」で止める。agent の登録は手動で外さない。

   ```sh
   sleep 5
   /usr/bin/pgrep -x Capsaicin
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" > "$B/agent.unregister-before.txt" 2>&1
   printf '%s\n' "$?" > "$B/agent.unregister-before.exit.txt"
   /usr/bin/pmset -g
   ```

   アプリの PID がなく、agent の照会は成功するが動いていないこと、`SleepDisabled 0` を確認する。通常版が動いたままだと試作は重複として終了するため、その状態では試作を開かない。

3. 別のターミナルで、試作の起動前からログを記録する。

   ```sh
   B='控えた退避先の絶対パスに置き換える'
   /usr/bin/log stream --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' | /usr/bin/tee "$B/log.agent-unregister.stream.txt"
   ```

   操作用ターミナルで、試作を直接起動する。agent を前提にする `just start`・`just restart` は使わない。

   ```sh
   /usr/bin/open "$APP"
   sleep 5
   /usr/bin/pgrep -x Capsaicin
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" > "$B/agent.unregister-after.txt" 2>&1
   printf '%s\n' "$?" > "$B/agent.unregister-after.exit.txt"
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper > "$B/helper.agent-unregister.after.txt" 2>&1
   /usr/bin/sfltool dumpbtm > "$B/btm.agent-unregister.after.txt"
   /usr/bin/pmset -g
   /usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.agent-unregister.show.txt"
   ```

   仮説の期待: ログの `Agent cleanup before: status=1` から `Agent cleanup after: status=0` へ変わる。`0=notRegistered`、`1=enabled`、`2=requiresApproval`、`3=notFound` である。agent の照会はサービスなしで失敗し、デーモンの登録は残り、アプリの「ヘルパー」の「状態」は「有効」のまま、バックグラウンドのスイッチもオンのままである。デーモンが30秒の無操作で終了して PID がなくなることと、登録の解除は区別する。

   起動前から `status=0` なら unregister の検証は判定不能である。権限不足による照会失敗もサービスなしに数えない。`Agent cleanup failed: <error>`、別の `status`、スイッチの変化があれば実測のまま残す。BTM の過去の agent の記録が残ることと、現行の登録・ジョブの有無を混ぜない。

4. 試作のアプリが1本だけで、実行ファイルが試作のパスであることを確認する。

   ```sh
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   ```

   試作は agent を登録せずクラッシュ後も再起動しない。「一般」に「クラッシュ時に自動再起動できませんでした」が出るのは試作の想定どおりである。`Duplicate instance; exiting: other_pid=<pid>` が出たら unregister の成功として扱わない。

## LED が点いたまま残ったとき

Caps Lock の LED が、Caps Lock の入力状態に連動せず点いたままなら、次の順に戻す（オーナーが 2026-11-18 に承認した順）。どの段階で戻ったかを記録に書く。値の読み戻しだけで判断せず、Caps Lock を手で押して LED が連動するかを目で確かめる。

1. `SleepDisabled 1` が残っていれば先に戻してから、アプリを起動する。起動時の処理が、停止中のあるべき状態（`"Auto"`）に合わせる。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
   /usr/bin/pgrep -x Capsaicin || /usr/bin/open "$APP"
   sleep 5
   /usr/bin/hidutil property --matching keyboard --get HIDCapsLockLED
   ```

   `sudo` の行は、`SleepDisabled 1` のときだけ実行する。

2. 戻らなければ、メニューの「Capsaicinを終了」で終了してから、OS 標準の `hidutil` で `"Auto"` を書く。

   ```sh
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/hidutil property --matching keyboard --set '{"HIDCapsLockLED":"Auto"}'
   /usr/bin/hidutil property --matching keyboard --get HIDCapsLockLED
   ```

3. それでも戻らなければ、Mac を再起動する。

## 中止するとき

対象・署名・PID を識別できない、通常版を終了できない、登録の前提が作れない、unregister に失敗した、デーモンやスイッチも変わった場合は後続を止める。登録を繰り返したり、手作業の `bootout` や BTM のリセットで成功に寄せたりしない。

```sh
/usr/bin/pmset -g > "$B/pmset.agent-unregister.aborted.txt"
/usr/bin/sfltool dumpbtm > "$B/btm.agent-unregister.aborted.txt"
/usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.agent-unregister.aborted.txt"
```

抑止は開始しない。予期せず `SleepDisabled 1` が残った場合は、アプリを起動し直す前に次で戻す。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

`0` に戻らない、登録を外せない場合はアプリと記録を残して PM に渡す。

## 元に戻す

開始時に登録はなく、確認用に作った agent は解除後のままにする。デーモンは、動いている対象アプリの「ヘルパー」で「削除…」と確認の「削除」を押し、「未インストール」へ戻す。抑止中なら先に「スリープ防止をオフにする」を選ぶ。

```sh
/usr/bin/pmset -g
/usr/bin/pmset -g assertions
```

`SleepDisabled 1` が残る場合だけ、次で戻す。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

設定を控えた値へ戻し、「Capsaicinを終了」で終了する。ログ用ターミナルを Control-C で止める。LED が通常連動しなければ「LED が点いたまま残ったとき」の順で戻す。最後に `cleanup.md` を行い、`"$B/agent-unregister.old-app-path.txt"` に残した今回の通常版のビルドも、同手順で今回のアプリと識別して片付ける。

登録解除前の状態を再現する必要が生じた場合、通常版を起動すると agent が再登録される。これは開始前への復元ではなく、確認用の登録を作り直す追加操作である。PM と対象を確認するまで行わない。

## 記録

`"$B/result-agent-unregister-cleanup.txt"` に次を書く。

- 実行日、機種、macOS のビルド番号、両ブランチ・コミット・署名・アプリの絶対パス、今回作った登録
- 通常版の停止、試作の PID とパス、unregister 前後の `status` とエラーの有無、agent の照会の本文と終了コード
- デーモンの登録とアプリの状態、バックグラウンドのスイッチの前後、BTM と実画面の名前・識別子・パス
- 仮説の各項目の当否、成功／失敗／判定不能、中止・未実施の理由、写真・ログの絶対パス、復元結果
