---
schema: evidence
id: EVID-HLP-001
title: visudo -c は sudoers の書式を検証し、sudoers.d は「.」を含むファイル名を読まない
observed_on: 2026-11-06
environment: macOS 27.0.1（ビルド 26A434）、Mac16,8（Apple M4 Pro）
sources: ["/usr/share/man/man8/visudo.8", "/usr/share/man/man5/sudoers.5"]
---

# EVID-HLP-001 visudo -c は sudoers の書式を検証し、sudoers.d は「.」を含むファイル名を読まない

## 確かめた事実

`visudo` の man ページによると、`-c`（`--check`）は検証だけを行うモードで、sudoers とそれが読み込むファイルの書式の誤りを調べる。検証に成功すると終了コード 0、誤りがあると 1 を返す。`-f` で検証するファイルを指定できる。

`sudoers` の man ページによると、sudo は `/etc/sudoers.d` のファイルを読むとき、名前が `~` で終わるものと `.` を含むものを読み飛ばす。

## 確かめ方

`man visudo | col -b` の `-c, --check` と `-f` の項と、`man sudoers | col -b` の `/etc/sudoers.d` を読み込む規則の項を読んだ。

## 適用範囲

sudoers のルールを、読み込まれない一時名で書いて検証してから置く方法の根拠に使ってよい。

## 未確認のこと

- `/etc/sudoers.d/` に置いたファイルの書式の誤りで sudo 全体が使えなくなること（移行元の記述。この根拠では確かめていない）。
