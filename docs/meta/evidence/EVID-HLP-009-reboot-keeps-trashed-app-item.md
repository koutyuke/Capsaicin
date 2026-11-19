---
schema: evidence
id: EVID-HLP-009
title: アプリの項目の URL がゴミ箱の中のコピーを指すとき、BTM はそのコピーを追い、再起動の後もアプリの項目と登録を外したデーモンの親は残った
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）。`EVID-HLP-008` の最後の状態から、Debug のアプリを起動せずに再起動した（起動は 2026-11-19 00:46:54）
sources: ["docs/meta/hypotheses/HYP-HLP-012-reboot-drops-missing-app-item.md"]
---

# EVID-HLP-009 アプリの項目の URL がゴミ箱の中のコピーを指すとき、BTM はそのコピーを追い、再起動の後もアプリの項目と登録を外したデーモンの親は残った

## 確かめた事実

再起動の後、ログインしてから PM が `sfltool dumpbtm` を読んだ（読み取りだけ）。

- UID -2 の記録のアプリの項目 `2.io.github.koutyuke.capsaicin.debug`（UUID `6254535B…`）は残っていた。URL は `/Users/501/.Trash/copy-b 00-39-54-782/Capsaicin.app` で、ゴミ箱へ移した実験2のコピー B の移動先を指していた。`Generation` は 360 から 361 になった。
- 試験用の2つのデーモンの項目（`…helper-del30405acdda`、`…helper-movfe691e6c6b`）は、どちらも `[disabled, allowed, not notified]` のまま、`Parent Identifier` は `2.io.github.koutyuke.capsaicin.debug` だった。`Last Use` は再起動の前の時刻のままだった。
- UID 0 の記録のアプリの項目は、`/bin/rm -rf` で消した実験1のコピー A の場所を指したまま残っていた。
- Capsaicin のプロセスはなく、`SleepDisabled` は 0 だった。

## 確かめ方

`sfltool dumpbtm` の出力を、再起動の前（`EVID-HLP-008` の最後）と比べた。

## 適用範囲

アプリのコピーがゴミ箱の中に残っていて、デーモンの登録を外してある場合に当てはまる。

## 未確認のこと

- コピーを完全に消した（ゴミ箱にもない）場合に、再起動でアプリの項目が消えるか。
- デーモンを登録したまま（`enabled`）で再起動した場合の振る舞い。`EVID-HLP-007` の親のない項目は、Mac の起動の約 50 秒後に使われていた。
