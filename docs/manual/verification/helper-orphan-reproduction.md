# アプリのコピーを消す・動かすときの BTM のデーモンの親

`HYP-HLP-011` を、未使用のヘルパーのラベルで確かめる。実験1は登録元のコピー A を削除し、実験2は別の場所へ移動する。どちらもコピー B から使い直し、BTM の親、UUID、ヘルパーの動作を追う。期待は未確認の仮説であり、違う結果を期待に寄せて解釈しない。所要時間は未実測である。

```text
実験1: A から登録 → A を削除 → B から使用・登録解除
実験2: 別ラベルで A から登録 → A を移動 → 移動した A → B → 登録解除
```

最初に [`prepare.md`](prepare.md)、最後に [`cleanup.md`](cleanup.md) を行う。それ以外の検証ファイルには依存しない。

## 始める前に

- 実行者はオーナーである。ヘルパーの登録とシステム設定での許可、キーチェーンでの署名、今回のコピーだけの削除、復旧用の `/usr/bin/sudo /usr/bin/pmset -a disablesleep 0` を承認し、管理者認証を用意する。**親を失った BTM の項目が、アプリから登録解除しても消せずに残りうることも、実施前に承認する。** `sfltool resetbtm` や手作業のジョブ削除は行わない。
- `prepare.md` の退避と起動前ゲートを終え、`SleepDisabled 0`、Release・Debug とも停止、使用中の登録なしである。開始前からある無効な BTM の記録は消さない。
- 試作の worktree は `/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe`、ブランチは `spike/daemon-cleanup-probe` である。`TASK-117` の接尾辞付きビルドが使えることを、各実験の plist で確かめる。通常版や PR ビルドは使わない。
- LED は測らず、「スリープ防止中にCaps LockのLEDを点灯」をオフにする。起動時には LED を通常連動に戻す処理があるため、既存の LED 上書きを保つ必要がある Mac では行わない。MacBook はディスプレイを開いたままにする。

文書の worktree で devShell に入り、退避先を入れる。`OK` が出なければ止める。以後、各コマンドの結果を確認してから次へ進む。

```sh
cd /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-smappservice
nix develop
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
```

別のターミナルで、起動前からログを残す。ヘルパーのログの subsystem は接尾辞を付けても変わらない。

```sh
B='控えた退避先の絶対パスに置き換える'
/usr/bin/log stream --style compact --predicate 'category == "Spike" AND (subsystem == "io.github.koutyuke.capsaicin.debug" OR subsystem == "io.github.koutyuke.capsaicin.debug.helper")' | /usr/bin/tee "$B/log.helper-orphan.stream.txt"
```

`dumpbtm` は既存の手順と同じ `/usr/bin/sfltool dumpbtm` で採る。権限不足や UID -2 の記録が読めない場合は、空の出力を「項目なし」と判定しない。オーナーが管理者での読み取りを承認した場合だけ、その採取を `/usr/bin/sudo /usr/bin/sfltool dumpbtm` でやり直す。全体の出力は `B` の外へ公開しない。

## 操作と期待

各段階で保存した `btm.*.txt` を開き、今回のラベルの UUID と親を控えてから次へ進む。最後に「記録」のコマンドで Capsaicin の項目だけを抜き出して見比べる。

### 1. 実験1: A を消して B から使う

1. `r1` は例である。この Mac で登録したことのない英小文字・数字だけの名前に置き換える。名前、ラベル、全体の BTM を保存する。

   ```sh
   NAME=r1
   LABEL="io.github.koutyuke.capsaicin.debug.helper-$NAME"
   D="$B/helper-orphan-$NAME"
   mkdir "$D"
   printf '%s\n' "削除: $NAME $LABEL" >> "$B/helper-orphan-names.txt"
   /usr/bin/sfltool dumpbtm > "$D/btm.00-before.txt"
   /usr/bin/grep -F "$LABEL" "$D/btm.00-before.txt"
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   ```

   期待: 名前のディレクトリが新規に作れ、ラベルの検索結果もアプリの PID もなく、`SleepDisabled 0` である。BTM にラベルがなくても、過去の使用を否定できなければ別名を選ぶ。

