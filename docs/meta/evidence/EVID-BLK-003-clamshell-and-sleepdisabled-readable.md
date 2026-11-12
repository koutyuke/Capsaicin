---
schema: evidence
id: EVID-BLK-003
title: 一般ユーザーの権限で AppleClamshellState と SleepDisabled を読める
observed_on: 2026-11-06
environment: macOS 27.0.1（ビルド 26A434）、Mac16,8（Apple M4 Pro）、ディスプレイは開いた状態
sources: []
---

# EVID-BLK-003 一般ユーザーの権限で AppleClamshellState と SleepDisabled を読める

## 確かめた事実

- 一般ユーザーの権限で `ioreg` を実行すると、`AppleClamshellState`（値 `No`）と `AppleClamshellCausesSleep`（値 `No`）を読めた。
- 一般ユーザーの権限で `pmset -g` を実行すると、「System-wide power settings」に `SleepDisabled` の値を読めた。観測した時点の値は `1` で、Capsaicin の試作とは関係なく既に設定されていた。

## 確かめ方

```sh
ioreg -r -k AppleClamshellState -d1 -w0 | grep -oE '"AppleClamshell(State|CausesSleep)" = [A-Za-z]+'
pmset -g
```

## 適用範囲

ディスプレイの開閉状態と `disablesleep` の状態を、root なしで読めることの根拠に使ってよい。試験の手順で `SleepDisabled` を確かめる方法として使ってよい。

## 未確認のこと

- ディスプレイの開閉の変化を通知で検知できるか（`HYP-BLK-008`）。
- `AppleClamshellCausesSleep` が `No` だった理由（`SleepDisabled 1` によるものかは確かめていない）。
