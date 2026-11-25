# CLI の不正な引数と、CLI を許可しない設定

CLI が不正な引数を使い方の誤りとして拒んで開始しないことと、「CLIからの操作を許可」がオフのときは要求を拒んで状態を変えないことを確かめる。確かめる仕様は `SPEC-CLI-001`、`SPEC-CLI-005`、`SPEC-CLI-007` である。

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

アプリが動いていなければ起動し、メニューでスリープ防止がオフであることを確かめる。設定の「操作」の「CLIからの操作を許可」の値を `"$B/result-cli-invalid-input.txt"` に控え、オンにする。

```sh
just start
just status
```

## 操作と期待

1. 次を1つずつ実行する。

   ```sh
   "$CLI" on --for 0m
   printf 'exit=%s\n' "$?"
   "$CLI" on --until 24:00
   printf 'exit=%s\n' "$?"
   "$CLI" on --for 1m --until 4:00
   printf 'exit=%s\n' "$?"
   "$CLI" on --for 1m --for 2m
   printf 'exit=%s\n' "$?"
   "$CLI" on --for 1m --no-time-limit
   printf 'exit=%s\n' "$?"
   "$CLI" on --no-time-limit 1h
   printf 'exit=%s\n' "$?"
   "$CLI" status
   printf 'exit=%s\n' "$?"
   ```

   期待: 6つとも、標準エラーに `error:` で始まる英語の理由と、続く行に `--help` の案内を出し、終了コード `64` で開始しない。最後の `status` は終了コード `1` である。

2. メニューの「スリープ防止をオンにする」で開始し、設定の「操作」で「CLIからの操作を許可」をオフにする。

   ```sh
   "$CLI" off
   printf 'exit=%s\n' "$?"
   ```

   期待: 標準エラーにエラーを出し、終了コード `69` で、スリープ防止中のままである。

3. メニューを開いて状態を見る。「CLIからの操作を許可」をオンに戻して解除する。

   ```sh
   "$CLI" off
   printf 'exit=%s\n' "$?"
   ```

   期待: 操作2の後もメニューはスリープ防止中を示す。オンに戻すと、終了コード `0` で解除できる。

## 中止するとき

不正な入力で開始した、拒んだはずの `off` が状態を変えた場合は止める。「CLIからの操作を許可」をオンに戻し、メニューの「スリープ防止をオフにする」で解除して状態を記録する。

```sh
just status
```

## 元に戻す

「CLIからの操作を許可」をオンに戻し、メニューの「スリープ防止をオフにする」で解除する。最後に控えた値へ戻す。シンボリックリンクやエイリアスは作らない。

## 記録

`"$B/result-cli-invalid-input.txt"` に次を書く。

- 6つの不正な入力それぞれの標準エラーと終了コード
- 拒んだ後のスリープ防止の状態、操作3で解除できたこと
- 成功／失敗／判定不能、未実施の操作と理由、気づいたこと
