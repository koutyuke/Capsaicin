# Daemon がないときの disablesleep の永続性

起動時に `off` を実行する LaunchDaemon がない状態で `disablesleep` を立てると、再起動後も残るかを確かめる。ヘルパーがあると Daemon が値を下ろすので、ヘルパーのない状態で測る。確かめる仮説は `HYP-BLK-007` である。

前回の測定では再起動の後に `0` だったが、ほかの電源管理アプリ（AlDente の root ヘルパー、Amphetamine の sudoers のルールなど）が書いた可能性を除けなかった（`EVID-BLK-014`）。この結果で、起動時の後片付けを残すかを見直す（`DEC-HLP-005` の覆す条件）。そのため、ほかの電源管理アプリが `disablesleep` を書けない Mac で測る。

この手順はこのファイルだけで完結する。最初の1回の準備（[`prepare.md`](prepare.md)）を除き、ほかの検証ファイルの手順は行わない。共通の決まりは [`README.md`](README.md) にある。

**この手順は再起動後も残る設定を変え、Mac を再起動する。** 終わった直後に必ず値を戻す。値が `1` のまま次の検証へ進まない。ほかのアプリの未保存の作業を保存する。

## 始める前に

- 準備（`prepare.md`）を終え、退避先 `B` の絶対パスを控えている。
- `SleepDisabled` が `0` である。
- Release・Debug 両方のヘルパー、Daemon、sudoers がない。
- ほかの電源管理アプリ（AlDente、Amphetamine など）を終了し、それらの root ヘルパー、LaunchDaemon、`pmset` を許す sudoers のルールもない。下の照会で、Capsaicin 以外の項目を1つずつ確かめる。用途の分からない項目があれば、この検証を実施しない。
- 次の戻すコマンドを、この画面とは別のメモにも控える。再起動後に値が戻らなかったときに使う。

  ```sh
  /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
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

Release・Debug 両方のヘルパー構成がないことを確かめる。1つでもあれば、この検証を実施しない。

```sh
/bin/ls -ld /Library/PrivilegedHelperTools/io.github.koutyuke.capsaicin.helper{,.debug}
/bin/ls -ld /etc/sudoers.d/capsaicin{,_debug}
/bin/ls -ld /Library/LaunchDaemons/io.github.koutyuke.capsaicin.helper{,.debug}.plist
```

ほかのアプリの root ヘルパー、LaunchDaemon、sudoers のルールを一覧し、`pmset` を書けるものがないことを確かめる。

```sh
/bin/ls -l /Library/PrivilegedHelperTools /Library/LaunchDaemons /etc/sudoers.d
/usr/bin/sudo /usr/bin/grep -rl pmset /etc/sudoers.d
/bin/ps -axo pid,comm | /usr/bin/grep -iE '[a]ldente|[a]mphetamine'
```

アプリを終了し、`SleepDisabled` が `0` であることを確かめる。

```sh
just stop
just status
```

## 操作と期待

1. `disablesleep` を立て、再起動前の時刻を記録する。

   ```sh
   /usr/bin/sudo /usr/bin/pmset -a disablesleep 1
   just status
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   ```

   期待: `SleepDisabled` が `1` になる。

2. Apple メニューから再起動する。再ログインしたら、アプリは起動しない。ターミナルでリポジトリのルートを開いて devShell に入る。

   ```sh
   cd <リポジトリのルート>
   nix develop
   ```

   devShell の中で退避先を入れ直し、状態を読む。

   ```sh
   B='控えた退避先の絶対パスに置き換える'
   test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   just status
   ```

   期待: 再起動の前後とも `SleepDisabled = 1` なら仮説を支持し、再起動後に `0` なら支持しない。値が欠落する、ほかの常駐処理が起動する場合は判定不能とし、観測した事実を残す。

3. 判定したらすぐに値を戻す。

   ```sh
   /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
   just status
   ```

   期待: `SleepDisabled` が `0` に戻る。

## 中止するとき

どの時点で止めても、`SleepDisabled` が `0` でなければ次で戻す。`0` に戻らなければ後続を止めて PM に報告する。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
just status
```

## 元に戻す

`SleepDisabled` が `0` であることを確かめてから、アプリを起動する。

```sh
just status
just start
```

## 記録

`"$B/result-disablesleep-persistence.txt"` に次を書く。

- 再起動の前後それぞれの `SleepDisabled`、再起動の前後の時刻
- 戻すコマンドを控えた場所、操作3で戻したこと
- 成功／失敗／判定不能、未実施の操作と理由、気づいたこと