2. 試作をビルドし、署名する。失敗したら古い成果物は使わない。

   ```sh
   (
     cd /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe &&
     git branch --show-current && git rev-parse HEAD &&
     HELPER_LABEL_SUFFIX="$NAME" nix develop --command just build &&
     nix develop --command just sign-debug
   ) > "$D/build.txt" 2>&1
   cat "$D/build.txt"
   APP='/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe/.build/xcode/Build/Products/Debug/Capsaicin.app'
   /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
   /usr/libexec/PlistBuddy -c 'Print :Label' "$APP/Contents/Library/LaunchDaemons/$LABEL.plist"
   /usr/bin/plutil -p "$APP/Contents/Library/LaunchDaemons/$LABEL.plist" > "$D/plist.txt"
   /usr/bin/codesign -dv --verbose=4 "$APP" 2> "$D/signature.txt"
   /usr/bin/codesign --verify --deep --strict "$APP"
   cat "$D/plist.txt" "$D/signature.txt"
   ```

   期待: ブランチは `spike/daemon-cleanup-probe`、bundle ID は `io.github.koutyuke.capsaicin.debug`、plist の `Label` と `MachServices` のキーは `$LABEL` である。署名検査が成功し、最初の `Authority` が `Developer ID Application:`、Team ID が配布物と同じである。

3. 成果物を A と B に複製する。移動先に既存ファイルがあれば上書きしない。

   ```sh
   mkdir "$D/copy-a" "$D/copy-b"
   /usr/bin/ditto "$APP" "$D/copy-a/Capsaicin.app"
   /usr/bin/ditto "$APP" "$D/copy-b/Capsaicin.app"
   APP="$D/copy-a/Capsaicin.app"
   printf '%s\n' "$APP" > "$B/app-path.txt"
   /usr/bin/pgrep -x Capsaicin
   ```

   PID がない場合だけ A を開く。

   ```sh
   /usr/bin/open "$APP"
   sleep 5
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /bin/ps -p "$PID" -ww -o pid=,ppid=,comm=
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /usr/bin/sfltool dumpbtm > "$D/btm.01-a-launched.txt"
   ```

   期待: PID は1つ、実行ファイルは `$APP/Contents/MacOS/Capsaicin`、agent はサービスなしである。ログの `Agent cleanup before: status=<n>` と `Agent cleanup after: status=0` を控える。試作は同じ bundle ID の別プロセスがいると終了し、起動時に残った Debug agent を一度だけ unregister する。`Duplicate instance; exiting: other_pid=<pid>`、`Agent cleanup failed: <error>`、パス違いなら止める。

4. メニューの「設定…」を開き、開始値と変更値を `"$B/result-helper-orphan-reproduction.txt"` に控える。
   - 「一般」の「スリープ防止の再開」を「再開しない」、「ログイン時に起動」をオフにする。
   - 「スリープ」の「タイマー」「指定時刻」「残量が少なくなったらオフにする」をオフにする。
   - 「LED」の「スリープ防止中にCaps LockのLEDを点灯」をオフにする。
   - 「ヘルパー」が「未インストール」であることを確認して「インストール…」、確認の「インストール」を押す。「システム設定を開く」から今回の項目を許可し、「有効」にする。
   - MacBook では「スリープ」の「ディスプレイを閉じたとき」を「オンのまま」、MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオンにする。

   macOS のシステム設定の項目名は実画面で未確認である。実施時に表示名を控え、BTM の Debug の識別子とコピー A のパスで照合する。Release や別アプリと区別できなければ変更しない。

5. 「スリープ防止をオンにする」を選び、値とデーモンを保存する。

   ```sh
   /usr/bin/pmset -g > "$D/pmset.a-on.txt"
   /bin/launchctl print "system/$LABEL" > "$D/helper.a-on.txt" 2>&1
   cat "$D/pmset.a-on.txt" "$D/helper.a-on.txt"
   ```

   `SleepDisabled 1` を確認して「スリープ防止をオフにする」を選ぶ。

   ```sh
   /usr/bin/pmset -g > "$D/pmset.a-off.txt"
   /usr/bin/sfltool dumpbtm > "$D/btm.02-a-working.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'process == "launchd" AND eventMessage CONTAINS "io.github.koutyuke.capsaicin.debug.helper"' > "$D/log.a.txt"
   cat "$D/pmset.a-off.txt"
   ```

   仮説1の期待: `SleepDisabled 0` に戻り、UID -2 のデーモンの `Parent Identifier` は `2.io.github.koutyuke.capsaicin.debug` である。UUID と親を控える。この段階で動かない、既に `Unknown Developer`、対象項目を読めない場合は削除へ進まず判定不能とする。

