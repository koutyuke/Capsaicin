# 暗くしたままアプリが終了した後に輝度を戻す

MacBook の「ディスプレイを閉じたとき」を「明るさを0」にして抑止し、暗いままアプリを終了させる。開いた後に輝度のキーで戻せ、手動起動で記録した輝度へ戻るという `HYP-BLK-013` を確かめる。`kill -9` が仮説の対象で、`kill -SEGV` も分けて観測する。接続切断による `off` は `HYP-HLP-008` の確認である。期待は未確認であり、違う結果を期待に寄せて解釈しない。

最初の準備は [`prepare.md`](prepare.md)、最後の片付けは [`cleanup.md`](cleanup.md) で行う。それ以外の検証ファイルには依存しない。所要時間は未実測である。

## 始める前に

- 実行者はオーナーである。ヘルパーの登録、遅延実行によるアプリの強制終了、復旧用の `/usr/bin/sudo /usr/bin/pmset -a disablesleep 0` を承認し、管理者認証を用意する。未保存の作業を保存する。
- 内蔵ディスプレイのある MacBook を使う。外部ディスプレイは外し、電源とキーボードの構成を記録する。画面を開いた後、輝度を上げるキーを操作できることを先に確かめる。
- `prepare.md` の退避と起動前ゲートを終え、開始時の `SleepDisabled` は `0`、アプリは Release・Debug とも停止、既存の登録なしである。LED が点いたまま残ったときは、このファイルの「LED が点いたまま残ったとき」の順で戻す。
- 画面が暗いままでも復旧できるよう、システム設定の「ディスプレイ」の輝度のスライダーを先に開き、操作位置を確認する。macOS の画面名は本手順の執筆時には実画面で未確認なので、実施時に照合する。キーもスライダーも使えない場合は始めない。

文書の worktree で devShell に入り、`B` を入れる。`OK` が出なければ止める。

```sh
cd /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-smappservice
nix develop
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
```

試作 `spike/daemon-cleanup-probe` の `1b42313` をビルドし、オーナーのキーチェーンで署名する。各コマンドの成功を確認する。

```sh
(
  cd /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe &&
  git rev-parse --short HEAD &&
  nix develop --command just build &&
  nix develop --command just sign-debug
)
APP='/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe/.build/xcode/Build/Products/Debug/Capsaicin.app'
printf '%s\n' "$APP" > "$B/app-path.txt"
/usr/bin/codesign -dv --verbose=4 "$APP" 2>&1
/usr/bin/codesign --verify --deep --strict "$APP"
/usr/bin/pmset -g
/usr/bin/pgrep -x Capsaicin
```

コミット `1b42313`、bundle ID `io.github.koutyuke.capsaicin.debug`、`Authority` の先頭が `Developer ID Application:`、Team ID あり、`SleepDisabled 0`、アプリの PID なしを確認する。違えば起動しない。

別のターミナルで起動前からログを記録する。

```sh
B='控えた退避先の絶対パスに置き換える'
/usr/bin/log stream --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' | /usr/bin/tee "$B/log.brightness-crash.stream.txt"
```

操作用ターミナルで起動する。

```sh
/usr/bin/open "$APP"
sleep 5
/usr/bin/pgrep -x Capsaicin
/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
```

アプリは1本だけで、agent はサービスなし、ログは `Agent cleanup after: status=0` であることを確認する。試作は agent を登録せず、クラッシュ後も再起動しない。「一般」の「クラッシュ時に自動再起動できませんでした」は試作の想定どおりである。`Duplicate instance; exiting: other_pid=<pid>` や `Agent cleanup failed: <error>` が出たら止める。

メニューの「設定…」を開き、設定・輝度・ヘルパーの開始値を `"$B/result-brightness-crash-recovery.txt"` に控える。

- 「一般」の「スリープ防止の再開」を「再開しない」、「ログイン時に起動」をオフにする。
- 「LED」の「スリープ防止中にCaps LockのLEDを点灯」はオフにする。このファイルでは輝度を判定し、LED の点灯の残存は判定しない。
- 「スリープ」の「タイマー」「指定時刻」「残量が少なくなったらオフにする」をオフ、「ディスプレイを自動でオフにしない」をオンにする。
- 「ヘルパー」が「未インストール」なら「インストール…」と確認の「インストール」を押す。承認待ちなら「システム設定を開く」から許可して「有効」にする。今回登録したかを控える。
- 「スリープ」の「ディスプレイを閉じたとき」を「明るさを0」にする。明るさを変更できない旨が表示されたら始めない。

システム設定の「一般 > ログイン項目と機能拡張」とバックグラウンドの項目名は実画面で未確認である。実施時に表示名を記録し、BTM の Debug の識別子・アプリのパスと照合する。Release や別アプリと区別できなければ変更しない。

