---
schema: evidence
id: EVID-SYS-001
title: Homebrew の公式 Cask は Gatekeeper の検査に通ることを求める
observed_on: 2026-11-06
environment: Web 上の文書（Homebrew Documentation）
sources: ["https://docs.brew.sh/Acceptable-Casks"]
---

# EVID-SYS-001 Homebrew の公式 Cask は Gatekeeper の検査に通ることを求める

## 確かめた事実

Homebrew の「Acceptable Casks」の「Platform compatibility and macOS security protections」の節は、macOS では Gatekeeper が評価できるアプリやインストーラーが Homebrew の Gatekeeper の検査に通ること、System Integrity Protection や Gatekeeper の無効化や回避を必要としないことを求めている。

## 確かめ方

https://docs.brew.sh/Acceptable-Casks を読んだ。

## 適用範囲

公式 Cask への掲載条件の根拠に使ってよい。

## 未確認のこと

- この文書は「署名」や「公証」という言葉を使っていない。公証していないアプリが Homebrew の Gatekeeper の検査に落ちることは、Gatekeeper が公証のないアプリを止めること（`EVID-SYS-002`）からの推論であり、実際に検査を通して確かめてはいない。
