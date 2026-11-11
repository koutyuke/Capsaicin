---
schema: evidence
id: EVID-BLK-008
title: 抑止中に蓋を閉じても内蔵ディスプレイはスリープせず、レジストリのバックライトの値も変わらない
observed_on: 2026-11-11
environment: macOS 27.2.1（ビルド 26B131）、Mac16,8（Apple M4 Pro）、外部ディスプレイなし、電池駆動、Capsaicin で抑止中（SleepDisabled 1、Capsaicin のディスプレイスリープを止めるアサーションあり）
sources: []
---

# EVID-BLK-008 抑止中に蓋を閉じても内蔵ディスプレイはスリープせず、レジストリのバックライトの値も変わらない

## 確かめた事実

Capsaicin で抑止して蓋を閉じた Mac の上でエージェントが作業を続けていた間に、一般ユーザーの権限で次を読んだ。

- 蓋を閉じた状態（`AppleClamshellState` が `true`）で、内蔵ディスプレイは `CGDisplayIsActive` が `1`、`CGDisplayIsAsleep` が `0` だった。オンラインのディスプレイは内蔵の1台だけだった。
- 同じとき、`pmset -g` は `SleepDisabled 1` を示し、`sleep` と `displaysleep` の行に Capsaicin による抑止が表示されていた。`AppleClamshellCausesSleep` は `true` だった。
- `AppleARMBacklight` の `IODisplayParameters` は、蓋を閉じていたときと、約10分後に蓋を開けていたときとで同じ値だった。`BrightnessMilliNits` は `381794`、`brightness` は `32768`、`BrightnessMicroAmps` は `3199` だった。

## 確かめ方

蓋を閉じた状態の値は、`EVID-BLK-007` の試作プログラムと次のコマンドで読んだ。蓋を開けた後に同じコマンドで読み直した。

```sh
ioreg -rn IOPMrootDomain -d1 | grep -E '"AppleClamshell(State|CausesSleep)"'
ioreg -rn AppleARMBacklight -d1 | grep -o '"IODisplayParameters" = .*'
pmset -g
```

## 適用範囲

抑止中に蓋を閉じても、内蔵ディスプレイが CoreGraphics から見て描画できる状態に残ることの根拠に使ってよい。レジストリの `IODisplayParameters` が輝度の設定値を示すだけで、蓋を閉じたときのバックライトの実際の状態を示さないことの根拠に使ってよい。

## 未確認のこと

- 閉じた蓋の中でバックライトが実際に光っているか（`HYP-BLK-010`）。
- `disablesleep` だけで、ディスプレイスリープを止めるアサーションがない場合も同じになるか。
- 「ディスプレイを閉じたとき」の保存値。観測の時点で「オンのまま」だったことは記録していない。
