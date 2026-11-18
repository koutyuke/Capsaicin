# スリープ防止中にバックグラウンドの項目をオフにする

試作のアプリで抑止中にバックグラウンドの許可を外し、デーモンが `SIGTERM` で `off` を実行すること、アプリが終了せず切断時の承認待ちを記録することを確かめる。対象は `HYP-HLP-009` である。期待は未確認の仮説であり、違う結果を期待に寄せて解釈しない。

最初の準備は [`prepare.md`](prepare.md)、最後の片付けは [`cleanup.md`](cleanup.md) で行う。それ以外の検証ファイルには依存しない。所要時間は未実測である。

## 始める前に

- 実行者はオーナーである。ヘルパーの登録、バックグラウンドの許可の変更、復旧用の `/usr/bin/sudo /usr/bin/pmset -a disablesleep 0` を承認し、管理者認証を用意する。未保存の作業を保存する。
- `prepare.md` の退避と起動前ゲートを終えている。開始時の `SleepDisabled` は `0` で、Release・Debug ともアプリは停止している。既存の登録があれば先に準備で片付ける。
- 対象は `spike/daemon-cleanup-probe`、コミット `1b42313` だけである。PR ビルドや通常の `feature/smappservice` のアプリを混ぜない。

文書の worktree で devShell に入り、`B` を入れる。`OK` が出なければ止める。

```sh
cd /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-smappservice
nix develop
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
```

試作の worktree でビルドし、オーナーのキーチェーンの Developer ID で署名する。各コマンドが成功してから次へ進む。

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

コミットが `1b42313`、bundle ID が `io.github.koutyuke.capsaicin.debug`、最初の `Authority` が `Developer ID Application:` で始まり、Team ID があることを確かめる。`SleepDisabled 0` で、アプリの PID がないことを確かめる。違えば起動しない。

別のターミナルで、起動前からログを流す。表示を保存できるよう、このターミナルにも同じ `B` を入れる。終わるまで開いたままにする。

```sh
B='控えた退避先の絶対パスに置き換える'
/usr/bin/log stream --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' | /usr/bin/tee "$B/log.background-off.stream.txt"
```

操作用ターミナルで起動する。

```sh
/usr/bin/open "$APP"
sleep 5
/usr/bin/pgrep -x Capsaicin
/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
```

アプリは1本だけで、agent の照会はサービスなしで失敗することを確かめる。ログの `Agent cleanup after: status=0` を確認する。試作は agent を登録せず、クラッシュ後も再起動しない。「一般」に「クラッシュ時に自動再起動できませんでした」が出るのは試作の想定どおりである。`Duplicate instance; exiting: other_pid=<pid>` や `Agent cleanup failed: <error>` が出たら止める。

メニューの「設定…」を開く。設定の開始値とヘルパーの状態を `"$B/result-background-off-while-blocking.txt"` に控え、次の状態にする。

- 「一般」の「スリープ防止の再開」は「再開しない」、「ログイン時に起動」はオフ。
- 「LED」の「スリープ防止中にCaps LockのLEDを点灯」はオフ。
- 「スリープ」の「タイマー」「指定時刻」「残量が少なくなったらオフにする」はオフ。
- 「ヘルパー」が「未インストール」なら「インストール…」と確認の「インストール」を押す。「システム設定での許可待ち」なら「システム設定を開く」から許可し、「有効」にする。今回登録したかを控える。
- MacBook では「スリープ」の「ディスプレイを閉じたとき」を「オンのまま」、MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオンにする。ディスプレイは閉じない。

システム設定の「一般 > ログイン項目と機能拡張」とバックグラウンドの一覧の名前は、この手順では実画面で未確認である。実施時に表示名を記録する。次の BTM の Debug の識別子とアプリのパスを画面と照合し、Release や別アプリと区別できなければ変更しない。

```sh
/usr/bin/sfltool dumpbtm > "$B/btm.background-before.txt"
/bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
```

## 操作と期待