6. 「Capsaicinを終了」で A を止める。まだヘルパーは削除しない。

   ```sh
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   /usr/bin/sfltool dumpbtm > "$D/btm.03-a-quit.txt"
   printf '%s\n' "$D/copy-a"
   /bin/ls -ld "$D/copy-a" "$D/copy-a/Capsaicin.app"
   ```

   PID なし、`SleepDisabled 0` を確認する。**次は表示したコピー A のフォルダーだけを完全に削除する。元には戻せない。** 対象が今回のコピーと一致するときだけ実行する。ゴミ箱は空にしない。

   ```sh
   /bin/date '+%Y-%m-%dT%H:%M:%S%z' > "$D/deleted-at.txt"
   /bin/rm -rf "${D:?}/copy-a"
   /usr/bin/sfltool dumpbtm > "$D/btm.04-a-deleted.txt"
   ```

   仮説2の期待: 同じ UUID のデーモンの親が `Unknown Developer` になる。終了時点で変わったのか、削除後に変わったのかを分けて控える。変わらなくても B の観測へ進めるが、仮説2を成立扱いにしない。

7. B を開く前に PID がないことを確認する。

   ```sh
   APP="$D/copy-b/Capsaicin.app"
   printf '%s\n' "$APP" > "$B/app-path.txt"
   /usr/bin/pgrep -x Capsaicin
   ```

   PID がなければ開く。

   ```sh
   /usr/bin/open "$APP"
   sleep 5
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /usr/bin/sfltool dumpbtm > "$D/btm.05-b-launched.txt"
   ```

   実行ファイルが B であることと `Agent cleanup ...` を確認し、「ヘルパー」の表示をそのまま控える。「未インストール」なら「インストール…」、確認の「インストール」で登録する。許可が必要なら「システム設定を開く」から今回の項目だけを許可する。「有効」なら、その表示だけで動作成功や再登録済みと判断しない。

   MacBook は「ディスプレイを閉じたとき」を「オンのまま」、それ以外は「メニューからのスリープも防ぐ」をオンにして「スリープ防止をオンにする」を選ぶ。10秒後に保存する。

   ```sh
   sleep 10
   /usr/bin/pmset -g > "$D/pmset.b-on.txt"
   /bin/launchctl print "system/$LABEL" > "$D/helper.b-on.txt" 2>&1
   /usr/bin/sfltool dumpbtm > "$D/btm.06-b-attempted.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'process == "launchd" AND eventMessage CONTAINS "io.github.koutyuke.capsaicin.debug.helper"' > "$D/log.b.txt"
   cat "$D/pmset.b-on.txt" "$D/helper.b-on.txt"
   ```

   仮説3の期待: 親を失った同じ UUID が使われ、ヘルパーは動かず `SleepDisabled 0` のままである。`log.b.txt` の今回の `$LABEL` と時刻に、`Could not find and/or execute program specified by service: 108: Invalid path: Contents/Helpers/capsaicin-helper` があるか調べる。別ラベルや操作前の失敗は数えない。ログがないだけでは起動成功としない。

