# デーモンが落ちた後に `on` を送り直す

抑止中の Debug デーモンだけを `sudo kill -9` で終了させる。アプリが接続を張り直し、新しいデーモンが `on` を受けて後片付けの役目を持つことを、続けてアプリを強制終了したときの `off` で確かめる（`SPEC-HLP-005`、`SPEC-HLP-002`）。所要時間は未実測である。

```text
[抑止開始] → [デーモンだけ強制終了] → [同じアプリ・新しいデーモン] → [アプリを強制終了し、新しいデーモンの off を観測]
```

## 始める前に

- オーナーが `prepare.md` の起動前ゲートを通し、接続保持と単一インスタンスを含む、Developer ID で署名し直した手元のビルドか署名・公証済みの PR Debug ビルドを `APP` に選んでいる。
- ヘルパーの登録と許可、対象デーモンとアプリの強制終了、復旧時の `sudo pmset` を承認している。管理者認証を用意し、未保存の作業を保存する。

リポジトリのルートで `nix develop` を実行する。devShell の中で退避先と対象を読む。

```sh
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
APP="$(cat "$B/app-path.txt")"
printf 'APP=%s\n' "$APP"
/usr/bin/pmset -g
/usr/bin/pgrep -x Capsaicin
/bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
```

`OK`、準備で選んだ `APP`、`SleepDisabled 0`、アプリの PID なし、デーモンのサービスなしを確かめる。違えば起動しない。

開始前の Debug の設定を退避する。退避に失敗したら起動しない。

```sh
/usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.daemon-restart.before.plist" &&
/usr/bin/plutil -lint "$B/defaults.daemon-restart.before.plist"
```

```sh
/usr/bin/open "$APP"
just status
```

`$APP/Contents/MacOS/Capsaicin` のプロセスだけが動いていることを確かめ、メニューの「設定…」を開く。アイコンが見えない場合は `/usr/bin/open "$APP"` でもう一度開き、「一般」の「メニューバーにアイコンを表示」をオンにする。

- 「一般」の「ログイン時に起動」をオフにする。
- 「スリープ」の「タイマー」「指定時刻」「残量が少なくなったらオフにする」をオフにする。「LED」の「スリープ防止中にCaps LockのLEDを点灯」もオフにする。
- 「ヘルパー」の「状態」が「未インストール」であることを確かめ、「インストール…」と確認の「インストール」を押す。許可待ちなら「システム設定を開く」から「一般 > ログイン項目と機能拡張」を開く。

```sh
/usr/bin/sfltool dumpbtm > "$B/btm.daemon-restart.txt"
```

許可するときは、BTM の記録の Debug の識別子と `APP` のパスを照合し、対象のバックグラウンドの項目だけを変更する。macOS の項目名は検証時の画面で照合し、対象を識別できなければ変更しない。

「状態」が「有効」になってから、「スリープ」の「ディスプレイを閉じたとき」を「オンのまま」にする。MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオンにする。MacBook のディスプレイは閉じない。

## 操作と期待

1. メニューの「スリープ防止をオンにする」を選ぶ。アプリとデーモンを識別する。

   ```sh
   just status
   /usr/bin/pmset -g
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   ```

   `SleepDisabled 1` を確かめる。アプリの PID と開始時刻、ジョブの `pid =` の値を控える。以下の `APP_PID` はアプリの PID、`DAEMON_PID` は最初のデーモンの PID に置き換える。

2. **アプリではなく、識別した Debug デーモンだけを強制終了する。** デーモンの後片付けは走らない。直前にジョブの PID と UID `0`、実行ファイルが `$APP/Contents/Helpers/capsaicin-helper` であることを照合する。

   ```sh
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /bin/ps -p DAEMON_PID -ww -o pid=,uid=,comm=
   /usr/bin/sudo /usr/sbin/lsof -a -p DAEMON_PID -d txt -Fn
   ```

   一致した場合だけ、次を実行する。

   ```sh
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   /usr/bin/sudo /bin/kill -9 DAEMON_PID
   /usr/bin/pmset -g
   ```

