# 設定ごとのアサーション

スリープ防止中は自動スリープを止めるアサーションが常にあり、「ディスプレイを自動でオフにしない」がオンのときだけ画面の消灯も止めることを確かめる。確かめる仕様は `SPEC-BLK-001` である。

この手順はこのファイルだけで完結する。最初の1回の準備（[`prepare.md`](prepare.md)）を除き、ほかの検証ファイルの手順は行わない。共通の決まりは [`README.md`](README.md) にある。

## 始める前に

- 準備（`prepare.md`）を終え、退避先 `B` の絶対パスを控えている。
- 電源アダプターをつなぐ。

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

アプリが動いていなければ起動する。

```sh
just start
just status
```

メニューの「設定…」で設定を開き、「スリープ」の次の値を `"$B/result-assertions.txt"` に控えてから変える。

- 「ディスプレイを閉じたとき」を「システムスリープ（標準）」にする。MacBook 以外の Mac では「メニューからのスリープも防ぐ」をオフにする。
- 「スリープ防止の自動解除」の「タイマー」と「指定時刻」をオフにする。
- 「バッテリー」の「残量が少なくなったらオフにする」をオフにする（内蔵バッテリーのある Mac だけ）。

画面消灯までの既存の時間も控える。

```sh
/usr/bin/pmset -g custom | /usr/bin/grep -i displaysleep
```

## 操作と期待

1. 「ディスプレイを自動でオフにしない」をオフにし、メニューの「スリープ防止をオンにする」で開始する。
2. アサーションを読み、Capsaicin の行を写す。

   ```sh
   /usr/bin/pmset -g assertions | /usr/bin/grep -i -A2 capsaicin
   ```

   期待: `Capsaicin` の `PreventUserIdleSystemSleep` があり、`PreventUserIdleDisplaySleep` はない。

3. メニューの「スリープ防止をオフにする」で解除する。「ディスプレイを自動でオフにしない」をオンにし、もう一度開始して同じコマンドを実行する。

   ```sh
   /usr/bin/pmset -g assertions | /usr/bin/grep -i -A2 capsaicin
   ```

   期待: `PreventUserIdleSystemSleep` と `PreventUserIdleDisplaySleep` の両方がある。

4. 「スリープ防止をオフにする」で解除し、同じコマンドを実行する。

   ```sh
   /usr/bin/pmset -g assertions | /usr/bin/grep -i -A2 capsaicin
   ```

   期待: Capsaicin のアサーションがない。別のアプリのアサーションは消さない。

5. ほかのアプリの行は `just status` に出ないので、全体を読んで数だけ数える。

   ```sh
   /usr/bin/pmset -g assertions
   ```

6. アサーションがあるだけでは、実際のスリープ抑止の合格にしない。「ディスプレイを自動でオフにしない」をオフにして開始し、控えた画面消灯までの時間を超えて操作せずに待つ。次にオンにして同じだけ待つ。

   期待: オフなら画面が消灯し、オンなら消灯しない。OS 側の自動スリープの条件を特定できない場合、実際の自動スリープは判定不能とする。`pmset` のタイマー設定は変更しない。

## 中止するとき

開始が拒否される、解除後もアサーションが残る場合は止める。メニューで解除し、アプリを終了して残りを確かめる。

```sh
just stop
just status
```

`just status` に Capsaicin のアサーションが残っていれば、それ以上操作せず PM に報告する。

## 元に戻す

メニューの「スリープ防止をオフにする」で解除する。「スリープ」の各設定を、始める前に控えた値へ戻す。

## 記録

`"$B/result-assertions.txt"` に次を書く。

- 各段階の Capsaicin の行を丸ごと（アサーションの種類と数を後から比べるため）。ほかのアプリの行は数だけ
- 画面消灯までの時間と、操作6で消灯したかどうか
- 戻した設定
- 成功／失敗／判定不能、未実施の操作と理由、気づいたこと
