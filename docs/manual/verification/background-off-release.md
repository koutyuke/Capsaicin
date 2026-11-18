# バックグラウンドの許可を外すと抑止が解除される

ヘルパーが要る抑止中に、システム設定で対象のバックグラウンドの項目だけをオフにする。抑止が解除されて理由が HUD に出ること、アプリと設定の保存値がそのままであることを確かめる（`SPEC-HLP-002`、`SPEC-HLP-004`、`SPEC-BLK-007`、`SPEC-HUD-001`、`SPEC-HUD-002`）。所要時間は未実測である。

```text
[ヘルパー有効・抑止中] → [許可を外す] → [抑止解除・HUD・許可待ち] → [許可を戻して後片付け]
```

## 始める前に

- オーナーが `prepare.md` の起動前ゲートを通し、接続保持と単一インスタンスを含む、Developer ID で署名し直した手元のビルドか署名・公証済みの PR Debug ビルドを `APP` に選んでいる。
- ヘルパーの登録、システム設定の許可の変更、復旧時の `sudo pmset` を承認している。未保存の作業は保存する。

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
/usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.background-off.before.plist" &&
/usr/bin/plutil -lint "$B/defaults.background-off.before.plist"
```

```sh
/usr/bin/open "$APP"
just status
```

`$APP/Contents/MacOS/Capsaicin` のプロセスだけが動いていることを確かめ、メニューの「設定…」を開く。アイコンが見えない場合は `/usr/bin/open "$APP"` でもう一度開き、「一般」の「メニューバーにアイコンを表示」をオンにする。

- 「一般」の「切り替え時にHUDを表示」をオンにし、「ログイン時に起動」はオフにする。
- 「スリープ」の「タイマー」「指定時刻」「残量が少なくなったらオフにする」をオフにする。「LED」の「スリープ防止中にCaps LockのLEDを点灯」もオフにする。
- 「ヘルパー」の「状態」が「未インストール」であることを確かめ、「インストール…」と確認の「インストール」を押す。許可待ちなら「システム設定を開く」から「一般 > ログイン項目と機能拡張」を開く。

```sh
/usr/bin/sfltool dumpbtm > "$B/btm.background-off.before.txt"
```

BTM の Debug の識別子と `APP` のパスに対応するバックグラウンドの項目だけを許可する。macOS の項目名は検証時の画面で照合し、表示名を記録する。Release や別アプリと区別できなければ変更しない。

「状態」が「有効」になってから、「スリープ」の「ディスプレイを閉じたとき」を「オンのまま」にする。MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオンにする。MacBook のディスプレイは閉じない。

## 操作と期待

1. メニューの「スリープ防止をオンにする」を選ぶ。開始時の HUD が消えてから、状態と設定の保存値を記録する。

   ```sh
   just status
   /usr/bin/pmset -g
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/settings.background-off.before.plist" &&
   /usr/bin/plutil -type 'capsaicin\.settings' "$B/settings.background-off.before.plist"
   ```

   期待: `SleepDisabled 1` で、対象アプリとデーモンの PID があり、`capsaicin.settings` は `data` である。値が取れなければ許可を外さない。

2. システム設定で識別したバックグラウンドの項目だけをオフにする。時刻を控え、直後に画面下部の HUD を見る。HUD は短時間で消えるため、文言を控えるか、切り替え前から画面を収録する。手動で抑止を解除したり、アプリを開き直したりしない。

   期待: HUD に「スリープ防止 オフ」と「バックグラウンド項目オフ」が、末尾を省略されずに出る。

3. アプリのメニューと「ヘルパー」を開き、解除後の状態を読む。スリープの設定は操作しない。

   ```sh
   just status
   /usr/bin/pmset -g
   /usr/bin/pmset -g assertions
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /usr/bin/sfltool dumpbtm > "$B/btm.background-off.after.txt"
   /usr/bin/log show --last 10m --style compact --predicate 'process == "capsaicin-helper" AND eventMessage CONTAINS "Helper SIGTERM cleanup"' > "$B/log.background-off.txt"
   ```

   期待: `SleepDisabled 0` になり、Capsaicin のアサーションは消える。デーモンの照会はサービスなしで、ログには操作時刻に対応する PID の `Helper SIGTERM cleanup succeeded` が出る。アプリの PID と開始時刻は変わらず、メニューには「スリープ防止をオンにする」が出る。「ヘルパー」の「状態」は「システム設定での許可待ち」になり、「システム設定を開く」と「削除…」が出る。ヘルパーが要る設定の行には注意の記号が付く。

4. 許可を戻したり、設定を操作したりする前に、保存値を比較する。2 つ目は `defaults export` が成功してから実行する。

   ```sh
   /usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/settings.background-off.after.plist"
   python3 - "$B/settings.background-off.before.plist" "$B/settings.background-off.after.plist" <<'PY'
   import json
   import plistlib
   import sys

   def settings(path):
       with open(path, "rb") as file:
           return json.loads(plistlib.load(file)["capsaicin.settings"])

   if settings(sys.argv[1]) != settings(sys.argv[2]):
       sys.exit("設定差分あり")
   print("設定差分なし")
   PY
   ```

   期待: `設定差分なし` と表示される。設定画面で同じ選択肢が見えるだけでは、保存値が同じとは判定しない。

## 中止するとき

対象を識別できない、抑止開始時の `SleepDisabled` が `1` でない、または許可を外した後に別のアプリが動く、数秒後も `SleepDisabled` が `1` または不明の場合は止める。許可を何度も切り替えない。

```sh
just status > "$B/status.background-off.aborted.txt"
/usr/bin/pmset -g > "$B/pmset.background-off.aborted.txt"
```

対象アプリが動いていて「スリープ防止をオフにする」が出ていれば選ぶ。値を読み直し、今回立てた `1` が残っていると確かめた場合だけ、承認済みの復旧操作を行う。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

対象を特定できない場合や `0` に戻らない場合は、登録と記録を残して PM に渡す。

## 元に戻す

1. `SleepDisabled 0` であることを確認する。操作でバックグラウンドの項目をオフにした場合は、識別済みの項目だけをオンに戻す。対象アプリが停止していれば開く。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/open "$APP"
   just status
   ```

   「ヘルパー」の「状態」が「有効」に戻り、メニューに「スリープ防止をオンにする」が出ることを確かめる。

2. 「ヘルパー」で今回登録したものだけを「削除…」と確認の「削除」で外す。「状態」が「未インストール」になったら「Capsaicinを終了」で終了する。

   ```sh
   just status
   /usr/bin/pmset -g
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   ```

   `No Debug processes.`、`SleepDisabled 0`、デーモンのサービスなしを確かめる。そろった場合だけ停止したまま設定を戻す。

   ```sh
   /usr/bin/defaults import io.github.koutyuke.capsaicin.debug "$B/defaults.background-off.before.plist"
   ```

   準備で退避した記録とアプリの片付けは最後の `cleanup.md` で行う。許可や登録を戻せない場合は、アプリを捨てずに PM に相談する。

## 記録

`"$B/result-background-off-release.txt"` に、ビルド・署名・環境、変更した項目の画面名・識別子・パス、切り替え時刻、前後の PID・`SleepDisabled`・「状態」、HUD の文言、保存値の比較結果を書く。ログ・写真・録画の絶対パスと、成功／失敗／判定不能、復元結果も残す。
