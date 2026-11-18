# アプリの強制終了後のスリープ設定と LED

抑止中のアプリを `kill -9` と `kill -SEGV` で終了させ、接続を保つデーモンが `off` を実行できるかを確かめる。対象は `HYP-HLP-008` である。併せて `HYP-LCY-001` の、書き込んだプロセスの終了後も LED の点灯が残るという主張を調べる。期待は未確認の仮説であり、違う結果を期待に寄せて解釈しない。

最初の準備は [`prepare.md`](prepare.md)、最後の片付けは [`cleanup.md`](cleanup.md) で行う。それ以外の検証ファイルには依存しない。所要時間は未実測である。

## 始める前に

- 実行者はオーナーである。ヘルパーの登録、アプリへの `kill -9`・`kill -SEGV`、復旧用の `/usr/bin/sudo /usr/bin/pmset -a disablesleep 0` を承認し、管理者認証を用意する。未保存の作業を保存する。
- `prepare.md` の退避と起動前ゲートを終えている。開始時の `SleepDisabled` は `0`、Release・Debug とも停止、既存の登録なしである。
- LED の確認は内蔵キーボードで行う。点いたまま残ったときは、このファイルの「LED が点いたまま残ったとき」の順で戻す。Caps Lock の入力状態はソフトウェアで変えない。
- 対象は試作 `spike/daemon-cleanup-probe` の `d76d393` である。MacBook ではディスプレイを開いたままにする。

文書の worktree で devShell に入り、退避先を入れる。`OK` が出なければ止める。

```sh
cd /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-smappservice
nix develop
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
```

試作をビルドし、オーナーのキーチェーンで署名する。各コマンドの成功を確認する。

```sh
(
  cd /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe &&
  git rev-parse --short HEAD &&
  HELPER_LABEL_SUFFIX= nix develop --command just build &&
  nix develop --command just sign-debug
)
APP='/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe/.build/xcode/Build/Products/Debug/Capsaicin.app'
printf '%s\n' "$APP" > "$B/app-path.txt"
/usr/bin/codesign -dv --verbose=4 "$APP" 2>&1
/usr/bin/codesign --verify --deep --strict "$APP"
/usr/bin/pmset -g
/usr/bin/pgrep -x Capsaicin
/usr/sbin/ioreg -l | /usr/bin/grep HIDCapsLockLED > "$B/led.crash.before.txt"
```

コミット `d76d393`、ヘルパーの plist `Contents/Library/LaunchDaemons/io.github.koutyuke.capsaicin.debug.helper.plist`（接尾辞なし）、bundle ID `io.github.koutyuke.capsaicin.debug`、`Authority` の先頭が `Developer ID Application:`、Team ID あり、`SleepDisabled 0`、アプリの PID なしを確認する。違えば起動しない。

別のターミナルで起動前からログを記録する。

```sh
B='控えた退避先の絶対パスに置き換える'
/usr/bin/log stream --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' | /usr/bin/tee "$B/log.app-crash.stream.txt"
```

操作用ターミナルで起動する。

```sh
/usr/bin/open "$APP"
sleep 5
/usr/bin/pgrep -x Capsaicin
/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
```

アプリは1本だけで、agent の照会はサービスなしで失敗することを確かめる。ログの `Agent cleanup after: status=0` を確認する。試作は agent を登録せず、クラッシュ後も再起動しない。「一般」の「クラッシュ時に自動再起動できませんでした」は試作の想定どおりである。`Duplicate instance; exiting: other_pid=<pid>` や `Agent cleanup failed: <error>` が出たら止める。

メニューの「設定…」を開き、設定とヘルパーの開始値を `"$B/result-app-crash-daemon-cleanup.txt"` に控える。

- 「一般」の「スリープ防止の再開」を「再開しない」、「ログイン時に起動」をオフにする。
- 「スリープ」の「タイマー」「指定時刻」「残量が少なくなったらオフにする」をオフにする。
- 「LED」の「スリープ防止中にCaps LockのLEDを点灯」をオンにする。開始前の Caps Lock の入力状態を控え、オーナーが手動でオフにして LED の消灯を確かめる。
- 「ヘルパー」が「未インストール」なら「インストール…」と確認の「インストール」を押す。承認待ちなら「システム設定を開く」から許可し、「有効」にする。今回登録したかを控える。
- MacBook では「スリープ」の「ディスプレイを閉じたとき」を「オンのまま」、MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオンにする。