```sh
/usr/bin/sfltool dumpbtm > "$B/btm.brightness-crash.before.txt"
```

## 操作と期待

### 1. 暗くしたまま `SIGKILL` で終了させる

1. 内蔵画面の輝度を、0と区別できる普段の値にし、スライダーの位置を写真に残す。メニューの「スリープ防止をオンにする」を選ぶ。

   ```sh
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /bin/ps -p "$PID" -ww -o pid=,ppid=,comm=
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /usr/bin/pmset -g
   ```

   PID は1つ、実行ファイルは `$APP/Contents/MacOS/Capsaicin`、`SleepDisabled 1`、ログに `Cleanup responsibility acquired: peer_pid=<pid>` があることを確かめる。

2. 次の20秒後の終了を予約し、20秒以内にディスプレイを閉じる。閉じる際に内蔵画面が暗くなることを観察する。30秒たってから開く。予約は1回だけ実行する。

   ```sh
   (
     sleep 20
     /usr/sbin/ioreg -r -k AppleClamshellState > "$B/lid.brightness-kill.txt"
     cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/record.brightness-kill.before.json" &&
     /usr/bin/grep -q '"AppleClamshellState" = Yes' "$B/lid.brightness-kill.txt" &&
     python3 -c 'import json,sys; v=json.load(open(sys.argv[1])).get("savedBrightness"); assert isinstance(v,(int,float)) and v>0, "明るさの退避がない"' "$B/record.brightness-kill.before.json" &&
     test "$(/usr/sbin/lsof -a -p "$PID" -d txt -Fn | /usr/bin/awk '/^n/ {print substr($0,2); exit}')" = "$APP/Contents/MacOS/Capsaicin" &&
     /bin/date '+%Y-%m-%dT%H:%M:%S%z' &&
     /bin/kill -9 "${PID:?}"
     sleep 1
     /usr/bin/pmset -g
     sleep 4
     /usr/bin/pmset -g
   ) > "$B/observation.brightness-kill.txt" 2>&1 &
   CRASH_JOB=$!
   ```

   閉じた状態・輝度の退避・実行ファイルの照合に失敗すると、予約はアプリを終了させない。開いても PID が残る場合は再実行せず中止する。`savedBrightness` は退避の証拠であって、輝度0の実測値ではない。暗くなったことを観察できなかった場合は、暗い状態からの復旧を判定不能にする。

3. 開いた直後、アプリを起動せず、キーを触る前の暗さを記録する。輝度を上げるキーを操作し、普段どおり画面が見えるようになるかを確かめる。戻らなければ失敗として記録し、準備したシステム設定の輝度のスライダーで戻す。戻せなければ後続を止める。

   ```sh
   wait "$CRASH_JOB"
   cat "$B/observation.brightness-kill.txt"
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   /usr/bin/plutil -p "$B/record.brightness-kill.before.json"
   /usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.brightness-kill.txt"
   ```

   仮説の期待: 開いた直後は暗いままだが、輝度のキーで戻せる。アプリは再起動せず、デーモンの `Disconnect cleanup off: success=true` と `Cleanup responsibility released: peer_pid=<pid>` があり、終了から数秒以内に `SleepDisabled 0` になる。暗いままか、キーで戻せるか、`off` の成否を別々に判定する。

