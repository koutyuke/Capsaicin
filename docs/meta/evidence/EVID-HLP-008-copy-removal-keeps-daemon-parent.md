---
schema: evidence
id: EVID-HLP-008
title: 登録したコピーを消しても動かしてもデーモンの項目は親を保ち、UID -2 にアプリの項目が作り直されると親のない古い項目は消えた
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、起動は 2026-11-18 14:30:57（`EVID-HLP-007` と同じ起動）。試作 `spike/daemon-cleanup-probe` の `d76d393` を、ヘルパーのラベルの接尾辞 `del30405acdda`（実験1）と `movfe691e6c6b`（実験2）でビルドし、Developer ID Application で署名し直した Debug ビルド
sources: ["docs/meta/hypotheses/HYP-HLP-011-daemon-item-orphaned-by-copy-removal.md"]
---

# EVID-HLP-008 登録したコピーを消しても動かしてもデーモンの項目は親を保ち、UID -2 にアプリの項目が作り直されると親のない古い項目は消えた

## 確かめた事実

オーナーと、検証を手伝うエージェント（別スレッド）が `helper-orphan-reproduction.md` を実施した。記録は Git の外の退避先にあり、段階ごとの `sfltool dumpbtm` の全体を PM が読み比べた。

- 実験1: コピー A から新しいラベルのヘルパーを登録すると、UID -2 の記録にデーモンの項目（UUID `D9746666…`）ができ、`Parent Identifier` は `2.io.github.koutyuke.capsaicin.debug` だった。ヘルパーは起動し、`SleepDisabled` は `0→1→0` になった。A を終了し、`/bin/rm -rf` で消した後も、コピー B を起動して使った後も、B で登録を外して登録し直した後も、UUID と親は変わらなかった。B からヘルパーは起動し、launchd に `Invalid path` はなかった。登録を外すと項目は `disabled` で残った。
- 実験2: 別のラベルで同じことを行い、A を消す代わりに `mv` で動かした。動かした A からも B からもヘルパーは起動し、UUID（`02591B2E…`）と親は最後まで変わらなかった。
- 登録の前（実験1の A の起動直後）、UID -2 の記録には Capsaicin のアプリの項目がなく、親のないデーモンの項目（UUID `02441BE8…`、`16.io.github.koutyuke.capsaicin.debug.helper`、`Generation: 64`、親 `Unknown Developer`）だけがあった（`EVID-HLP-007` と同じ項目）。
- 新しいラベルを登録して動かした後、UID -2 にアプリの項目 `2.io.github.koutyuke.capsaicin.debug`（UUID `6254535B…`、UID 501 のアプリの項目と同じ UUID）が現れ、agent と新しいデーモンを内包していた。同時に、親のない古い項目 `02441BE8…` は記録から消え、最後まで現れなかった。古いラベルの登録や `sfltool resetbtm` は行っていない。
- UID -2 のアプリの項目は、コピーを消しても、動かしても、登録を外しても残った。項目の URL は、最後に使ったコピーの場所に書き換わった。最後の記録では、UID -2 のアプリの項目の URL は、ゴミ箱へ移した実験2のコピー B を指していた。UID 0 の記録にも同じ識別子のアプリの項目があり、URL は消した実験1のコピー A のままだった。

## 確かめ方

PM が、各段階の `btm.*.txt` から Capsaicin の項目（アプリ、agent、デーモン）を UID ごとに抜き出し、UUID、`Disposition`、`Generation`、`Parent Identifier`、URL、内包する項目を比べた。

## 適用範囲

アプリが動いている間と、Mac の再起動をまたがない範囲の操作に当てはまる。

## 未確認のこと

- UID -2 のアプリの項目が、いつ、どの操作で消えたか。`EVID-HLP-007` の親のない項目の最後の使用は、Mac の起動の約 50 秒後（14:31:46）だった。
- 古いラベル（`.helper`）を今登録すると、ヘルパーが起動するか。
- 試作の実験では、操作のいくつかをメニューではなく CLI（`capsaicin on` と `off`）で行い、実験の最後のコピーは `/bin/rm -rf` ではなくゴミ箱へ移した。どちらも、上の観測の判定には影響しない。
