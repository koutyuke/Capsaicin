---
schema: evidence
id: EVID-LCY-001
title: launchd の KeepAlive の Crashed は、クラッシュによる終了のときだけジョブを再起動する
observed_on: 2026-11-06
environment: macOS 27.0.1（ビルド 26A434）、Mac16,8（Apple M4 Pro）
sources: ["/usr/share/man/man5/launchd.plist.5"]
---

# EVID-LCY-001 launchd の KeepAlive の Crashed は、クラッシュによる終了のときだけジョブを再起動する

## 確かめた事実

`launchd.plist` の man ページによると、`KeepAlive` の `Crashed` を `true` にすると、ジョブがクラッシュに伴うシグナル（`SIGILL`、`SIGSEGV` など）で終了した場合に限り、launchd がジョブを再起動する。`false` にすると逆の条件で再起動する。

## 確かめ方

`man launchd.plist | col -b` の `Crashed` の項を読んだ。

## 適用範囲

LaunchAgent でクラッシュ時だけアプリを再起動できることの根拠に使ってよい。

## 未確認のこと

- 同じ LaunchAgent でログイン時の起動を行う設定と組み合わせたときの挙動。
- ad-hoc 署名のアプリで同じように動くか。
