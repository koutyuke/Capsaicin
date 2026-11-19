# キー配列を変更するアプリの案内が出て、終了すると消える

Karabiner-Elements が動いている間だけ設定の「フィードバック」に案内が出て、終了すると10秒以内に消えることを確かめる。確かめる仕様は `SPEC-LED-005` である。

Karabiner-Elements が動いているときの LED の振る舞いとルールの成否は確かめ済みである（`EVID-LED-009`、`EVID-LED-012`）。Sidecar の仮想キーボードだけでは案内が出ないことも確かめ済みである（`EVID-LED-015`）。この手順では、残っている案内の出し入れだけを見る。

この手順はこのファイルだけで完結する。最初の1回の準備（[`prepare.md`](prepare.md)）を除き、ほかの検証ファイルの手順は行わない。共通の決まりは [`README.md`](README.md) にある。

## 始める前に

- 準備（`prepare.md`）を終え、退避先 `B` の絶対パスを控えている。
- Karabiner-Elements を既に使える検証環境である。新たなインストールや設定の変更はこの手順に含めない。
- Karabiner-Elements の稼働状態を `"$B/result-led-remapper.txt"` に控える。

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

## 操作と期待

1. Karabiner-Elements が動作中に、メニューの「設定…」で設定の「フィードバック」を開いて案内を撮る。

   期待: 「キー配列を変更するアプリが動作中」の行があり、(i) に「そのアプリがCaps LockのLEDを制御している場合、スリープ防止中もLEDが点灯しないことがあります。」が出る。

2. 設定の「フィードバック」を開いたまま、Karabiner-Elements をメニューバーから終了する（「Quit Karabiner-Elements」）。案内が消えるまでの秒数を数える。

   期待: 終了後10秒以内に案内が消える。過去の確認では、Karabiner-Elements のアプリを閉じても常駐プロセスが残る間は案内が出続けた（`EVID-LED-009`）。メニューバーからの終了で常駐プロセスまで止まったかを、次で確かめる。

   ```sh
   /bin/ps -axo pid,comm | /usr/bin/grep -i '[k]arabiner'
   ```

## 中止するとき

案内が出ない、終了後も消えない場合は止める。Karabiner-Elements の常駐プロセスが残っているかを記録する。

```sh
/bin/ps -axo pid,comm | /usr/bin/grep -i '[k]arabiner'
```

## 元に戻す

Karabiner-Elements の稼働状態を控えた状態へ戻す。

## 記録

`"$B/result-led-remapper.txt"` に次を書く。

- 設定の「フィードバック」の案内と画面写真の絶対パス
- 案内が消えるまでの秒数、終了後に残った Karabiner-Elements のプロセス
- Karabiner-Elements の稼働状態の前後
- 成功／失敗／判定不能、未実施の操作と理由、気づいたこと