システム設定の「一般 > ログイン項目と機能拡張」とバックグラウンドの項目名は、実画面で未確認である。実施時に表示名を記録し、BTM の Debug の識別子・アプリのパスと照合する。Release や別アプリと区別できなければ変更しない。

```sh
/usr/bin/sfltool dumpbtm > "$B/btm.app-crash.before.txt"
```

## 操作と期待

### 1. `SIGKILL` で終了させる

1. メニューの「スリープ防止をオンにする」を選ぶ。LED が点灯し、`SleepDisabled 1` であることを確かめる。

   ```sh
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /bin/ps -p "$PID" -ww -o pid=,ppid=,comm=
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /usr/bin/pmset -g
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /usr/sbin/ioreg -l | /usr/bin/grep HIDCapsLockLED > "$B/led.crash-kill.active.txt"
   ```

   アプリの PID は1つで、実行ファイルが `$APP/Contents/MacOS/Capsaicin` と一致する。ログの `Cleanup responsibility acquired: peer_pid=<pid>` がその PID を示すことを確かめる。デーモンの PID を控える。役目の取得がなければ終了させない。

2. 35秒間操作せず、30秒の無操作による終了が起きないことを確かめる。

   ```sh
   sleep 35
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /usr/bin/pmset -g
   /bin/ps -p "$PID" -ww -o pid=,comm=
   ```

   仮説の期待: 同じデーモンの PID が動き、`SleepDisabled 1` のままである。この区間にそのデーモンの `Idle exit` がない。再起動して PID が変わっていた場合は成功にしない。

3. 対象の PID とパスを確認してからアプリだけを終了させる。観測が終わるまで起動し直さない。

   ```sh
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   /bin/kill -9 "${PID:?}"
   sleep 1
   /usr/bin/pmset -g
   sleep 4
   /usr/bin/pmset -g
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g assertions
   /usr/sbin/ioreg -l | /usr/bin/grep HIDCapsLockLED > "$B/led.crash-kill.after.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.app-crash-kill.txt"
   ```

   `HYP-HLP-008` の期待: デーモンに `Disconnect cleanup off: success=true` と `Cleanup responsibility released: peer_pid=<pid>` が出て、終了から数秒以内に `SleepDisabled 0` になる。アプリは再起動せず、Capsaicin のアサーションも消える。`Disconnect cleanup off` は、試作では役目を持つ接続の `XPC_ERROR_CONNECTION_INVALID` を受けた経路でだけ出る。単に値が `0` であるだけではこの経路の成功にしない。

4. `HYP-LCY-001` の期待: アプリがいないまま、`HIDCapsLockLED` は `"On"` のままで、LED は点灯し続ける。オーナーが承認済みの手順で Caps Lock を手動操作しても、通常の入力状態への連動には戻らない。読み戻しと目視を別々に記録し、値だけで判定しない。観測後は「LED が点いたまま残ったとき」の順で戻し、どの段階で戻ったかを記録する。1（アプリの起動）で戻った場合は、そのアプリのまま 2 に進む。Caps Lock の入力状態は控えた値へ手動で戻す。

   `SleepDisabled 1` が残る場合は、後続を止め、起動し直す前に復旧する。

   ```sh
   /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
   /usr/bin/pmset -g
   ```

### 2. `SIGSEGV` で終了させる

