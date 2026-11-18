# worktree 間で Debug agent の起動先を切り替える

同じラベル `io.github.koutyuke.capsaicin.debug` を共有する2つの worktree で、`just start` がそのチェックアウトの実行ファイルへ起動先を切り替えることを確かめる。確かめる仕様は `SPEC-LCY-005`、操作の承認範囲は `DEC-SYS-024` である。`justfile` の `start` と `status`、`LaunchAgent.swift` の登録処理を対象とする。

最初の1回の準備は [`prepare.md`](prepare.md)、最後の片付けは [`cleanup.md`](cleanup.md) で行う。それ以外の検証ファイルの操作には依存しない。所要時間は未実測である。

## 始める前に

- オーナーが2つの worktree の Debug アプリの起動と終了、agent・mainApp の登録、Debug ジョブの切り替えを承認している。署名し直す操作にも承認があり、配布物と同じ Team ID の「Apple Development」の証明書と鍵がオーナーのキーチェーンにある（`DEC-SYS-025`）。`just stop` は全チェックアウトの手元の Debug アプリを対象にするため、ほかの検証を同時に行わない。
- 2つの worktree はオーナーが用意済みで、それぞれの `.build/xcode/Build/Products/Debug/Capsaicin.app` をビルド済みである。このファイルでは worktree を作らず、コードも変更しない。
- 1つ目の worktree で `prepare.md` を手元のビルド用に終え、`B` の絶対パスを控えている。`/Applications` の PR ビルドと Release は動かさない。
- ヘルパーは使わず、`SleepDisabled = 0` である。このファイルでは worktree 間の切り替えだけを確かめ、ヘルパーやログイン時の起動の検証には数えない。

1つ目の worktree のルートで devShell に入り、退避先と2つの worktree を指定する。`W2` はオーナーが用意した2つ目の worktree の絶対パスに置き換える。2つの `OK` が出なければ止める。`pgrep` で Capsaicin が見つかった場合も、署名し直す前に止める。

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
/usr/bin/pgrep -x Capsaicin
```

アプリが動いていないことを確かめてから、両方のビルドを同じ Team ID で署名し直す。再ビルドした場合は、そのビルドも署名し直してから起動する。

```sh
just sign-debug
(cd "$W2" && nix develop --command just sign-debug)
/usr/bin/codesign -dv "$W1/.build/xcode/Build/Products/Debug/Capsaicin.app" 2>&1
/usr/bin/codesign -dv "$W2/.build/xcode/Build/Products/Debug/Capsaicin.app" 2>&1
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$W1/.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$W2/.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/Info.plist"
just status
/usr/bin/pgrep -x Capsaicin
```

期待: bundle ID は両方 `io.github.koutyuke.capsaicin.debug`、`TeamIdentifier` は両方とも配布物と同じである。署名し直しや検査が失敗したら起動しない。対象外のアプリのプロセスがあれば止める。起動先の判定は `just status` の `Job executable:` が示す、ジョブの PID から引いた実行ファイルの絶対パスで行う。バンドル内の定義の存在だけで合格にしない。定義は `project.yml` のビルドフェーズが `Contents/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist` に作る。

## 操作と期待

1. 1つ目の worktree の devShell で、手元の Debug アプリを止めてから起動する。

   ```sh
   just stop
   just start
   just status
   ```

   期待: `Started Debug PID …` が1つ目の実行ファイルの絶対パスを示す。`just status` は `Job matches this checkout: yes` で、`Job executable:` は `$W1/.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/MacOS/Capsaicin` を指す。プロセスは1本だけで、ジョブの `pid` と一致し、PPID は `1` である。

   「一般」の「ログイン時に起動」「スリープ防止の再開」、「LED」の「スリープ防止中にCaps LockのLEDを点灯」、「スリープ」の値を `"$B/result-debug-agent-worktree-switch.txt"` に控える。ログイン時の起動と LED はオフ、再開は「再開しない」にする。「ディスプレイを閉じたとき」は「システムスリープ（標準）」、MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオフにする。抑止は開始しない。

2. 1つ目を止め、agent のジョブが読み込まれたままでアプリだけが停止したことを確かめる。

   ```sh
   just stop
   just status
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   ```

   期待: プロセス一覧は `No Debug processes.` で、ジョブに実行中の `pid` がない。`Job matches this checkout: unknown (job is not running)` になる。停止中は実行ファイルの絶対パスを読めず、どのチェックアウトのジョブか判断できない。ここでは手作業でジョブを外さない。

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

   期待: `just start` が読み込み済みの Debug ジョブを外し、開いたアプリ自身による SMAppService の登録と引き渡しを経て起動する。`Started Debug PID …` は2つ目のパスを示す。`just status` は `Job matches this checkout: yes` で、`Job executable:` は `$W2/.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/MacOS/Capsaicin` になる。プロセスは1本だけで、PPID は `1`、1つ目は動かない。

4. 1つ目のターミナルに戻り、起動はせず状態だけ読む。

   ```sh
   just status
   ```

   期待: `This checkout:` は1つ目のパス、`Job executable:` と唯一のプロセスは2つ目のパスで、`Job matches this checkout: no` になる。終了コードは `0` でも、表示は一致しないことを示す。

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

   期待: `Job executable:` と唯一のプロセスが1つ目のパスへ戻り、PPID は `1`、`Job matches this checkout: yes` になる。抑止はオフ、`SleepDisabled = 0` のままである。

## 中止するとき

`just start` が失敗した場合は、停止する前に launchd のログで `Launch Constraint Violation` を探す。

```sh
/usr/bin/log show --last 5m --predicate 'process == "launchd"' | grep 'Launch Constraint Violation' > "$B/launch-constraint.switch-aborted.txt"
```

該当する記録があれば、ad-hoc 署名のビルドが同じ bundle ID の Team ID 付きビルドの agent の項目を使っていないか、署名の `TeamIdentifier` を記録して照合する。

```sh
/usr/bin/codesign -dv "$W1/.build/xcode/Build/Products/Debug/Capsaicin.app" > "$B/signature-first.switch-aborted.txt" 2>&1
/usr/bin/codesign -dv "$W2/.build/xcode/Build/Products/Debug/Capsaicin.app" > "$B/signature-second.switch-aborted.txt" 2>&1
```

直接起動したアプリだけが動き続けていても、agent への引き渡しが確かめられなければ失敗である。アプリを止めてから `just sign-debug` で同じ Team ID の署名を用意し、PM と再試行を決める。ログに該当する記録がないだけでは、起動の成功とみなさない。

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

- 2つの worktree と Debug アプリの絶対パス、bundle ID、ビルド番号、署名の `TeamIdentifier`
- 各起動・停止後の `Job executable:`、`pid`、PPID、プロセスの本数、`Job matches this checkout` の値。停止中の起動先は判定不能とする
- 1つ目→2つ目→1つ目の切り替えの結果、`just start` の出力と終了コード
- `SIGTERM` の有無、`SleepDisabled` とアサーション、戻した設定と片付け対象のアプリ
- 失敗時の `Launch Constraint Violation` の有無、ログと署名の記録の絶対パス
- 成功／失敗／判定不能、未実施の操作と理由、出力を保存した絶対パス
