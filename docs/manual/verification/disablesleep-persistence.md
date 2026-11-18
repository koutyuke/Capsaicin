# デーモンがないときの disablesleep の永続性

起動時に `off` を実行するデーモンが登録されていない状態で `disablesleep` を立てると、再起動後も残るかを確かめる。ヘルパーがあるとデーモンが値を下ろすので、ヘルパーのない状態で測る。確かめる仮説は `HYP-BLK-007` である。

前回の測定では再起動の後に `0` だったが、ほかの電源管理アプリ（AlDente の root ヘルパー、Amphetamine の sudoers のルールなど）が書いた可能性を除けなかった（`EVID-BLK-014`）。この結果で、起動時の後片付けを残すかを見直す（`DEC-HLP-005` の覆す条件）。そのため、ほかの電源管理アプリが `disablesleep` を書けない Mac で測る。

この手順はこのファイルだけで完結する。最初の1回の準備（[`prepare.md`](prepare.md)）を除き、ほかの検証ファイルの手順は行わない。共通の決まりは [`README.md`](README.md) にある。

**この手順は再起動後も残る設定を変え、Mac を再起動する。** 終わった直後に必ず値を戻す。値が `1` のまま次の検証へ進まない。ほかのアプリの未保存の作業を保存する。

## 始める前に

- 準備（`prepare.md`）を終え、退避先 `B` の絶対パスを控えている。
- `SleepDisabled` が `0` である。
- Release・Debug 両方の Capsaicin のデーモンと mainApp の登録がない。v0.1.0 の方式のファイルがないことは `prepare.md` で確認済みである。
- ほかの電源管理アプリ（AlDente、Amphetamine など）を終了し、それらの root ヘルパー、LaunchDaemon、`pmset` を許す sudoers のルールもない。下の照会で、Capsaicin 以外の項目を1つずつ確かめる。用途の分からない項目があれば、この検証を実施しない。
- 次の戻すコマンドを、この画面とは別のメモにも控える。再起動後に値が戻らなかったときに使う。

  ```sh
  /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
  /usr/bin/pmset -g
  ```

リポジトリのルートで devShell に入る。

```sh
cd <リポジトリのルート>
nix develop
```

devShell の中で退避先を入れ、足場を確かめる。`OK` が出なければ、退避先かチェックアウトが違うので止める。

```sh
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
```

Capsaicin が動いている場合は、設定の「ヘルパー」が「未インストール」（ad-hoc 署名では「このビルドでは使用不可」）であることを確かめ、「一般」の「ログイン時に起動」をオフにして、メニューの「Capsaicinを終了」で終了する。ヘルパーが「有効」か「システム設定での許可待ち」なら、この検証を始めず `cleanup.md` で片付ける。

Release・Debug 両方のデーモンの登録がないことを確かめる。サービスなし以外のエラーは不在とみなさない。

```sh
/bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
printf 'exit=%s\n' "$?"
/bin/launchctl print system/io.github.koutyuke.capsaicin.helper
printf 'exit=%s\n' "$?"
/usr/bin/sfltool dumpbtm
```

期待: どちらのジョブもサービスなしで、BTM とシステム設定の「一般 > ログイン項目と機能拡張」に Capsaicin の使用中のデーモンと「ログイン時に開く」の登録がない。`disabled` の履歴だけで不在を判断せず、アプリの「ヘルパー」の状態と照合する。アプリを一度も起動していなければ、`prepare.md` の開始前の読み取りと照合する。バンドル内の定義があることは登録の有無を意味しない。macOS の項目名は実装にないため、検証時の画面で照合して記録する。

ほかのアプリの root ヘルパー、LaunchDaemon、sudoers のルールを一覧し、`pmset` を書けるものがないことを確かめる。SMAppService のデーモンも BTM と system ドメインの一覧で調べる。従来の配置先だけで不在と判定しない。

```sh
/bin/ls -l /Library/PrivilegedHelperTools /Library/LaunchDaemons /etc/sudoers.d
/usr/bin/sudo /usr/bin/grep -rl pmset /etc/sudoers.d
/bin/launchctl print system
/usr/bin/sfltool dumpbtm
/bin/ps -axo pid,comm | /usr/bin/grep -iE '[a]ldente|[a]mphetamine'
```

アプリを終了し、`SleepDisabled` が `0` であることを確かめる。

```sh
/bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
/usr/bin/pmset -g
```

## 操作と期待

1. `disablesleep` を立て、再起動前の時刻を記録する。

   ```sh
   /usr/bin/sudo /usr/bin/pmset -a disablesleep 1
   /usr/bin/pmset -g
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   ```

   期待: `SleepDisabled` が `1` になる。`pmset -a disablesleep` は成功しても何も出力しないので、直後の `pmset -g` で値を確かめる。

2. Apple メニューから再起動し、「再ログイン時にウインドウを再度開く」を外す。再ログインしたら、アプリは起動しない。ターミナルでリポジトリのルートを開いて devShell に入る。

   ```sh
   cd <リポジトリのルート>
   nix develop
   ```

   devShell の中で退避先を入れ直し、状態を読む。

   ```sh
   B='控えた退避先の絶対パスに置き換える'
   test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   /usr/bin/pmset -g
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /bin/launchctl print system/io.github.koutyuke.capsaicin.helper
   /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
   ```

   期待: 再起動の前後とも `SleepDisabled = 1` なら仮説を支持し、再起動後に `0` なら支持しない。値が欠落する、ほかの常駐処理が起動する場合は判定不能とし、観測した事実を残す。

3. 判定したらすぐに値を戻す。

   ```sh
   /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
   /usr/bin/pmset -g
   ```

   期待: `SleepDisabled` が `0` に戻る。

## 中止するとき

どの時点で止めても、`SleepDisabled` が `0` でなければ次で戻す。`0` に戻らなければ後続を止めて PM に報告する。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

## 元に戻す

`SleepDisabled` が `0` であることを確かめる。アプリは起動せず、最後に `cleanup.md` で設定を開始前へ戻す。

```sh
/usr/bin/pmset -g
```

ヘルパーを削除しても `/Library/Application Support/io.github.koutyuke.capsaicin.debug/boot-session-uuid` は残る。Mac の起動が変わった後に設置し直すと、その場で外部の `disablesleep` も下ろす制約がある（`SPEC-HLP-003`）。次に設置する場合も、必ず `SleepDisabled = 0` を確かめてから行い、起動の記録は消さない。

## 記録

`"$B/result-disablesleep-persistence.txt"` に次を書く。

- 再起動の前後それぞれの `SleepDisabled`、再起動の前後の時刻
- Capsaicin のデーモンと mainApp の登録がない根拠、ほかの電源管理アプリと常駐処理の調査結果
- 戻すコマンドを控えた場所、操作3で戻したこと
- 成功／失敗／判定不能、未実施の操作と理由、気づいたこと