1. `SleepDisabled 0` と LED の通常連動を確認できた場合だけ進む。アプリが動いていなければ起動する。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/pgrep -x Capsaicin || /usr/bin/open "$APP"
   sleep 5
   /usr/bin/pgrep -x Capsaicin
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   ```

   再開せず停止中であること、「一般」の「スリープ防止の再開」が「再開しない」であることを確かめる。Caps Lock の入力状態は手動でオフにし、LED の消灯を確認する。メニューの「スリープ防止をオンにする」を選ぶ。

   ```sh
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /bin/ps -p "$PID" -ww -o pid=,ppid=,comm=
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /usr/bin/pmset -g
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /usr/sbin/ioreg -l | /usr/bin/grep HIDCapsLockLED > "$B/led.crash-segv.active.txt"
   ```

   アプリは1本でパスが `$APP/Contents/MacOS/Capsaicin`、`SleepDisabled 1`、LED 点灯、`Cleanup responsibility acquired: peer_pid=<今回のPID>` を確認する。前の接続の取得ログを流用しない。

2. デーモンの PID を控えて35秒待つ。

   ```sh
   sleep 35
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /usr/bin/pmset -g
   /bin/ps -p "$PID" -ww -o pid=,comm=
   ```

   仮説の期待: 同じデーモンが動き続け、`SleepDisabled 1` で、この区間にそのデーモンの `Idle exit` がない。

3. 対象のパスを読み直し、アプリだけを終了させる。観測が終わるまで起動し直さない。

   ```sh
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   /bin/kill -SEGV "${PID:?}"
   sleep 1
   /usr/bin/pmset -g
   sleep 4
   /usr/bin/pmset -g
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g assertions
   /usr/sbin/ioreg -l | /usr/bin/grep HIDCapsLockLED > "$B/led.crash-segv.after.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.app-crash-segv.txt"
   ```

   `HYP-HLP-008` の期待: デーモンの `Disconnect cleanup off: success=true` と `Cleanup responsibility released: peer_pid=<今回のPID>`、終了から数秒以内の `SleepDisabled 0`、アプリの不在、Capsaicin のアサーションの消失である。クラッシュレポートの処理で終了が遅れた場合は、シグナル送信と実際の終了を分けて時刻を残す。

4. `HYP-LCY-001` の追加観測として LED の点灯、手動の Caps Lock 操作に連動するか、読み戻した値を記録する。`SIGKILL` の結果とは混ぜない。観測後は「LED が点いたまま残ったとき」の順で戻し、どの段階で戻ったかを記録する。Caps Lock の入力状態を控えた値へ手動で戻す。

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

署名・PID・役目の取得を確認できない、デーモンが35秒以内に終了する、アプリが自動で再起動する、LED の対象を識別できない場合は止める。終了後5秒でも `SleepDisabled 1` なら記録して復旧し、後続へ進まない。

```sh
/usr/bin/pmset -g > "$B/pmset.app-crash.aborted.txt"
/usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.app-crash.aborted.txt"
```

動いているアプリでは「スリープ防止をオフにする」を選ぶ。停止後に `SleepDisabled 1` が残った場合は、アプリを起動し直す前に次で戻す。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

LED は「LED が点いたまま残ったとき」の順で戻す。Mac の再起動でも戻らなければ、アプリ・登録・記録を残して PM に渡す。

## 元に戻す

`SleepDisabled 0` と LED の通常連動を確認してからアプリを起動する。

```sh
/usr/bin/pmset -g
/usr/bin/open "$APP"
```

抑止中ならメニューの「スリープ防止をオフにする」を選ぶ。`SleepDisabled 1` が残る場合だけ次で戻す。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

今回登録したヘルパーは「ヘルパー」の「削除…」と確認の「削除」で「未インストール」に戻す。変更した設定を控えた値へ戻し、「Capsaicinを終了」で終了する。ログ用ターミナルを Control-C で止める。Caps Lock の入力状態は開始前の値へ手動で戻し、LED の通常連動を目で確かめる。最後に `cleanup.md` を行う。復旧できなければアプリと記録を削除しない。

## 記録

`"$B/result-app-crash-daemon-cleanup.txt"` に次を書く。

- 実行日、機種、macOS のビルド番号、内蔵キーボード、コミット、署名、`APP`、設定と登録の開始値
- シグナル別のアプリ・デーモンの PID、役目の取得、35秒の保持と `Idle exit` の有無
- 送信・終了・`off` の時刻、1秒後・5秒後の `SleepDisabled`、役目の解放、再起動とアサーションの有無
- シグナル別の LED の目視、手動操作への連動、`HIDCapsLockLED`、LED が戻った段階（アプリの起動、`hidutil`、Mac の再起動）と目視結果
- 仮説の各項目の当否、成功／失敗／判定不能、中止・未実施の理由、写真・ログの絶対パス、復元結果