1. メニューの「スリープ防止をオンにする」を選び、状態を読む。

   ```sh
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /bin/ps -p "$PID" -ww -o pid=,ppid=,comm=
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /usr/bin/pmset -g
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   ```

   PID が1つで、実行ファイルが `$APP/Contents/MacOS/Capsaicin`、`SleepDisabled 1` であることを確かめる。ログに `Cleanup responsibility acquired: peer_pid=<pid>` があり、`peer_pid` がアプリの PID と一致することを確かめる。これがなければ許可を外さない。

2. システム設定で識別した Capsaicin のバックグラウンドの項目だけをオフにする。アプリは起動し直さず、切り替えた時刻と直後のログを記録する。

   ```sh
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   sleep 5
   /bin/ps -p "$PID" -ww -o pid=,ppid=,comm=
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /usr/bin/sfltool dumpbtm > "$B/btm.background-after.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.background-off.show.txt"
   ```

   仮説の期待: デーモンに `SIGTERM cleanup off: success=true` が出て、`SleepDisabled 0` になる。アプリは同じ PID のまま動いている。アプリに `Helper connection event: event=<interrupted|invalid>; daemon_status=2` が出る。`2` は `requiresApproval` である（`0=notRegistered`、`1=enabled`、`3=notFound`）。イベント名も実測のまま残す。

   切断時の状態が `1` で、後から画面が承認待ちになった場合も「切断時に `2`」の成功にはしない。`SIGTERM` のログがなく `SleepDisabled` だけが `0` になった場合は、`SIGTERM` で戻したとは判定しない。

3. アプリの「ヘルパー」の「状態」、メニューの抑止の表示、警告を写真に残す。画面を開いた後の状態と、切断時のログを分けて記録する。試作には、切断を受けて抑止を解除し HUD で知らせる完成版の動作は求めない。

## 中止するとき

PID・対象の項目・署名を識別できない、`on` の役目の取得を確認できない場合は許可を外さない。オフにした後にアプリが終了した、5秒後も `SleepDisabled 1`、ログが欠けた場合は後続を止める。許可を何度も切り替えて結果を補わない。

```sh
/usr/bin/pmset -g > "$B/pmset.background-aborted.txt"
/usr/bin/log show --last 10m --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' > "$B/log.background-aborted.txt"
```

`SleepDisabled 1` が残った場合は、アプリを起動し直す前に承認済みの復旧操作を行う。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

`0` に戻らなければ、登録と記録を残して PM に渡す。

## 元に戻す

1. 変更したバックグラウンドの項目だけをオンに戻す。アプリが停止していれば、`SleepDisabled 0` を確認してから起動する。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/open "$APP"
   ```

2. メニューに「スリープ防止をオフにする」があれば選ぶ。ヘルパーが「有効」に戻ったことを確かめる。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/pmset -g assertions
   ```

   `SleepDisabled 1` が残る場合だけ、次で戻す。設定変更は成功しても何も出力しないので、読み戻して判断する。

   ```sh
   /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
   /usr/bin/pmset -g
   ```

3. 今回登録したヘルパーは「ヘルパー」の「削除…」と確認の「削除」で「未インストール」に戻す。変更した設定を控えた値へ戻し、「Capsaicinを終了」で終了する。ログ用ターミナルを Control-C で止め、最後に `cleanup.md` で設定・記録を復元する。許可・抑止・LED を戻せなければ、アプリや記録を削除しない。

## 記録

`"$B/result-background-off-while-blocking.txt"` に次を書く。

- 実行日、macOS のビルド番号、機種、コミット、署名、`APP`、変更した設定と登録
- 許可を変更した項目の実画面の名前・識別子・パス、変更前後のスイッチ
- 操作前後のアプリとデーモンの PID、`SleepDisabled`、役目の取得、`SIGTERM` の `off` の成否、切断時のイベント名と `daemon_status`、各時刻
- アプリが終了しなかったか、画面の状態、写真・ログの絶対パス。ログがなければその旨
- 仮説の3項目それぞれの当否、成功／失敗／判定不能、中止・未実施の理由、復元結果と復旧操作の有無
