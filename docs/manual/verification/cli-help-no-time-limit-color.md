# CLI のヘルプ、--no-time-limit、色を付けない出力

`--help` と `-h` がアプリを起動せずに使い方を出すこと、`--no-time-limit` が設定の「タイマーで自動解除」と「指定時刻に自動解除」を使わずに開始し、抑止中に使うと解除の時刻をなくすこと、パイプと `NO_COLOR` で色を付けないことを確かめる。確かめる仕様は `SPEC-CLI-001`、`SPEC-CLI-003`、`SPEC-CLI-007`、`SPEC-CLI-008` である。

この手順はこのファイルだけで完結する。最初の1回の準備（[`prepare.md`](prepare.md)）を除き、ほかの検証ファイルの手順は行わない。共通の決まりは [`README.md`](README.md) にある。

## 始める前に

- 準備（`prepare.md`）を終え、退避先 `B` の絶対パスを控えている。

リポジトリのルートで devShell に入る。

```sh
cd <リポジトリのルート>
nix develop
```

devShell の中で退避先を入れ、足場を確かめる。`OK` が出なければ、退避先かチェックアウトが違うので止める。試験する CLI のパスも入れる。

```sh
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
CLI="$PWD/.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/Helpers/capsaicin"
just status
```

アプリが動いていなければ起動し、メニューでスリープ防止がオフであることを確かめる。

```sh
just start
just status
```

設定の次の値を `"$B/result-cli-help-no-time-limit-color.txt"` に控えてから変える。

- 「操作」の「CLIからの操作を許可」をオンにする。
- 「スリープ」の「ディスプレイを閉じたとき」を「Macをスリープ（標準）」にする（MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオフ）。「バッテリー残量が少ないときに自動解除」をオフにする。「タイマーで自動解除」と「指定時刻に自動解除」のオン・オフと値を控える。
- 「フィードバック」の「スリープ防止中にCaps LockのLEDを点灯」をオフにする。

メニューの「Capsaicinを終了」でアプリを終了する。

```sh
just status
```

## 操作と期待

1. アプリが動いていないまま、ヘルプを出す。前後のプロセスの検索で、アプリが起動しないことを見る。

   ```sh
   /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
   "$CLI" --help
   printf 'exit=%s\n' "$?"
   /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
   "$CLI" -h
   printf 'exit=%s\n' "$?"
   /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
   ```

   期待: 説明、書式、サブコマンド、`on` のオプション、終了コードが英語で標準出力に出て、終了コードはどちらも `0` である。プロセスの検索ではアプリが見つからない。

2. アプリを起動する。設定の「タイマーで自動解除」をオンにして「継続時間」を1分、「指定時刻に自動解除」をオンにして2分後の時刻にする。次を実行し、2分待ってから `status` をもう一度実行する。

   ```sh
   just start
   "$CLI" on --no-time-limit
   printf 'exit=%s\n' "$?"
   "$CLI" status
   printf 'exit=%s\n' "$?"
   ```

   2分待ってから実行する。

   ```sh
   "$CLI" status
   printf 'exit=%s\n' "$?"
   ```

   期待: 終了コード `0` で時間の条件なしにスリープ防止を開始し、2分後もスリープ防止中である。時間の条件がないときに何を伝えるかは `SPEC-CLI-003` に従う。

3. 抑止中に時間を付けてから、条件をなくす。

   ```sh
   "$CLI" on --for 1m
   printf 'exit=%s\n' "$?"
   "$CLI" status
   printf 'exit=%s\n' "$?"
   "$CLI" on --no-time-limit
   printf 'exit=%s\n' "$?"
   "$CLI" status
   printf 'exit=%s\n' "$?"
   ```

   1分待ってから実行する。

   ```sh
   "$CLI" status
   printf 'exit=%s\n' "$?"
   ```

   期待: 最初の `status` に解除の時刻と残り時間が出て、`--no-time-limit` の後は解除の時刻がなくなる。いずれも終了コード `0` で、1分後もスリープ防止中である。

4. スリープ防止中に次を実行し、エスケープシーケンスを表す `^[` が出力に混ざらないかを見る。`cat -v` による記号の変換と、エスケープシーケンスを区別する。

   ```sh
   "$CLI" status | cat -v
   NO_COLOR=1 "$CLI" status
   NO_COLOR=1 "$CLI" status | cat -v
   ```

   期待: パイプと `NO_COLOR=1` のどちらでも色が付かず、`cat -v` を通した出力に `^[` が出ない。`NO_COLOR=1` はそのコマンドだけに付け、シェルの設定は変えない。

## 中止するとき

ヘルプでアプリが起動した、Release が起動した、`--no-time-limit` でも解除の時刻が残る、待っている間に解除された、色の出力が期待と違う場合は止める。出力を残して解除する。

```sh
"$CLI" off
printf 'exit=%s\n' "$?"
just status
```

## 元に戻す

`"$CLI" off` か、メニューの「スリープ防止をオフにする」で解除する。「タイマーで自動解除」と「指定時刻に自動解除」を控えた値とオン・オフへ戻し、ほかの設定も控えた値へ戻す。シンボリックリンクやエイリアスは作らない。

```sh
"$CLI" off
printf 'exit=%s\n' "$?"
```

## 記録

`"$B/result-cli-help-no-time-limit-color.txt"` に次を書く。

- ヘルプの標準出力・標準エラー・終了コードと前後のプロセス
- 操作2と操作3の出力・終了コード・待った後の状態
- 操作4の端末と `cat -v` の出力、戻した設定
- 成功／失敗／判定不能、未実施の操作と理由、気づいたこと
