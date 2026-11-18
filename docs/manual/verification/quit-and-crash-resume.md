# 利用者の終了とクラッシュの区別、再開

メニューからの終了ではスリープ防止を再開せず、クラッシュの後は「スリープ防止の再開」の設定に従って元の期限のまま再開することを確かめる。確かめる仕様は `SPEC-LCY-002`、`SPEC-LCY-004`、`SPEC-LCY-006`、`SPEC-LCY-007` である。

この手順はこのファイルだけで完結する。最初の1回の準備（[`prepare.md`](prepare.md)）を除き、ほかの検証ファイルの手順は行わない。共通の決まりは [`README.md`](README.md) にある。

再開用の記録 `$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json` は読むだけで、手で編集しない。判定に使うキーは `session`、`ownsSleepDisabled`、`isRunning`、`exitReason`、`misalignments`、`lastUpdated`、`crashLaunches` である。

## 始める前に

- 準備（`prepare.md`）を終え、退避先 `B` の絶対パスを控えている。
- LED とヘルパーを使わず、自動スリープだけを止める。

リポジトリのルートで devShell に入る。

```sh
cd <リポジトリのルート>
nix develop
```

devShell の中で退避先を入れ、足場を確かめる。`OK` が出なければ、退避先かチェックアウトが違うので止める。

```sh
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
just status
```

アプリが動いていなければ起動し、メニューでスリープ防止がオフであることを確かめる。

```sh
just start
just status
```

設定の次の値を `"$B/result-quit-and-crash-resume.txt"` に控えてから変える。

- 「LED」の「スリープ防止中にCaps LockのLEDを点灯」をオフにする。
- 「スリープ」の「ディスプレイを閉じたとき」を「システムスリープ（標準）」にする（MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオフ）。「残量が少なくなったらオフにする」と「指定時刻」をオフにする。
- 「一般」の「スリープ防止の再開」の値を控える。

## 操作と期待

1. 「スリープ防止の再開」を「クラッシュおよびMacの再起動後」にする。「タイマー」をオンにして「継続時間」を10分にし、メニューの「スリープ防止をオンにする」で開始する。メニューの「Capsaicinを終了」で終了する。
2. 記録を読んで保存する。

   ```sh
   cat "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"
   cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/record.user-quit.json"
   just status
   ```

   期待: `isRunning` が `false`、`exitReason` が `userQuit` で、`session` がない。Capsaicin のアサーションは解放されている。

3. Finder と同じ経路で起動する。

   ```sh
   /usr/bin/open .build/xcode/Build/Products/Debug/Capsaicin.app
   sleep 3
   just status
   ```

   期待: スリープ防止は再開せず、メニューに「スリープ防止をオンにする」が出る。

4. 「スリープ防止の再開」を「クラッシュ後のみ」にし、「タイマー」の「継続時間」を10分にして「スリープ防止をオンにする」で開始する。メニューの解除の時刻を控え、記録を読む。

   ```sh
   /usr/bin/plutil -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" | /usr/bin/grep -E 'isRunning|exitReason|session|lastUpdated'
   ```

   PID を得る。

   ```sh
   PID="$(/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/awk '$1 == "pid" && $2 == "=" {print $3}')"
   /bin/ps -p "$PID" -ww -o pid=,comm=
   ```

   出力がこのチェックアウトの `.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/MacOS/Capsaicin` の絶対パスと一致した場合だけ、クラッシュさせる。`kill -SEGV` は1回だけ行い、起こし直されなくても撃ち直さない。

   ```sh
   /bin/kill -SEGV "$PID"
   ```

5. 起こし直されたら記録を読み、控えた解除の時刻を過ぎるまで待つ。

   ```sh
   just status
   /usr/bin/plutil -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" | /usr/bin/grep -E 'isRunning|lastUpdated|misalignments'
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   ```

   期待: スリープ防止が再開し、メニューの解除の時刻は控えた時刻のままである。その時刻に解除され、タイマーを数え直さない。

## 中止するとき

記録を保存できない旨の警告（メニューの「状態を保存できていません」）が出る、解除の時刻が延びる、PID が一致しない場合は止める。メニューの「スリープ防止をオフにする」で解除し、状態を記録する。記録を消して不具合を隠さない。

```sh
just status
cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/record.aborted.json"
```

## 元に戻す

メニューの「スリープ防止をオフにする」で解除する。「スリープ防止の再開」、「タイマー」、「LED」、「スリープ」の値を控えた値へ戻す。記録ファイルは消さず、`cleanup.md` まで残す。

## 記録

`"$B/result-quit-and-crash-resume.txt"` に次を書く。

- 操作2と操作5で読んだ記録の中身、アサーションの有無
- クラッシュさせた PID と起こし直された PID、再開までにかかった時間
- 控えた解除の時刻と実際に解除された時刻
- 成功／失敗／判定不能、未実施の操作と理由、気づいたこと
