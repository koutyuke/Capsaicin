# デーモンだけを強制終了した後の張り直しと後片付け

抑止中のデーモンだけを `sudo kill -9` で終了させ、アプリが接続を張り直して `on` を送り直し、その後のアプリの強制終了で新しいデーモンが `off` を実行することを確かめる。対象は `HYP-HLP-010` と、最後の切断の `HYP-HLP-008` である。期待は未確認の仮説であり、違う結果を期待に寄せて解釈しない。

最初の準備は [`prepare.md`](prepare.md)、最後の片付けは [`cleanup.md`](cleanup.md) で行う。それ以外の検証ファイルには依存しない。所要時間は未実測である。

## 始める前に

- 実行者はオーナーである。ヘルパーの登録、Debug デーモンだけへの `sudo kill -9`、アプリへの `kill -9`、復旧用の `/usr/bin/sudo /usr/bin/pmset -a disablesleep 0` を承認し、管理者認証を用意する。未保存の作業を保存する。
- `prepare.md` の退避と起動前ゲートを終え、開始時の `SleepDisabled` は `0` である。Release・Debug ともアプリは停止し、既存の登録はない。
- 対象は試作 `spike/daemon-cleanup-probe` の `1b42313` だけである。アプリとデーモンの PID を取り違えない。