8. 「スリープ防止をオフにする」を選ぶ。`SleepDisabled 0` を確認してから「ヘルパー」の「削除…」、確認の「削除」で外す。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/sfltool dumpbtm > "$D/btm.07-b-unregistered.txt"
   /bin/launchctl print "system/$LABEL" > "$D/helper.unregistered.txt" 2>&1
   ```

   仮説4の期待: 「未インストール」になりジョブはなくなるが、親を失った同じ UUID の BTM の項目は残る。`Disposition` が無効になっただけか、項目自体が消えたかを区別する。

   続いて、B からの再登録を明示的に試す。「インストール…」、確認の「インストール」で登録し、許可が必要なら「システム設定を開く」から今回の項目を許可する。MacBook は「ディスプレイを閉じたとき」を「オンのまま」、それ以外は「メニューからのスリープも防ぐ」をオンにして「スリープ防止をオンにする」を選ぶ。

   ```sh
   sleep 10
   /usr/bin/pmset -g > "$D/pmset.b-reregistered.txt"
   /bin/launchctl print "system/$LABEL" > "$D/helper.b-reregistered.txt" 2>&1
   /usr/bin/sfltool dumpbtm > "$D/btm.08-b-reregistered.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'process == "launchd" AND eventMessage CONTAINS "io.github.koutyuke.capsaicin.debug.helper"' > "$D/log.b-reregistered.txt"
   ```

   同じ UUID・親、`SleepDisabled`、今回の登録後の `Invalid path` を控える。「スリープ防止をオフにする」、ヘルパーの「削除…」、確認の「削除」を選び、「未インストール」に戻す。登録解除に失敗したらコピーを消さず中止する。

   「ログイン時に起動」をオフにして「Capsaicinを終了」で止め、コピー B だけを片付ける。

   ```sh
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   /bin/launchctl print "system/$LABEL" > "$D/helper.final.txt" 2>&1
   /usr/bin/sfltool dumpbtm > "$D/btm.09-final.txt"
   /bin/ls -ld "$D/copy-b"
   ```

   PID なし、`SleepDisabled 0`、ジョブなし、表示した今回のコピーであることを確認して消す。BTM の過去の項目だけなら残留として控え、削除を妨げる使用中の登録と混ぜない。

   ```sh
   /bin/rm -rf "${D:?}/copy-b"
   ```

### 2. 実験2: A を動かし、移動した A と B から使う

1. 実験1とは別の未使用名を選ぶ。`r2` は例である。実験1の登録と抑止が片付いていなければ進まない。

   ```sh
   NAME=r2
   LABEL="io.github.koutyuke.capsaicin.debug.helper-$NAME"
   D="$B/helper-orphan-$NAME"
   mkdir "$D"
   printf '%s\n' "移動: $NAME $LABEL" >> "$B/helper-orphan-names.txt"
   /usr/bin/sfltool dumpbtm > "$D/btm.00-before.txt"
   /usr/bin/grep -F "$LABEL" "$D/btm.00-before.txt"
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   ```

   期待: ラベルの検索結果も PID もなく、`SleepDisabled 0` である。試作を別名でビルドし直す。

   ```sh
   (
     cd /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe &&
     git branch --show-current && git rev-parse HEAD &&
     HELPER_LABEL_SUFFIX="$NAME" nix develop --command just build &&
     nix develop --command just sign-debug
   ) > "$D/build.txt" 2>&1
   cat "$D/build.txt"
   APP='/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe/.build/xcode/Build/Products/Debug/Capsaicin.app'
   /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
   /usr/libexec/PlistBuddy -c 'Print :Label' "$APP/Contents/Library/LaunchDaemons/$LABEL.plist"
   /usr/bin/plutil -p "$APP/Contents/Library/LaunchDaemons/$LABEL.plist" > "$D/plist.txt"
   /usr/bin/codesign -dv --verbose=4 "$APP" 2> "$D/signature.txt"
   /usr/bin/codesign --verify --deep --strict "$APP"
   cat "$D/plist.txt" "$D/signature.txt"
   ```

   ビルド・署名が成功し、ブランチ `spike/daemon-cleanup-probe`、Debug の bundle ID、`Label` と `MachServices` が今回の `$LABEL`、Developer ID と同じ Team ID を確認する。違えば複製しない。

2. 新しい A と B を作る。既存の移動先には上書きしない。

   ```sh
   mkdir "$D/copy-a" "$D/copy-b"
   /usr/bin/ditto "$APP" "$D/copy-a/Capsaicin.app"
   /usr/bin/ditto "$APP" "$D/copy-b/Capsaicin.app"
   APP="$D/copy-a/Capsaicin.app"
   printf '%s\n' "$APP" > "$B/app-path.txt"
   /usr/bin/pgrep -x Capsaicin
   ```

   PID がなければ A を開く。

   ```sh
   /usr/bin/open "$APP"
   sleep 5
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /usr/bin/sfltool dumpbtm > "$D/btm.01-a-launched.txt"
   ```

   PID が1つで実行ファイルが A、agent はサービスなし、`Agent cleanup after: status=0` を確認する。重複・解除失敗なら止める。

3. 「設定…」で、「一般」の「スリープ防止の再開」を「再開しない」、「ログイン時に起動」をオフにする。「スリープ」の「タイマー」「指定時刻」「残量が少なくなったらオフにする」と、「LED」の「スリープ防止中にCaps LockのLEDを点灯」もオフにする。

   「ヘルパー」が「未インストール」であることを確認して「インストール…」、確認の「インストール」を押す。「システム設定を開く」から今回の項目だけを許可し、「有効」にする。macOS の表示名は実画面で控える。MacBook は「ディスプレイを閉じたとき」を「オンのまま」、それ以外は「メニューからのスリープも防ぐ」をオンにする。

   「スリープ防止をオンにする」を選び、保存する。

   ```sh
   /usr/bin/pmset -g > "$D/pmset.a-on.txt"
   /bin/launchctl print "system/$LABEL" > "$D/helper.a-on.txt" 2>&1
   cat "$D/pmset.a-on.txt" "$D/helper.a-on.txt"
   ```

   `SleepDisabled 1` を確認して「スリープ防止をオフにする」を選ぶ。

   ```sh
   /usr/bin/pmset -g > "$D/pmset.a-off.txt"
   /usr/bin/sfltool dumpbtm > "$D/btm.02-a-working.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'process == "launchd" AND eventMessage CONTAINS "io.github.koutyuke.capsaicin.debug.helper"' > "$D/log.a.txt"
   cat "$D/pmset.a-off.txt"
   ```

   仮説1の期待: `SleepDisabled 0` に戻り、UID -2 のデーモンの親が `2.io.github.koutyuke.capsaicin.debug` である。UUID を控える。動作や親を確認できなければ移動へ進まない。

4. 「Capsaicinを終了」で A を止める。ヘルパーは削除しない。

   ```sh
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   /usr/bin/sfltool dumpbtm > "$D/btm.03-a-quit.txt"
   /bin/ls -ld "$D/copy-a"
   test ! -e "$D/moved-a" && echo OK
   ```

   PID なし、`SleepDisabled 0`、移動先なしの `OK` を確認して動かす。

   ```sh
   /bin/date '+%Y-%m-%dT%H:%M:%S%z' > "$D/moved-at.txt"
   /bin/mv "$D/copy-a" "$D/moved-a"
   /usr/bin/sfltool dumpbtm > "$D/btm.04-a-moved.txt"
   /bin/launchctl print "system/$LABEL" > "$D/helper.a-moved.txt" 2>&1
   /usr/bin/log show --last 10m --style compact --predicate 'process == "launchd" AND eventMessage CONTAINS "io.github.koutyuke.capsaicin.debug.helper"' > "$D/log.a-moved.txt"
   ```

   仮説2の期待: 同じ UUID のデーモンの親が `Unknown Developer` になる。終了時点と移動後を分けて控える。親が維持された場合も実測として続ける。

5. 移動した A を開く前に PID がないことを確認する。

   ```sh
   APP="$D/moved-a/Capsaicin.app"
   printf '%s\n' "$APP" > "$B/app-path.txt"
   /usr/bin/pgrep -x Capsaicin
   ```

   PID がなければ開く。

   ```sh
   /usr/bin/open "$APP"
   sleep 5
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /usr/bin/sfltool dumpbtm > "$D/btm.05-moved-a-launched.txt"
   ```

   パスが移動した A であることと `Agent cleanup ...` を確認し、ヘルパーの状態を控える。「未インストール」なら「インストール…」、確認の「インストール」で登録する。許可が必要なら「システム設定を開く」から今回の項目を許可する。MacBook は「ディスプレイを閉じたとき」を「オンのまま」、それ以外は「メニューからのスリープも防ぐ」をオンにして「スリープ防止をオンにする」を選ぶ。

   ```sh
   sleep 10
   /usr/bin/pmset -g > "$D/pmset.moved-a-on.txt"
   /bin/launchctl print "system/$LABEL" > "$D/helper.moved-a-on.txt" 2>&1
   /usr/bin/sfltool dumpbtm > "$D/btm.06-moved-a-attempted.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'process == "launchd" AND eventMessage CONTAINS "io.github.koutyuke.capsaicin.debug.helper"' > "$D/log.moved-a.txt"
   ```

   親・UUID・URL が変わったか、`SleepDisabled 1` にできたか、今回のラベルに `Invalid path` が出たかを控える。移動した A の起動で親が戻るかは追加観測であり、仮説の必須の期待にはしない。「スリープ防止をオフにする」を選び、`SleepDisabled 0` を確認して「Capsaicinを終了」で止める。まだヘルパーは削除しない。

6. B を開く前の状態を保存する。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/sfltool dumpbtm > "$D/btm.07-before-b.txt"
   APP="$D/copy-b/Capsaicin.app"
   printf '%s\n' "$APP" > "$B/app-path.txt"
   ```

   `SleepDisabled 0`、PID なしを確認して B を開く。

   ```sh
   /usr/bin/open "$APP"
   sleep 5
   PID="$(/usr/bin/pgrep -x Capsaicin)"
   /usr/sbin/lsof -a -p "$PID" -d txt -Fn
   /usr/bin/sfltool dumpbtm > "$D/btm.08-b-launched.txt"
   ```

   実行ファイルが B、PID が1つであることと `Agent cleanup ...` を確認する。ヘルパーの状態を控え、「未インストール」なら「インストール…」、確認の「インストール」で登録する。必要な許可を行い、MacBook は「ディスプレイを閉じたとき」を「オンのまま」、それ以外は「メニューからのスリープも防ぐ」をオンにして「スリープ防止をオンにする」を選ぶ。

   ```sh
   sleep 10
   /usr/bin/pmset -g > "$D/pmset.b-on.txt"
   /bin/launchctl print "system/$LABEL" > "$D/helper.b-on.txt" 2>&1
   /usr/bin/sfltool dumpbtm > "$D/btm.09-b-attempted.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'process == "launchd" AND eventMessage CONTAINS "io.github.koutyuke.capsaicin.debug.helper"' > "$D/log.b.txt"
   ```

   仮説3の期待は、親を失った同じ UUID、起動失敗と `SleepDisabled 0`、今回の `$LABEL` の `Invalid path: Contents/Helpers/capsaicin-helper` である。移動した A の起動で親が戻った場合は、その条件では仮説3を判定できない。B が「有効」でも、新しい登録操作がなければ再登録の確認とはしない。

