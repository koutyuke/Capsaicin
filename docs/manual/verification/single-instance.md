# 同じ bundle ID の別のコピーから既存の設定を開く

Debug アプリが抑止中に、同じ bundle ID の別のコピーを起動する。後から開いた方は終了し、動いていた方の設定ウインドウが前に出ることを確かめる（`SPEC-LCY-009`、`SPEC-SET-001`）。`just start` が、Debug がすでに動いているときに起動を拒むことも確かめる（`DEC-SYS-027`）。ヘルパーは設置しない。所要時間は未実測である。

```text
[最初のアプリが抑止中] → [just start は起動を拒む] → [別のコピーを新規起動] → [最初のアプリだけ残り、設定が前面に出る]
```

## 始める前に

- オーナーが `prepare.md` の起動前ゲートを通し、接続保持と単一インスタンスを含む、Developer ID で署名し直した手元のビルドか署名・公証済みの PR Debug ビルドを `APP` に選んでいる。チェックアウトとは別の場所の Debug も `just start` が検出することを確かめるなら、最初に PR Debug ビルドを選ぶ。
- 2つ目は、`APP` から `B` の下に作るコピーとする。既存の別のビルドを変更しない。

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
/usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.single-instance.before.plist" &&
/usr/bin/plutil -lint "$B/defaults.single-instance.before.plist"
```

```sh
mkdir "$B/single-instance-copy" &&
/usr/bin/ditto "$APP" "$B/single-instance-copy/Capsaicin.app" &&
/usr/bin/codesign --verify --deep --strict "$B/single-instance-copy/Capsaicin.app" &&
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$B/single-instance-copy/Capsaicin.app/Contents/Info.plist"
```

署名検査が成功し、コピーの bundle ID も `io.github.koutyuke.capsaicin.debug` であることを確かめる。作成先がすでにあれば上書きしない。

```sh
/usr/bin/open "$APP"
just status
```

`$APP/Contents/MacOS/Capsaicin` のプロセスだけが動いていることを確かめ、メニューの「設定…」を開く。アイコンが見えない場合は `/usr/bin/open "$APP"` でもう一度開き、「一般」の「メニューバーにアイコンを表示」をオンにする。

- 「一般」の「ログイン時に起動」をオフにする。
- 「スリープ」の「ディスプレイを閉じたとき」を「システムスリープ（標準）」にする。MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオフにする。
- 「スリープ」の「タイマー」と「残量が少なくなったらオフにする」はオフにする。「指定時刻」はオンにし、確認中に時刻を迎えないよう、30 分以上先に設定する。

## 操作と期待

1. 設定ウインドウを閉じ、メニューの「スリープ防止をオンにする」を選ぶ。メニューを開き直し、「スリープ防止中」と、残り時間ではなく解除の時刻を控える。メニューを閉じ、最初の PID と開始時刻を記録する。

   ```sh
   just status > "$B/status.single-instance.before.txt"
   cat "$B/status.single-instance.before.txt"
   /usr/bin/pmset -g assertions > "$B/assertions.single-instance.before.txt"
   ```

   期待: 選んだ `APP` の PID だけがあり、Capsaicin のアサーションがある。ヘルパーが要らない設定なので `SleepDisabled 0` である。

2. 動いている方を終了させず、リポジトリのルートで `just start` を実行する。

   ```sh
   just start > "$B/start.single-instance.txt" 2>&1
   printf 'exit=%s\n' "$?"
   cat "$B/start.single-instance.txt"
   just status
   ```

   期待: 終了コードは `1` で、`Debug apps are running. Run just stop first.` と出る。PID・開始時刻・実行ファイルはそのままである。表示にある `just stop` は実行しない。

3. 設定ウインドウが閉じたままであることを確かめ、別のコピーを新しいプロセスとして開く。`-n` がないと macOS が既存の方に開き直しを届けるだけの可能性がある。`-W` で、新しく開いた方が終了するまで待つ。

   ```sh
   /usr/bin/open -n -W "$B/single-instance-copy/Capsaicin.app"
   printf 'open exit=%s\n' "$?"
   ```

   期待: 先に動いていた方の設定ウインドウが前に出る。そのアプリを閉じなくても `open` が終了コード `0` で戻る。ウインドウを手で開いて結果を補わない。10 秒程度たってもコマンドが戻らなければ Control-C で待機を止め、状態を記録する。

4. PID と抑止を読み直す。メニューの解除の時刻も読み直す。

   ```sh
   just status > "$B/status.single-instance.after.txt"
   cat "$B/status.single-instance.after.txt"
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g assertions > "$B/assertions.single-instance.after.txt"
   ```

   期待: 最初の PID・開始時刻・実行ファイルだけが残り、設定ウインドウが開いている。「スリープ防止中」のままで、解除の時刻とアサーションを持つ PID は変わらない。`SleepDisabled 0` のままである。別のコピーがヘルパー、LED、輝度、IPC の初期化に進まないことは、`AppDelegate.swift` で起動処理の前に終了する分岐を照合する。この実機観測だけで、全制御の呼び出し回数までは判定しない。

## 中止するとき

想定外のコピーが動く、2つ目が終了しない、最初の PID や抑止が変わる、パスを照合できない場合は起動を繰り返さない。

```sh
just status > "$B/status.single-instance.aborted.txt"
/bin/ps -axo pid,ppid,comm > "$B/processes.single-instance.aborted.txt"
```

対象がどちらか分からない場合は `just stop` で一括終了せず、パスと PID を PM に渡す。最初のアプリだけが動いていると確かめられる場合は、メニューの「スリープ防止をオフにする」を選び、「Capsaicinを終了」で終了する。

## 元に戻す

最初のアプリが動いていれば、メニューで「スリープ防止をオフにする」を選ぶ。「Capsaicinを終了」で終了してから、プロセスと抑止を確かめる。

```sh
just status
/usr/bin/pmset -g
/usr/bin/pmset -g assertions
```

`No Debug processes.`、`SleepDisabled 0`、Capsaicin のアサーションなしを確認する。そろった場合だけ停止したまま設定を戻し、今回作った別のコピーだけをゴミ箱に移す。

```sh
/usr/bin/defaults import io.github.koutyuke.capsaicin.debug "$B/defaults.single-instance.before.plist" &&
trash "${B:?}/single-instance-copy/Capsaicin.app"
```

`APP` と保存設定・輝度の記録の片付けは、最後の `cleanup.md` で行う。プロセスや抑止が残っていれば、コピーも処分せず PM に相談する。

## 記録

`"$B/result-single-instance.txt"` に、ビルド・署名・環境、2つの絶対パス、`just start` の終了コードと出力、`open` の結果、前後の PID・開始時刻・アサーション・解除の時刻、設定ウインドウが前に出たか、成功／失敗／判定不能と復元結果を書く。