文書の worktree で devShell に入り、`B` を入れる。`OK` が出なければ止める。

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
/usr/bin/log stream --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' | /usr/bin/tee "$B/log.daemon-reconnect.stream.txt"
```

操作用ターミナルで起動する。

```sh
/usr/bin/open "$APP"
sleep 5
/usr/bin/pgrep -x Capsaicin
/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
```

アプリは1本だけ、agent はサービスなし、ログは `Agent cleanup after: status=0` であることを確かめる。試作は agent を登録せず、クラッシュ後も再起動しない。「一般」の「クラッシュ時に自動再起動できませんでした」は試作の想定どおりである。`Duplicate instance; exiting: other_pid=<pid>` や `Agent cleanup failed: <error>` が出たら止める。

メニューの「設定…」を開き、設定と登録の開始値を `"$B/result-daemon-reconnect-cleanup.txt"` に控える。

- 「一般」の「スリープ防止の再開」を「再開しない」、「ログイン時に起動」をオフにする。
- 「LED」の「スリープ防止中にCaps LockのLEDを点灯」と、「スリープ」の「タイマー」「指定時刻」「残量が少なくなったらオフにする」をオフにする。
- 「ヘルパー」が「未インストール」なら「インストール…」と確認の「インストール」を押す。承認待ちなら「システム設定を開く」から許可し、「有効」にする。今回登録したかを控える。
- MacBook では「スリープ」の「ディスプレイを閉じたとき」を「オンのまま」、MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオンにする。ディスプレイは閉じない。

システム設定の「一般 > ログイン項目と機能拡張」とバックグラウンドの項目名は、実画面で未確認である。実施時に表示名を記録し、次の BTM の Debug の識別子・`APP` のパスと照合する。Release や別アプリと区別できなければ変更しない。

```sh
/usr/bin/sfltool dumpbtm > "$B/btm.daemon-reconnect.before.txt"
```

## 操作と期待

1. メニューの「スリープ防止をオンにする」を選び、アプリとデーモンを識別する。

   ```sh
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /bin/ps -p "$PID" -ww -o pid=,ppid=,comm=
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   HELPER_PID="$(/bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper | /usr/bin/awk '$1 == "pid" && $2 == "=" {print $3}')"
   /bin/ps -p "$HELPER_PID" -ww -o pid=,uid=,comm=
   /usr/bin/sudo /usr/sbin/lsof -a -p "$HELPER_PID" -d txt -Fn
   /usr/bin/pmset -g
   ```

   アプリの PID は1つで、実行ファイルが `$APP/Contents/MacOS/Capsaicin` である。デーモンの PID も1つで、UID が `0`、実行ファイルが `$APP/Contents/Helpers/capsaicin-helper`、システムのジョブの PID と一致することを確かめる。`SleepDisabled 1` と `Cleanup responsibility acquired: peer_pid=<アプリのPID>` が必要である。PID と実行ファイルを結果に控える。

2. **アプリではなく、識別した Debug デーモンだけを終了させる。** 実行直前に PID とパスを読み直し、一致しなければ実行しない。名前での一括終了はしない。

   ```sh
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /bin/ps -p "$HELPER_PID" -ww -o pid=,uid=,comm=
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   /usr/bin/sudo /bin/kill -9 "${HELPER_PID:?}"
   /usr/bin/pmset -g
   sleep 5
   /bin/ps -p "$PID" -ww -o pid=,comm=
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /usr/bin/pmset -g
   /usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.daemon-reconnect.after-helper.txt"
   ```

   仮説の期待: `SleepDisabled 1` が残り、アプリは同じ PID のままである。アプリのログに `Helper connection event: event=interrupted; daemon_status=<n>`、続いて `Helper reconnect on: success=true` が出る。デーモンは別の PID で動き、`Cleanup responsibility acquired: peer_pid=<アプリのPID>` を記録する。`daemon_status` は実測値を書く（`0=notRegistered`、`1=enabled`、`2=requiresApproval`、`3=notFound`）。

   `Helper reconnect on: success=false`、`Helper reconnect on timed out; connection cancelled`、新しい役目の取得なしは成功にしない。単にデーモンが再起動したことと、`on` で役目が戻ったことを分けて判定する。5秒後の値だけでは途中で `0` にならなかったと証明できないので、直後の読み取りとログの時系列も残す。

3. 新しいデーモンが役目を取得したことを確認してから、アプリだけを終了させる。アプリはまだ起動し直さない。

   ```sh
   /bin/ps -p "$PID" -ww -o pid=,comm=
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   /bin/kill -9 "${PID:?}"
   sleep 1
   /usr/bin/pmset -g
   sleep 4
   /usr/bin/pmset -g
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g assertions
   /usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.daemon-reconnect.after-app.txt"
   ```

   仮説の期待: 新しいデーモンに `Disconnect cleanup off: success=true` と `Cleanup responsibility released: peer_pid=<アプリのPID>` が出て、アプリの終了から数秒以内に `SleepDisabled 0` になる。アプリは再起動せず、Capsaicin のアサーションが消える。どの PID のデーモンが記録したかも照合する。

## 中止するとき

PID や署名を識別できない、役目の取得なし、再接続失敗・タイムアウト、想定外のアプリの終了、`SleepDisabled` の欠落・不明は中止する。デーモンを繰り返し終了させず、状態を保存する。

```sh
/usr/bin/pmset -g > "$B/pmset.daemon-reconnect.aborted.txt"
/usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.daemon-reconnect.aborted.txt"
```

動いているアプリで「スリープ防止をオフにする」を選ぶ。アプリの終了後に `SleepDisabled 1` が残った場合、起動し直す前に次で戻す。起動後の後片付けをデーモンの成功に数えない。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

`0` に戻らなければ登録と記録を残して PM に渡す。

## 元に戻す

`SleepDisabled 0` を確認してアプリを起動し、抑止中ならメニューの「スリープ防止をオフにする」を選ぶ。

```sh
/usr/bin/pmset -g
/usr/bin/open "$APP"
```

`SleepDisabled 1` が残る場合だけ次で戻す。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

今回登録したヘルパーを「ヘルパー」の「削除…」と確認の「削除」で「未インストール」に戻す。変更した設定を控えた値に戻し、「Capsaicinを終了」で終了する。ログ用ターミナルを Control-C で止め、最後に `cleanup.md` を行う。登録や抑止を戻せなければアプリと記録を削除しない。

## 記録

`"$B/result-daemon-reconnect-cleanup.txt"` に次を書く。

- 実行日、機種、macOS のビルド番号、コミット、署名、`APP`、設定と登録の開始値
- アプリの PID、終了前後のデーモンの PID・UID・実行ファイル、各操作の時刻、各 `SleepDisabled`
- `interrupted` とそのときの `daemon_status`、再送の成否とタイムアウトの有無、新しいデーモンによる役目の取得
- アプリ終了後の新しいデーモンの `off`・役目の解放・アサーション、ログの絶対パス
- 仮説の各項目の当否、成功／失敗／判定不能、中止・未実施の理由、復元結果と復旧操作の有無