7. 「スリープ防止をオフにする」を選び、`SleepDisabled 0` を確認する。「ヘルパー」の「削除…」、確認の「削除」で外して記録する。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/sfltool dumpbtm > "$D/btm.10-b-unregistered.txt"
   /bin/launchctl print "system/$LABEL" > "$D/helper.unregistered.txt" 2>&1
   ```

   仮説4の期待: 「未インストール」、ジョブなしでも、親を失った同じ UUID の項目は残る。続いて B からの再登録を明示的に試す。「インストール…」、確認の「インストール」で登録し、許可が必要なら「システム設定を開く」から今回の項目を許可する。MacBook は「ディスプレイを閉じたとき」を「オンのまま」、それ以外は「メニューからのスリープも防ぐ」をオンにして「スリープ防止をオンにする」を選ぶ。

   ```sh
   sleep 10
   /usr/bin/pmset -g > "$D/pmset.b-reregistered.txt"
   /bin/launchctl print "system/$LABEL" > "$D/helper.b-reregistered.txt" 2>&1
   /usr/bin/sfltool dumpbtm > "$D/btm.11-b-reregistered.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'process == "launchd" AND eventMessage CONTAINS "io.github.koutyuke.capsaicin.debug.helper"' > "$D/log.b-reregistered.txt"
   ```

   UUID・親・動作と今回の登録後のログを控える。「スリープ防止をオフにする」、ヘルパーの「削除…」、確認の「削除」を選び、「未インストール」に戻す。「ログイン時に起動」をオフにし、「Capsaicinを終了」で止める。

   ```sh
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   /bin/launchctl print "system/$LABEL" > "$D/helper.final.txt" 2>&1
   /usr/bin/sfltool dumpbtm > "$D/btm.12-final.txt"
   /bin/ls -ld "$D/moved-a" "$D/copy-b"
   ```

   PID なし、`SleepDisabled 0`、ジョブなし、表示した今回のコピーであることを確認した場合だけ、2つのコピーを消す。解除できなければ消さず中止する。

   ```sh
   /bin/rm -rf "${D:?}/moved-a"
   /bin/rm -rf "${D:?}/copy-b"
   ```

## 中止するとき

別プロセス、パス・署名・ラベル違い、権限不足、開始時から親なし、初回のヘルパーの動作失敗なら、その先の削除・移動は行わない。途中で仮説と違う結果になっただけなら実測を残す。`SleepDisabled` が読めない、停止しても `1` のまま、登録解除できない場合は後続を止める。

動いている試作では「スリープ防止をオフにする」を選ぶ。`SleepDisabled 1` が残った場合だけ、起動し直す前に戻す。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

`0` に戻らなければコピー・登録・設定を残して PM に渡す。戻れば「ヘルパー」の「削除…」、確認の「削除」を選び、「ログイン時に起動」をオフにして「Capsaicinを終了」で止める。解除失敗時はコピーを消さない。時刻、止めた操作、残ったラベルとパスを `"$B/result-helper-orphan-reproduction.txt"` に書く。

## 元に戻す

各実験の登録解除とコピーの削除を終えた場合は、ログ用ターミナルを Control-C で止める。試作をもう一度起動せず、最後の状態を保存する。

```sh
/usr/bin/pmset -g > "$B/pmset.helper-orphan.final.txt"
/usr/bin/pmset -g assertions > "$B/assertions.helper-orphan.final.txt"
/usr/bin/pgrep -x Capsaicin
/usr/bin/sfltool dumpbtm > "$B/btm.helper-orphan.final.txt"
```

`SleepDisabled 0`、Capsaicin のアサーションと PID なしを確認する。今回の各ラベルのジョブなしと、BTM の残った UUID・親を記録する。LED の通常連動も目で確かめる。戻らなければコピーや設定をさらに消さず PM に渡す。

最後に `cleanup.md` で設定と再開用の記録を戻す。ただし、この検証のコピーは既に完全削除しているので、再起動やゴミ箱を空にする操作は行わない。`B/app-path.txt` の削除済みのコピーを起動し直さない。試作 worktree の成果物は登録元ではないため残す。親なしの BTM の項目は、復元できたことにせず残留として PM に渡す。

## 記録

保存した全体の dump から、Capsaicin のアプリ・agent・デーモンだけを抜き出す。UID の見出しを残し、項目ごとに UUID、Identifier、URL、Disposition、Generation、Parent Identifier を表示する。元の dump は上書きしない。

```sh
for dump in "$B"/helper-orphan-*/btm.*.txt; do
  /usr/bin/awk '
    function emit() {
      if (item ~ /(^|\n)[[:space:]]*Identifier:.*io\.github\.koutyuke\.capsaicin([.]|[[:space:]]|$)/) print uid "\n" item
      item = ""
    }
    /Records for UID/ { emit(); uid = $0; next }
    /^[[:space:]]*UUID:/ { emit() }
    /^[[:space:]]*(UUID|Identifier|URL|Disposition|Generation|Parent Identifier):/ {
      item = item $0 "\n"
    }
    END { emit() }
  ' "$dump" > "$dump.capsaicin"
  printf '\n--- %s\n' "$dump"
  cat "$dump.capsaicin"
