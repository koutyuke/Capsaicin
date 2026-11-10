---
schema: evidence
id: EVID-HLP-002
title: パスを指定しない visudo -c は読み込む全ファイルのモードを検査し、sudo 本体より厳しい
observed_on: 2026-11-07
environment: macOS 27.0.1（ビルド 26A434）、sudo 1.9.17p2、nix-darwin と Amphetamine を入れた開発機
sources: ["/usr/share/man/man8/visudo.8", "https://raw.githubusercontent.com/sudo-project/sudo/main/plugins/sudoers/visudo.c", "https://raw.githubusercontent.com/sudo-project/sudo/main/lib/util/secure_path.c"]
---

# EVID-HLP-002 パスを指定しない visudo -c は読み込む全ファイルのモードを検査し、sudo 本体より厳しい

## 確かめた事実

`visudo -c` は、sudoers のパスを指定しないと、書式に加えて所有者とモードも検査する（man の `-c` と `-P` の項）。ソースの `check_syntax` は、sudoers 本体に加えて読み込んだファイル（`sudoerslist`）ごとに `check_file` を呼ぶ。所有者が root:wheel でないか、モードが 0440 でないファイルが1つでもあれば失敗する。`-f` でパスを指定すると、所有者とモードの検査は `-O` と `-P` を付けたときだけになる。

sudo 本体がファイルを拒むのは、所有者が違うか、他人が書き込めるか、別のグループが書き込めるときだけである（`sudo_check_secure`）。0644 や 0444 の root 所有のファイルは、sudo 本体は読むが、パスを指定しない `visudo -c` では失敗になる。

開発機の `/etc/sudoers.d` には、Amphetamine の `amphetamine_PowerProtect`（0644）と、nix-darwin の `10-nix-darwin-extra-config`（0444 のファイルへの symlink）がある。この開発機では、ヘルパーの設置と削除が次のように止まっていた。

- 18:35:12 の設置: ヘルパーの実行ファイルは置かれたが、`/Library/LaunchDaemons` は更新されていない。sudoers のルールを置いてから LaunchDaemon を書くまでの間で止まっており、その間にある処理は `visudo -c` だけである。
- 18:35:27 の削除: `/etc/sudoers.d` だけが更新され、ヘルパーの実行ファイルは残った。sudoers のルールを消した直後の `visudo -c` で止まっている。
- どちらも直前に `authd` が `system.privilege.admin` の認証の成功を記録しており、認証は通っている。

## 確かめ方

- `man visudo | col -b` の `-c` と `-P` の項を読んだ。
- sudo のソースの `plugins/sudoers/visudo.c`（`check_syntax`、`check_file`、`main` の既定値）と `lib/util/secure_path.c`（`sudo_check_secure`）を読んだ。
- `stat -L -f '%Sp %Su:%Sg %N' /etc/sudoers.d/*` でモードを見た。
- `stat -f '%Sm %N' -t '%H:%M:%S'` で設置先の更新時刻を見た。`/usr/bin/log show` で、Capsaicin の `Helper` のエラーと `authd` の認証結果の時刻を見た。

一般ユーザーが所有する一時ディレクトリで `#includedir` を使う実験は、sudo が root 以外の所有するディレクトリを読み込まないため、この検査の再現には使えなかった。root での `visudo -c` は実行していない。

## 適用範囲

設置と削除の処理で、パスを指定しない `visudo -c` を使わない判断の根拠に使ってよい。`visudo -c -f <ファイル>` で、1つのファイルの書式を検証することの妥当性は `EVID-HLP-001` が持つ。

## 未確認のこと

- 開発機で root として `visudo -c` を実行したときの実際の出力。設置の失敗の詳細はログで `<private>` になっている。