4. `SleepDisabled 0` を確認し、輝度を退避した値と見分けられる位置に手動で変えてからアプリを起動する。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/open "$APP"
   sleep 5
   /usr/bin/plutil -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"
   ```

   仮説の期待: 抑止は再開せず、記録した輝度へ戻る。`savedBrightness` がなくなることと、開始時の写真に対応するスライダーの位置・目視を照合する。記録が消えただけで輝度の復元成功にしない。

### 2. 暗くしたまま `SIGSEGV` で終了させる

1. `SleepDisabled 0`、ディスプレイが開いていること、「一般」の「スリープ防止の再開」が「再開しない」であることを確かめる。輝度を普段の値にし、スライダーを写真に残す。メニューの「スリープ防止をオンにする」を選ぶ。

   ```sh
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /bin/ps -p "$PID" -ww -o pid=,ppid=,comm=
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /usr/bin/pmset -g
   ```

   PID が1つで、実行ファイルが `$APP/Contents/MacOS/Capsaicin`、`SleepDisabled 1`、ログが `Cleanup responsibility acquired: peer_pid=<今回のPID>` であることを確認する。

2. 次の予約を1回実行し、20秒以内にディスプレイを閉じる。内蔵画面が暗くなることを観察し、30秒たってから開く。

   ```sh
   (
     sleep 20
     /usr/sbin/ioreg -r -k AppleClamshellState > "$B/lid.brightness-segv.txt"
     cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/record.brightness-segv.before.json" &&
     /usr/bin/grep -q '"AppleClamshellState" = Yes' "$B/lid.brightness-segv.txt" &&
     python3 -c 'import json,sys; v=json.load(open(sys.argv[1])).get("savedBrightness"); assert isinstance(v,(int,float)) and v>0, "明るさの退避がない"' "$B/record.brightness-segv.before.json" &&
     test "$(/usr/sbin/lsof -a -p "$PID" -d txt -Fn | /usr/bin/awk '/^n/ {print substr($0,2); exit}')" = "$APP/Contents/MacOS/Capsaicin" &&
     /bin/date '+%Y-%m-%dT%H:%M:%S%z' &&
     /bin/kill -SEGV "${PID:?}"
     sleep 1
     /usr/bin/pmset -g
     sleep 4
     /usr/bin/pmset -g
   ) > "$B/observation.brightness-segv.txt" 2>&1 &
   CRASH_JOB=$!
   ```

   開いても PID が残る、暗くなったことを観察できない、閉じた状態や退避した輝度を確認できない場合は再実行せず、その制約を記録する。

3. 起動し直さず、開いた直後の暗さ、輝度を上げるキーで戻せるかを観察する。戻らなければ結果を残してシステム設定の輝度のスライダーで戻す。

   ```sh
   wait "$CRASH_JOB"
   cat "$B/observation.brightness-segv.txt"
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   /usr/bin/plutil -p "$B/record.brightness-segv.before.json"
   /usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.brightness-segv.txt"
   ```

   追加観測の期待: 暗いまま開くがキーで戻せ、アプリは再起動しない。`HYP-HLP-008` の期待は、デーモンの `Disconnect cleanup off: success=true`・役目の解放と、終了から数秒以内の `SleepDisabled 0` である。シグナル送信から終了までに遅れがあれば分けて記録する。`SIGKILL` の結果と混ぜない。

4. `SleepDisabled 0` を確認し、輝度を退避値と見分けられる位置に変えてから手動起動する。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/open "$APP"
   sleep 5
   /usr/bin/plutil -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"
   ```

   追加観測の期待: 抑止は再開せず、退避した輝度へ戻り、`savedBrightness` がなくなる。写真と目視も照合する。

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

対象・署名・PID・役目の取得を識別できない、輝度や記録を戻せない、想定外に再起動した場合は止める。予約の待ち時間中に止める場合は、**アプリの PID ではなく待機中のシェルの PID** を確かめて予約を止める。既に終わった PID には送らない。

```sh
/bin/ps -p "$CRASH_JOB" -ww -o pid=,ppid=,command=
```

待機中の予約のシェルだと確認できた場合だけ実行する。

```sh
/bin/kill -TERM "${CRASH_JOB:?}"
```

ディスプレイを開き、キーまたはシステム設定のスライダーで輝度を戻す。動いているアプリでは「スリープ防止をオフにする」を選ぶ。終了後に `SleepDisabled 1` が残った場合は、アプリを起動し直す前に復旧する。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

`0` に戻らなければアプリ・登録・記録を残して PM に渡す。

## 元に戻す

予約が終わり、ディスプレイが開き、輝度が見える状態、`SleepDisabled 0` になったことを確かめて起動する。

```sh
/usr/bin/pmset -g
/usr/bin/open "$APP"
```

抑止中なら「スリープ防止をオフにする」を選ぶ。`SleepDisabled 1` が残る場合だけ次で戻す。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

今回登録したヘルパーを「ヘルパー」の「削除…」と確認の「削除」で「未インストール」に戻す。変更した設定を控えた値へ戻し、「Capsaicinを終了」で終了する。輝度と機器の接続も開始前へ戻す。LED が通常連動しなければ「LED が点いたまま残ったとき」の順で戻す。ログ用ターミナルを Control-C で止め、最後に `cleanup.md` を行う。戻せなければアプリや記録を削除しない。

## 記録

`"$B/result-brightness-crash-recovery.txt"` に次を書く。

- 実行日、MacBook の機種、macOS のビルド番号、電源・キーボード、コミット、署名、`APP`、設定と登録の開始値
- シグナル別の PID・役目の取得、閉じた時刻・暗くなった観察・`AppleClamshellState`・退避した `savedBrightness`
- シグナル送信・終了・`off` の時刻、1秒後・5秒後の `SleepDisabled`、自動再起動の有無
- 開いた直後の暗さ、キーで戻せたか、スライダーでの復旧が必要だったか、手動起動前後の輝度と記録
- 仮説の各項目の当否、成功／失敗／判定不能、中止・未実施の理由、写真・ログの絶対パス、復元結果