done
```

抽出結果を全体の dump の対象項目と照合する。書式が違って抽出できなければ、全体から対象項目を読み取り、抽出の不成功を「項目なし」にしない。デーモンは `16.<ラベル>`、アプリの親は `2.io.github.koutyuke.capsaicin.debug` を手掛かりにし、UID -2 と利用者の UID を混ぜない。

`"$B/result-helper-orphan-reproduction.txt"` に次を書く。

- 実行日、機種、macOS のビルド番号、承認内容、各実験の名前・ラベル・コミット・署名・コピーの絶対パス。
- 各段階の時刻、ヘルパーの表示、登録・許可・登録解除を実際に行ったか、`SleepDisabled` のオン／オフ、デーモンの PID・起動失敗。コピー切り替えごとの `Agent cleanup ...` の値。
- UID 別の UUID・Identifier・URL・Disposition・Generation・Parent Identifier の変化。終了、削除・移動、各コピーの起動、再登録、登録解除のどこで変わったか。
- 今回のラベルと時刻に一致する `Invalid path (108)` の有無、仮説1〜4それぞれの当否／判定不能。移動した A で親が戻った場合は B の結果と分ける。
- 成功／失敗／判定不能、中止・未実施の理由、ログと写真の絶対パス、復元結果と残った項目。仮説の確認済みへの更新は PM が行う。
