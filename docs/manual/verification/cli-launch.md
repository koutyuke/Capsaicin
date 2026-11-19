# 停止したアプリを CLI から起動し、出力と終了コードを見る

アプリが動いていなくても `capsaicin on` がアプリを起動して開始できることと、出力・終了コード・ソケットの所有者を確かめる。確かめる仕様は `SPEC-CLI-001`、`SPEC-CLI-002`、`SPEC-CLI-003`、`SPEC-CLI-004`、`SPEC-CLI-006`、`SPEC-CLI-007` である。

この手順はこのファイルだけで完結する。最初の1回の準備（[`prepare.md`](prepare.md)）を除き、ほかの検証ファイルの手順は行わない。共通の決まりは [`README.md`](README.md) にある。

終了コードの意味は次のとおりである。

| 終了コード | 意味 |
| --- | --- |
| `0` | 成功。開始、解除、状態の取得ができた |
| `1` | `status` でスリープ防止がオフ |
| `64` | 使い方の誤り（引数の形が違う） |
| `69` | 要求を完了できなかった。アプリに接続できないときもこれ |

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

設定の次の値を `"$B/result-cli-launch.txt"` に控えてから変える。

- 「操作」の「CLIからの操作を許可」をオンにする。
- 「スリープ」の「ディスプレイを閉じたとき」を「Macをスリープ（標準）」にする（MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオフ）。「タイマー」「指定時刻」「残量が少なくなったらオフにする」をオフにする。
- 「LED」の「スリープ防止中にCaps LockのLEDを点灯」をオフにする。

設定の「操作」の「コマンドの場所」のパスをコピーし、`$CLI` と同じ絶対パスかを比べる。

```sh
printf '%s\n' "$CLI"
```

メニューの「Capsaicinを終了」でアプリを終了する。

```sh
just status
```

## 操作と期待

1. 1コマンドずつ実行し、出力を記録する。`set -e` は使わない。

   ```sh
   "$CLI" on --for 1m
   printf 'exit=%s\n' "$?"
   ```

   期待: その CLI を含む Debug アプリが起動し、終了コード `0` でスリープ防止を開始する。出力は英語で、結果の行に続けて解除の条件が出る。解除の時刻はローカルの24時間制で、残り時間を伴う（`SPEC-CLI-003`）。CLI の操作では HUD が出ない。

2. 状態を読む。

   ```sh
   "$CLI" status
   printf 'exit=%s\n' "$?"
   ```

   期待: 終了コード `0` で、状態の行に続けて解除の条件が出る。

3. 時間を置き換える。

   ```sh
   "$CLI" on --for 2m
   printf 'exit=%s\n' "$?"
   ```

   期待: 終了コード `0` で、要求を受けた時点から2分後に解除の時刻を置き換え、置き換えたことと新しい解除の条件を伝える。

4. 解除して状態を読む。

   ```sh
   "$CLI" off
   printf 'exit=%s\n' "$?"
   "$CLI" status
   printf 'exit=%s\n' "$?"
   ```

   期待: `off` は終了コード `0`、`status` は終了コード `1` で、解除の条件の行が出ない。

5. ソケットを読む。

   ```sh
   /bin/ls -ld "/private/tmp/io.github.koutyuke.capsaicin-$(id -u)"
   /bin/ls -l "/private/tmp/io.github.koutyuke.capsaicin-$(id -u)/ipc.debug.sock"
   ```

   期待: 親ディレクトリはこのユーザーの所有で 700 である。Debug のソケットは `ipc.debug.sock` である。

## 中止するとき

Release が起動する、接続に失敗する、ソケットの所有者が違う場合は止める。ソケットの権限を変えて回避しない。解除して状態を記録する。

```sh
"$CLI" off
printf 'exit=%s\n' "$?"
just status
```

## 元に戻す

`"$CLI" off` か、メニューの「スリープ防止をオフにする」で解除する。設定を控えた値へ戻す。ソケットの共有ディレクトリは消さない。

```sh
"$CLI" off
printf 'exit=%s\n' "$?"
```

## 記録

`"$B/result-cli-launch.txt"` に次を書く。

- 各コマンドの標準出力・標準エラー・終了コード
- 操作1でアプリが起動したか、HUD が出なかったか
- 「コマンドの場所」と `$CLI` が一致したか、ソケットの所有者と権限
- 成功／失敗／判定不能、未実施の操作と理由、気づいたこと
