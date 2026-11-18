# worktree 間で Debug agent の起動先を切り替える

同じラベル `io.github.koutyuke.capsaicin.debug` を共有する2つの worktree で、`just start` がそのチェックアウトの実行ファイルへ起動先を切り替えることを確かめる。確かめる仕様は `SPEC-LCY-005`、操作の承認範囲は `DEC-SYS-024` である。`justfile` の `start` と `status`、`LaunchAgent.swift` の登録処理を対象とする。

最初の1回の準備は [`prepare.md`](prepare.md)、最後の片付けは [`cleanup.md`](cleanup.md) で行う。それ以外の検証ファイルの操作には依存しない。所要時間は未実測である。

## 始める前に

- オーナーが2つの worktree の Debug アプリの起動と終了、agent・mainApp の登録、Debug ジョブの切り替えを承認している。`just stop` は全チェックアウトの手元の Debug アプリを対象にするため、ほかの検証を同時に行わない。
- 2つの worktree はオーナーが用意済みで、それぞれの `.build/xcode/Build/Products/Debug/Capsaicin.app` をビルド済みである。このファイルでは worktree を作らず、コードも変更しない。
- 1つ目の worktree で `prepare.md` を手元のビルド用に終え、`B` の絶対パスを控えている。`/Applications` の PR ビルドと Release は動かさない。
- ヘルパーは使わず、`SleepDisabled = 0` である。ad-hoc 署名のビルドを使ってよいが、ヘルパーやログイン時の起動の検証には数えない。

1つ目の worktree のルートで devShell に入り、退避先と2つの worktree を指定する。`W2` はオーナーが用意した2つ目の worktree の絶対パスに置き換える。2つの `OK` が出なければ止める。

```sh
cd <1つ目の worktree のルート>
nix develop
B='控えた退避先の絶対パスに置き換える'
W1="$(cat "$B/repository-path.txt")"
W2='2つ目の worktree の絶対パスに置き換える'
test "$W1" = "$PWD" && echo OK
test "$W1" != "$W2" && test -d "$W2/.build/xcode/Build/Products/Debug/Capsaicin.app" && echo OK
printf 'W1=%s\nW2=%s\n' "$W1" "$W2"
printf '%s\n' "$W2" > "$B/second-worktree-path.txt"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$W1/.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$W2/.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/Info.plist"
just status
/bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
```

期待: bundle ID は両方 `io.github.koutyuke.capsaicin.debug` である。対象外のアプリのプロセスがあれば止める。起動先の判定はジョブの `program` で行い、バンドル内の定義の存在だけで合格にしない。定義は `project.yml` のビルドフェーズが `Contents/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist` に作る。

## 操作と期待

1. 1つ目の worktree の devShell で、手元の Debug アプリを止めてから起動する。

   ```sh
   just stop
   just start
   just status
   ```

   期待: `Started Debug PID …` が1つ目の実行ファイルの絶対パスを示す。`just status` は `Job matches this checkout: yes` で、`program` は `$W1/.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/MacOS/Capsaicin` を指す。プロセスは1本だけで、ジョブの `pid` と一致する。

   「一般」の「ログイン時に起動」「スリープ防止の再開」、「LED」の「スリープ防止中にCaps LockのLEDを点灯」、「スリープ」の値を `"$B/result-debug-agent-worktree-switch.txt"` に控える。ログイン時の起動と LED はオフ、再開は「再開しない」にする。「ディスプレイを閉じたとき」は「システムスリープ（標準）」、MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオフにする。抑止は開始しない。

2. 1つ目を止め、agent のジョブが読み込まれたままでアプリだけが停止したことを確かめる。

   ```sh
   just stop
   just status
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   ```

   期待: プロセス一覧は `No Debug processes.` で、ジョブに実行中の `pid` がない。`program` は1つ目のパスのままである。ここでは手作業でジョブを外さない。

3. 別のターミナルで2つ目の worktree のルートを開き、devShell に入る。`B` と `W2` を保存した値から読み戻す。`OK` が出なければ止める。

   ```sh
   cd <2つ目の worktree のルート>
   nix develop
   B='控えた退避先の絶対パスに置き換える'
   W1="$(cat "$B/repository-path.txt")"
   W2="$(cat "$B/second-worktree-path.txt")"
   test "$W2" = "$PWD" && echo OK
   just start
   just status
   ```

   期待: `just start` が読み込み済みの Debug ジョブを外し、開いたアプリ自身による SMAppService の登録と引き渡しを経て起動する。`Started Debug PID …` は2つ目のパスを示す。`just status` は `Job matches this checkout: yes` で、`program` は `$W2/.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/MacOS/Capsaicin` になる。プロセスは1本だけで、1つ目は動かない。

4. 1つ目のターミナルに戻り、起動はせず状態だけ読む。

   ```sh
   just status
   ```

   期待: `This checkout:` は1つ目のパス、`program` と唯一のプロセスは2つ目のパスで、`Job matches this checkout: no` になる。終了コードは `0` でも、表示は一致しないことを示す。

5. 2つ目のターミナルで停止する。

   ```sh
   just stop
   just status
   ```

   プロセスが消えたら、1つ目のターミナルで起動する。

   ```sh
   just start
   just status
   ```

   期待: `program` と唯一のプロセスが1つ目のパスへ戻り、`Job matches this checkout: yes` になる。抑止はオフ、`SleepDisabled = 0` のままである。

## 中止するとき

複数起動、対象外のパス、`just start` の失敗、切り替え後の不一致、`SleepDisabled` の変化があれば止める。起動を繰り返さず、動いている対象のメニューで抑止を解除してから、いずれかの worktree の devShell で停止する。

```sh
just stop
just status
/usr/bin/pmset -g
/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" > "$B/agent.switch-aborted.txt" 2>&1
```

`SIGTERM` で停止した場合は後片付けを通らないので、アサーションと値を記録する。値が戻らない場合は追加の登録操作をせず、`cleanup.md` で復旧する。

## 元に戻す

1つ目のアプリで控えた設定を戻す。起動していなければ、1つ目のターミナルで次を実行する。別の Debug アプリが残っている間は `just start` を実行しない。

```sh
just status
just start
```

「ログイン時に起動」「スリープ防止の再開」「LED」「スリープ」の値を戻してから停止する。

```sh
just stop
just status
```

最後に1つ目の worktree で `cleanup.md` を行う。2つのビルドの絶対パスを記録し、今回使ったアプリだけを片付ける。ソースや worktree 自体は削除しない。

## 記録

`"$B/result-debug-agent-worktree-switch.txt"` に次を書く。

- 2つの worktree と Debug アプリの絶対パス、bundle ID、ビルド番号
- 各起動・停止後の `program`、`pid`、プロセスの本数、`Job matches this checkout` の値
- 1つ目→2つ目→1つ目の切り替えの結果、`just start` の出力と終了コード
- `SIGTERM` の有無、`SleepDisabled` とアサーション、戻した設定と片付け対象のアプリ
- 成功／失敗／判定不能、未実施の操作と理由、出力を保存した絶対パス
