# ログイン時の起動とクラッシュ後の再起動

「ログイン時に起動」で mainApp の登録だけが切り替わり、オフでも agent によるクラッシュ後の再起動が働くことを確かめる。確かめる仕様は `SPEC-LCY-001`、`SPEC-LCY-003`、`SPEC-LCY-005` である。Finder からの引き渡し自体は `EVID-HLP-006` で確認済みなので、このファイルではログインとクラッシュの結果を判定する。

最初の1回の準備は [`prepare.md`](prepare.md)、最後の片付けは [`cleanup.md`](cleanup.md) で行う。それ以外の検証ファイルの操作には依存しない。所要時間は未実測である。

## 始める前に

- オーナーが、mainApp と agent の登録、ログアウト、検証対象への `SIGSEGV` の送信を承認している。未保存の作業を保存する。
- `prepare.md` を終え、`B` の絶対パスを控えている。対象は `/Applications` に置いた署名・公証済みの PR Debug ビルド（`S-Preview`）である。ad-hoc 署名の `just build` は使わない。
- ヘルパーと LED を使わず、スリープ防止をオフにする。バックグラウンドの許可は有効で、Release は起動しない。

リポジトリのルートで devShell に入り、退避先とアプリを読み戻す。`OK` が出なければ止める。

```sh
cd <リポジトリのルート>
nix develop
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
APP="$(cat "$B/app-path.txt")"
printf 'APP=%s\n' "$APP"
/usr/bin/open "$APP"
sleep 5
/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
/bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
/usr/bin/pmset -g
```

期待: agent が `state = running` で、`program` が `$APP/Contents/MacOS/Capsaicin`、`pid` が唯一のアプリの PID と一致する。`SleepDisabled = 0` である。「一般」に「バックグラウンド項目が無効です」や「クラッシュ時に自動再起動できませんでした」があれば始めない。

「一般」の「ログイン時に起動」「スリープ防止の再開」「メニューバーにアイコンを表示」、「LED」の「スリープ防止中にCaps LockのLEDを点灯」、「スリープ」の開始値を `"$B/result-login-and-crash-restart.txt"` に控える。「スリープ防止の再開」は「再開しない」、メニューバーのアイコンはオン、LED はオフにする。「ディスプレイを閉じたとき」は「システムスリープ（標準）」、MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオフにする。抑止は開始しない。

システム設定の「一般 > ログイン項目と機能拡張」「ログイン時に開く」と、ログアウト時の「再ログイン時にウインドウを再度開く」は macOS の表示であり、実装にはない。検証時の画面で照合し、表示名を記録する。

## 操作と期待

1. 「一般」の「ログイン時に起動」をオフにし、システム設定の「ログイン時に開く」と BTM の Capsaicin の mainApp の項目を読む。表示名だけでなく、Debug の識別子と `$APP` のパスを照合する。

   ```sh
   /usr/bin/sfltool dumpbtm
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
   ```

   期待: mainApp の有効な登録と「ログイン時に開く」の Capsaicin の項目がなくなる。agent と動作中のアプリは止まらず、PID は変わらない。BTM の過去の無効な記録は、有効な登録と区別する。

2. メニューの「Capsaicinを終了」で終了し、アプリが停止したことを確かめる。agent を手作業で外さない。

   ```sh
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
   ```

   期待: agent は読み込み済みで `pid` がなく、アプリのプロセスもない。

3. Apple メニューからログアウトするときに「再ログイン時にウインドウを再度開く」を外し、ログインし直す。アプリは手で起動せず、ターミナルで次を実行する。

   ```sh
   cd <リポジトリのルート>
   nix develop
   B='控えた退避先の絶対パスに置き換える'
   test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
   APP="$(cat "$B/app-path.txt")"
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
   ```

   期待: agent は読み込み済みだが `pid` はなく、アプリは起動していない。ジョブ自体がサービスなしになる結果は、アプリが起動しないこととは別の異常として止める。

4. アプリを手で起動し、agent の PID と実行ファイルを照合する。

   ```sh
   /usr/bin/open "$APP"
   sleep 5
   PID="$(/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/awk '$1 == "pid" && $2 == "=" {print $3}')"
   printf 'expected=%s\n' "$APP/Contents/MacOS/Capsaicin"
   /bin/ps -p "$PID" -ww -o pid=,comm=
   ```

   PID が1つの数値で、実行ファイルが表示した期待の絶対パスと一致する場合だけ、`SIGSEGV` を1回送る。空・複数・別アプリなら送らない。

   ```sh
   /bin/kill -SEGV "$PID"
   sleep 5
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
   ```

   期待: 別の PID で1つだけ起動し、`program` は同じアプリを指す。スリープ防止はオフのままである。5秒後に起動していなければ、30秒を観測の上限として次の読み取りを1回行い、それでも起動しなければ中止する。シグナルは送り直さない。30秒は手順の中止基準であり、製品の保証時間ではない。

   ```sh
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
   ```

5. 「一般」の「ログイン時に起動」をオンにする。システム設定の「ログイン時に開く」に Capsaicin があり、BTM で Debug の mainApp の登録が有効であることを確かめる。

   ```sh
   /usr/bin/sfltool dumpbtm
   ```

   アプリをメニューから終了せずにログアウトする。「再ログイン時にウインドウを再度開く」を外し、ログインし直して次を実行する。

   ```sh
   cd <リポジトリのルート>
   nix develop
   B='控えた退避先の絶対パスに置き換える'
   test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
   APP="$(cat "$B/app-path.txt")"
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
   /usr/bin/sfltool dumpbtm
   ```

   期待: メニューバーに Capsaicin が出て、agent が `state = running`、`program` が `$APP/Contents/MacOS/Capsaicin` で、ジョブの `pid` と唯一のアプリの PID が一致する。スリープ防止はオフのままである。

## 中止するとき

対象の識別、登録、PID、起動の結果が期待と違えば止める。追加のシグナルを送らない。アプリが動いていればメニューで抑止を解除し、「ログイン時に起動」をオフにして「Capsaicinを終了」を選ぶ。登録と記録は消さず、状態を保存して `cleanup.md` へ進む。

```sh
/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" > "$B/agent.login-aborted.txt" 2>&1
/usr/bin/sfltool dumpbtm > "$B/btm.login-aborted.txt"
/usr/bin/pmset -g
```

## 元に戻す

アプリが停止していれば起動し、控えた設定を戻す。

```sh
/usr/bin/open "$APP"
```

「ログイン時に起動」「スリープ防止の再開」「メニューバーにアイコンを表示」「LED」「スリープ」の値を控えた値へ戻す。最後に `cleanup.md` で mainApp をオフにし、今回のアプリと agent を片付ける。手作業でジョブの定義を変えない。

## 記録

`"$B/result-login-and-crash-restart.txt"` に次を書く。

- PR・コミット・ビルド番号・アプリの絶対パス、mainApp の登録の前後とシステム設定の写真
- オフでの再ログイン前後の agent の状態と PID の有無、ウインドウを再度開くチェックを外したこと
- シグナルを送った PID、起こし直された PID、起動までの時間、`runs`、`last exit code`
- オンでの再ログイン後の agent の `program`・PID とアプリの本数、戻した設定
- 成功／失敗／判定不能、未実施の操作と理由、ログと写真の絶対パス