3. アプリを操作せず、デーモンが別の PID で起動し、役目のないときのアイドル終了（30 秒）を越えて動くことを確かめる。

   ```sh
   /bin/sleep 5
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /bin/sleep 35
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   just status
   /usr/bin/pmset -g
   ```

   期待: アプリの PID と開始時刻は変わらず、`SleepDisabled 1` である。デーモンは操作2で終了させた PID とは異なり、待つ前後では同じ PID である。新しい PID を控える。この時点では、値が `1` であることだけで `on` の再送を判定しない。

4. `APP_PID` の PID・開始時刻・実行ファイルを照合する。新しいデーモンがまだ動いており、対象のアプリだと確かめた場合だけ、今度はアプリを強制終了する。

   ```sh
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /bin/ps -p APP_PID -ww -o pid=,lstart=,comm=
   /usr/sbin/lsof -a -p APP_PID -d txt -Fn
   ```

   ```sh
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   /bin/kill -9 APP_PID
   /bin/sleep 5
   /usr/bin/pmset -g
   /usr/bin/pmset -g assertions > "$B/assertions.daemon-restart.after.txt"
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/log show --last 10m --style compact --predicate 'process == "capsaicin-helper" AND eventMessage CONTAINS "Helper disconnect cleanup"' > "$B/log.daemon-restart.txt"
   ```

   期待: アプリを開き直す前に `SleepDisabled 0` になり、Capsaicin の PID とアサーションはない。新しいデーモンの PID で `Helper disconnect cleanup succeeded: peer_pid=…` が出る。`peer_pid` と時刻を操作4に照合する。このログは `on` を受けた接続の切断でだけ出るため、新しいデーモンが再送を受けて後片付けした証拠になる。ログが取れなければ再送経路を判定不能とする。

## 中止するとき

PID とパスを照合できない、新しいデーモンが動かない、アプリが途中で終了する、アプリの終了後も `SleepDisabled` が `1` または不明の場合は止める。デーモンを繰り返し終了させない。

```sh
/usr/bin/pmset -g > "$B/pmset.daemon-restart.aborted.txt"
/bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper > "$B/job.daemon-restart.aborted.txt" 2>&1
just status > "$B/status.daemon-restart.aborted.txt"
```

対象アプリが動いていれば「スリープ防止をオフにする」を選び、`/usr/bin/pmset -g` で読む。今回立てた `1` が残っていると確かめた場合だけ、アプリを開き直す前に次で戻す。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

値が不明か `0` に戻らない場合、または別のコピーが動いている場合は、登録と記録を残して PM に渡す。

## 元に戻す

`SleepDisabled 0` を確認する。別のコピーが動いていないことを確かめ、対象アプリが停止していれば開く。

```sh
/usr/bin/pmset -g
/usr/bin/open "$APP"
just status
```

「ヘルパー」で今回登録したものだけを「削除…」と確認の「削除」で外す。「状態」が「未インストール」になったら「Capsaicinを終了」で終了する。

```sh
just status
/usr/bin/pmset -g
/bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
```

`No Debug processes.`、`SleepDisabled 0`、デーモンのサービスなしを確かめる。そろった場合だけ停止したまま設定を戻す。

```sh
/usr/bin/defaults import io.github.koutyuke.capsaicin.debug "$B/defaults.daemon-restart.before.plist"
```

準備で退避した記録とアプリの片付けは最後の `cleanup.md` で行う。抑止や登録が残る場合は、アプリを捨てずに PM に相談する。

## 記録

`"$B/result-daemon-restart-resend.txt"` に、ビルド・署名・環境、アプリと新旧デーモンの PID と実行ファイル、操作時刻、前後の `SleepDisabled`、新しいデーモンによる `off`、ログの絶対パス、成功／失敗／判定不能と復元結果を書く。
