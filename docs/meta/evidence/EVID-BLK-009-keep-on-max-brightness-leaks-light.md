---
schema: evidence
id: EVID-BLK-009
title: 「オンのまま」で最大輝度のままディスプレイを閉じると、ディスプレイの隙間から光が漏れた
observed_on: 2026-11-12
environment: macOS 27.2.1（26B131）、Mac16,8（Apple M4 Pro）、外部ディスプレイなし、電池駆動、暗い部屋、Capsaicin の Debug ビルド 0.1.0（1）で抑止中（SleepDisabled 1、「ディスプレイを閉じたとき」は「オンのまま」、「ディスプレイを自動でオフにしない」はオン）、自動輝度調節と True Tone はオフ
sources: ["e9e7e3d:scripts/manual/display-brightness.swift", "e9e7e3d:docs/manual/lid-close-dimming-verification.md", "~/Capsaicin-dimming.B7nQAG/C2-max.log", "~/Capsaicin-dimming.B7nQAG/C2-observation.txt", "~/Capsaicin-dimming.B7nQAG/initial-settings.txt"]
---

# EVID-BLK-009 「オンのまま」で最大輝度のままディスプレイを閉じると、ディスプレイの隙間から光が漏れた

## 確かめた事実

`e9e7e3d:docs/manual/lid-close-dimming-verification.md` の C2 のうち、最大輝度の回だけを行った。光はオーナーの目視による。

- 明るさのキーで輝度を最大（DisplayServices の読み取りで `1.0`）にし、14:46:27 から 14:49:46 まで（199秒）ディスプレイを閉じた。閉じている間、ディスプレイの隙間から光が見えた。
- 閉じている間の10秒ごとの読み取り20回は、すべて `AppleClamshellState=1`、`CGDisplayIsActive=1`、`CGDisplayIsAsleep=0`、`brightness=1.0` だった。
- 機体全体の放電電流の平均は、閉じている間が -2094 mA（20回）、同じ回の開いている間が -2158 mA（14回）だった。閉じても、電流ははっきりとは下がらなかった。負荷はそろえていない。

時刻は日本時間である。

## 確かめ方

手順は `e9e7e3d:docs/manual/lid-close-dimming-verification.md` の準備と C2 の操作1〜2。記録は `~/Capsaicin-dimming.B7nQAG/` にある。閉じていた区間と電流は、`C2-max.log` の `event=close` から `event=open` までの `timer` の行を読んだ。

## 適用範囲

「オンのまま」でディスプレイを閉じると、最大輝度では隙間から光が漏れることの根拠に使ってよい。

## 未確認のこと

- 光源が内蔵ディスプレイのバックライトか。輝度を下げて閉じたときとの比較をしていないので、キーボードのバックライトなどの光と区別できていない（`HYP-BLK-010`）。
- 最大より低い普段の輝度で、どれだけ光が漏れるか。
- 輝度による電力の差。負荷をそろえた比較（C5）はしていない。
