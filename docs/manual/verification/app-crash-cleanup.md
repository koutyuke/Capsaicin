# アプリの強制終了後にデーモンがスリープ禁止を解く

スリープ防止中の Debug アプリだけを `kill -9` で終了させる。デーモンが切断を受けて `off` を実行し、アプリが自動で起動し直されないことを確かめる（`SPEC-HLP-002`、`SPEC-LCY-003`）。記録を取った後、手で開くと停止中で始まることも見る（`SPEC-LCY-006`）。所要時間は未実測である。

```text
[SleepDisabled 0 → 抑止開始 → 1] → [アプリだけ強制終了] → [デーモンの off と 0、アプリ不在] → [手で起動して復元]
```

## 始める前に

- オーナーが `prepare.md` の起動前ゲートを通し、接続保持と単一インスタンスを含む、Developer ID で署名し直した手元のビルドか署名・公証済みの PR Debug ビルドを `APP` に選んでいる。
- ヘルパーの登録・許可、対象アプリの強制終了、復旧時の `sudo pmset` を承認している。未保存の作業は保存する。

リポジトリのルートで `nix develop` を実行する。devShell の中で退避先と対象を読み直す。

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
/usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.app-crash.before.plist" &&
/usr/bin/plutil -lint "$B/defaults.app-crash.before.plist"
```

```sh
/usr/bin/open "$APP"
just status
```

`$APP/Contents/MacOS/Capsaicin` のプロセスだけが動いていることを確かめる。メニューの「設定…」を開く。アイコンが見えない場合は `/usr/bin/open "$APP"` でもう一度開き、「一般」の「メニューバーにアイコンを表示」をオンにする。

- 「一般」の「ログイン時に起動」をオフにする。Debug ビルドでは自動アップデートが無効なので、更新による起動し直しは対象にしない。
- 「スリープ」の「タイマー」「指定時刻」「残量が少なくなったらオフにする」をオフにする。「LED」の「スリープ防止中にCaps LockのLEDを点灯」もオフにする。
- 「ヘルパー」の「状態」が「未インストール」であることを確かめ、「インストール…」と確認の「インストール」を押す。許可待ちなら「システム設定を開く」から「一般 > ログイン項目と機能拡張」を開く。

```sh
/usr/bin/sfltool dumpbtm > "$B/btm.app-crash.txt"
```

許可するときは、BTM の記録の Debug の識別子と `APP` のパスを照合し、対象のバックグラウンドの項目だけを変更する。macOS の項目名は検証時の画面で照合し、対象を識別できなければ変更しない。

「状態」が「有効」になってから、「スリープ」の「ディスプレイを閉じたとき」を「オンのまま」にする。MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオンにする。MacBook のディスプレイは閉じない。

## 操作と期待

1. メニューの「スリープ防止をオンにする」を選ぶ。アプリとデーモンの PID を控える。

   ```sh
   just status
   /usr/bin/pmset -g
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /bin/sleep 35
   /usr/bin/pmset -g
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   ```

   期待: 待つ前後で `SleepDisabled 1` で、デーモンの PID は同じである。35 秒は役目がないデーモンのアイドル終了（30 秒）と区別するための観測時間である。この間はアプリを操作しない。

2. `APP_PID` を控えたアプリの PID に置き換える。強制終了するとアプリ自身の後片付けは走らない。直前に、その PID と実行ファイルを照合する。

   ```sh
   /bin/ps -p APP_PID -ww -o pid=,lstart=,comm=
   /usr/sbin/lsof -a -p APP_PID -d txt -Fn
   ```

   `just status` で控えた PID・開始時刻と `"$APP/Contents/MacOS/Capsaicin"` に一致するときだけ、次を実行する。名前でまとめて終了させない。

   ```sh
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   /bin/kill -9 APP_PID
   ```

3. アプリを開き直さずに、`SleepDisabled` とプロセスを読む。

   ```sh
   /usr/bin/pmset -g | /usr/bin/tee "$B/pmset.app-crash.after.txt"
   /usr/bin/pgrep -x Capsaicin
   /bin/sleep 5
   /usr/bin/pmset -g
   /usr/bin/pmset -g assertions > "$B/assertions.app-crash.after.txt"
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/log show --last 10m --style compact --predicate 'process == "capsaicin-helper" AND eventMessage CONTAINS "Helper disconnect cleanup"' > "$B/log.app-crash.txt"
   ```

   期待: 数秒以内に `SleepDisabled 0` になり、Capsaicin の PID とアサーションはない。ログには `Helper disconnect cleanup succeeded: peer_pid=…` があり、記録したデーモンの PID、終了させたアプリの PID、終了時刻に対応する。値が `0` でも、ログがなければ切断による `off` は判定不能とする。

4. 観測を終え、`SleepDisabled 0` のときだけ手で開く。

   ```sh
   /usr/bin/open "$APP"
   just status
   ```

   期待: 選んだアプリが1本だけ動き、メニューには「スリープ防止をオンにする」が出る。`SleepDisabled` とアサーションは戻らない（抑止は再開しない）。

## 中止するとき

PID やパスを照合できない、35 秒の間にデーモンが入れ替わる、アプリが自動で戻る、5 秒後も `SleepDisabled` が `1` または不明の場合は止める。終了操作は繰り返さない。値、PID と照会結果を保存する。

```sh
/usr/bin/pmset -g > "$B/pmset.app-crash.aborted.txt"
just status > "$B/status.app-crash.aborted.txt"
```

対象アプリが動いていれば「スリープ防止をオフにする」を選び、`/usr/bin/pmset -g` で読む。今回立てた `1` が残っていると確かめた場合だけ、アプリを開き直す前に次で戻す。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

値が不明か `0` に戻らない場合、または別のコピーが動いている場合は、登録と記録を残して PM に渡す。

## 元に戻す

`SleepDisabled 0` で、対象以外のプロセスがない場合に復元する。対象アプリが停止していれば開く。

```sh
/usr/bin/open "$APP"
just status
```

「ヘルパー」で今回登録したものだけを「削除…」と確認の「削除」で外す。「状態」が「未インストール」になったら「Capsaicinを終了」で終了する。

```sh
just status
/usr/bin/pmset -g
/usr/bin/pmset -g assertions
/bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
```

`No Debug processes.`、`SleepDisabled 0`、Capsaicin のアサーションなし、デーモンのサービスなしを確かめる。そろった場合だけ停止したまま設定を戻す。

```sh
/usr/bin/defaults import io.github.koutyuke.capsaicin.debug "$B/defaults.app-crash.before.plist"
```

準備で退避した記録とアプリの片付けは最後の `cleanup.md` で行う。抑止や登録が残る場合は、アプリを捨てずに PM に相談する。

## 記録

`"$B/result-app-crash-cleanup.txt"` に、ビルド・署名・環境、アプリとデーモンの PID、送信時刻、`SleepDisabled`、切断後の `off` とアサーション、自動・手動起動の結果、ログの絶対パス、成功／失敗／判定不能と復元結果を書く。
