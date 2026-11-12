---
schema: evidence
id: EVID-BLK-011
title: 輝度 0 でディスプレイを閉じたまま11分置いても、ディスプレイはスリープせず、ロックされず、画面収録に時計が写り続けた
observed_on: 2026-11-12
environment: macOS 27.2.1（26B131）、Mac16,8（Apple M4 Pro）、外部ディスプレイなし、電池駆動、Capsaicin の Debug ビルド 0.1.0（1）で抑止中（SleepDisabled 1、「ディスプレイを閉じたとき」は「オンのまま」、「ディスプレイを自動でオフにしない」はオン）、自動輝度調節と True Tone はオフ、パスワードの要求は「すぐに」、スクリーンセーバーは5分後、ディスプレイの消灯は10分後
sources: ["e9e7e3d:scripts/manual/display-brightness.swift", "e9e7e3d:docs/manual/lid-close-dimming-verification.md", "~/Capsaicin-dimming.B7nQAG/C4-dim.log", "~/Capsaicin-dimming.B7nQAG/C4-observation.txt", "~/Capsaicin-dimming.B7nQAG/C4-clock-samples.png", "~/Capsaicin-dimming.B7nQAG/画面収録 2026-11-12 14.59.43.mov", "~/Capsaicin-dimming.B7nQAG/initial-settings.txt"]
---

# EVID-BLK-011 輝度 0 でディスプレイを閉じたまま11分置いても、ディスプレイはスリープせず、ロックされず、画面収録に時計が写り続けた

## 確かめた事実

`e9e7e3d:docs/manual/lid-close-dimming-verification.md` の C4 のうち、輝度 0 の回を行った。ロック画面の有無はオーナーの目視による。

- 補助（`watch --dim`）が閉じた通知で輝度を 0 にし、15:00:32 から 15:11:46 まで（11分14秒）ディスプレイを閉じた。パスワードの要求（すぐに）、スクリーンセーバー（5分）、ディスプレイの消灯（10分）の時間をすべて過ぎた。
- 閉じている間の10秒ごとの読み取り67回は、すべて `CGDisplayIsActive=1`、`CGDisplayIsAsleep=0`、`brightness=0.0` だった。
- ディスプレイを開いたとき、ロック画面は出なかった。
- 画面収録は、画面上のストップウォッチを囲む範囲（856×316）を、14:59:43 から12分11.8秒間 QuickTime Player で収録した。閉じていた区間は、収録の0:49〜12:03に当たる。
  - 収録の1:00、6:30、11:50では、ストップウォッチは順に02:33.71、08:03.75、13:23.74を示した。収録の経過時間と同じだけ進んでいた。
  - 41,224フレームの間隔は最大0.05秒だった。
  - 0.5秒以上続く黒い画面と、1秒以上続く静止した画面は、収録の全体で見つからなかった。PM が `ffmpeg` で解析し直しても同じだった。

時刻は日本時間である。

## 確かめ方

手順は `e9e7e3d:docs/manual/lid-close-dimming-verification.md` の準備と C4 の操作1〜3。記録は `~/Capsaicin-dimming.B7nQAG/` にある。収録は次で解析した。

```sh
ffmpeg -hide_banner -nostats -i "<収録>" -vf "blackdetect=d=0.5:pix_th=0.10,freezedetect=n=0.001:d=1" -an -f null -
ffprobe -v error -select_streams v:0 -show_entries frame=pts_time -of csv=p=0 "<収録>"
```

1行目は検出を1件も出さなかった。2行目の時刻から、フレームの間隔の最大を求めた。

## 適用範囲

DisplayServices で輝度を 0 にしても内蔵ディスプレイはディスプレイスリープせず、パスワードの要求やスクリーンセーバーの時間を過ぎてもロックされず、画面収録の内容が暗くならず描画も止まらないことの根拠に使ってよい。Capsaicin がディスプレイスリープを止めるアサーションを持っている状態での観測である。

## 未確認のこと

- 閉じている間に、目で見て真っ暗か（`HYP-BLK-011`）。
- 同じ環境で「ディスプレイをオフ」にして閉じたとき、ロックされるか。比べる回はしていない。
- 画面共有と Computer Use で、閉じている間の画面を取り込めるか。
- 画面全体の収録。収録したのはストップウォッチを囲む範囲だけである。
