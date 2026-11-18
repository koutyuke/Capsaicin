# ログアウト・再起動・システム終了と再開、連続クラッシュの上限

「スリープ防止の再開」の設定と終わり方の組み合わせごとに、ログイン後にスリープ防止が再開するかと、短い間に続けてクラッシュしたときは3回目で再開をやめることを確かめる。確かめる仕様と仮説は `HYP-LCY-004`、`HYP-LCY-005`、`SPEC-LCY-004`、`SPEC-LCY-006`、`SPEC-LCY-007` である。

この手順はこのファイルだけで完結する。最初の1回の準備（[`prepare.md`](prepare.md)）を除き、ほかの検証ファイルの手順は行わない。共通の決まりは [`README.md`](README.md) にある。

**この手順はログアウト、再起動、システム終了を繰り返す。** 失われるほかのアプリの未保存データは戻せないので、必ず先に保存する。

## 始める前に

- 準備（`prepare.md`）を終え、退避先 `B` の絶対パスを控えている。
- LED とヘルパーを使わない。

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

設定の次の値を `"$B/result-logout-restart-crash-limit.txt"` に控えてから変える。

- 「一般」の「ログイン時に起動」をオンにする。「スリープ防止の再開」の値を控える。
- 「LED」の「スリープ防止中にCaps LockのLEDを点灯」をオフにする。
- 「スリープ」の「ディスプレイを閉じたとき」を「システムスリープ（標準）」にする（MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオフ）。「残量が少なくなったらオフにする」と「指定時刻」をオフにする。

## 操作と期待

1. 次の表の行ごとに、設定を変えて新しく「スリープ防止をオンにする」で開始し、終わり方の操作を行う。行と行の間はメニューの「スリープ防止をオフにする」で解除し、行をまたいで抑止を続けない。表の各行は独立した試行で、期待と違ったらその行だけを止めて記録する。次の行へ進んでよいかは PM が決める。

   | 「スリープ防止の再開」 | 「タイマー」 | 終わり方 | ログイン後に期待する状態 |
   | --- | --- | --- | --- |
   | 再開しない | オフ | Apple メニューの「再起動…」 | スリープ防止オフ |
   | クラッシュ後のみ | オフ | ログアウト。別の試行で再起動 | どちらもスリープ防止オフ |
   | クラッシュおよびMacの再起動後 | オフ | ログアウト。別の試行で再起動 | どちらもスリープ防止中 |
   | クラッシュおよびMacの再起動後 | オン、「継続時間」1分 | システム終了し、2分以上待って起動 | 期限切れなのでスリープ防止オフ |

   再起動とシステム終了の試行では、直前に時刻を保存する。

   ```sh
   /usr/sbin/sysctl kern.boottime
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   ```

   各試行でログインし直したら、ターミナルでリポジトリのルートを開いて devShell に入る。

   ```sh
   cd <リポジトリのルート>
   nix develop
   ```

   devShell の中で退避先を入れ直し、状態、時刻、記録を保存する。

   ```sh
   B='控えた退避先の絶対パスに置き換える'
   test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
   just status
   /usr/sbin/sysctl kern.boottime
   /bin/date '+%Y-%m-%dT%H:%M:%S%z'
   /usr/bin/plutil -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" | /usr/bin/grep -E 'isRunning|exitReason|lastUpdated|crashLaunches'
   ```

   期待: 表のとおりである。同じ Mac の起動中は `kern.boottime` が変わらず、Mac の再起動後は保存した `lastUpdated` より後になる。`lastUpdated` は Swift の `Date` の標準の JSON 表現で、2001-01-01 UTC からの秒数である。UNIX 秒と直接比べない。

2. 連続クラッシュを試す。「スリープ防止の再開」を「クラッシュ後のみ」、「タイマー」をオフにして、「スリープ防止をオンにする」で開始する。10分以内に、次の1回分を3回、1回ずつ行う。途中で手で解除や開始をしない。

   ```sh
   PID="$(/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/awk '$1 == "pid" && $2 == "=" {print $3}')"
   /bin/ps -p "$PID" -ww -o pid=,comm=
   ```

   出力がこのチェックアウトの `.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/MacOS/Capsaicin` の絶対パスと一致した場合だけ、クラッシュさせて別の PID で起動したことを確かめる。一致しなければシグナルを送らない。

   ```sh
   /bin/kill -SEGV "$PID"
   sleep 5
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/grep -E '^\s*(state|pid|runs|last exit code) ='
   ```

   各回の後に、メニューでスリープ防止中かどうかを見る。3回目の後に記録を読む。

   ```sh
   /usr/bin/plutil -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" | /usr/bin/grep -E 'isRunning|crashLaunches'
   ```

   期待: 1・2回目の後は再開し、3回目の後はスリープ防止オフになる。`crashLaunches` に3件が残る。

`HYP-LCY-005` の Apple Event の生の値、終了処理の意図的な引き延ばし、ログアウトを取り消した後の内部判定は、通常のビルドでは採取も注入もできない。表による間接の確認と区別して判定不能とする。`HYP-LCY-004` の時計を戻す試験は、ほかのサービスにも影響するので実施しない。起動処理の途中の中断、起動時刻の取得不能、記録の保存の失敗、ヘルパーの期限超過は、専用の偽物を使う自動テストに任せる。実機の権限や時計を壊して模擬しない。

## 中止するとき

ログインしても起動しない、再開の条件と結果が違う、3回目でも再開する場合は止める。追加のシグナルを送らない。起動していればメニューの「スリープ防止をオフにする」で解除し、状態と記録を保存する。

```sh
just status
cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/record.aborted.json"
```

## 元に戻す

起動していればメニューの「スリープ防止をオフにする」で解除する。「ログイン時に起動」、「スリープ防止の再開」、「タイマー」、「LED」、「スリープ」の値を控えた値へ戻す。

## 記録

`"$B/result-logout-restart-crash-limit.txt"` に次を書く。

- 表の行ごとの設定と、ログイン後の状態
- `kern.boottime`、`lastUpdated`、`crashLaunches` の件数
- 3回のクラッシュでシグナルを送った PID と、起こし直された PID、各回の後のスリープ防止の状態
- 成功／失敗／判定不能、未実施の操作と理由、気づいたこと
