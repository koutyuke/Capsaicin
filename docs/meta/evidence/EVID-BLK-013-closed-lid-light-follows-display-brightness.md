---
schema: evidence
id: EVID-BLK-013
title: 「オンのまま」で閉じたディスプレイの隙間の光は、内蔵ディスプレイの輝度に合わせて点いたり消えたりした
observed_on: 2026-11-12
environment: macOS 27.2.1（26B131）、Mac16,8（Apple M4 Pro）、外部ディスプレイなし、電池駆動、暗い部屋、Capsaicin の Debug ビルド 0.1.0（1）で抑止中（「ディスプレイを閉じたとき」は「オンのまま」、「ディスプレイを自動でオフにしない」はオン）、自動輝度調節・True Tone・Night Shift はオフ、キーボードのバックライトは手で変えていない
sources: ["e9e7e3d:scripts/manual/display-brightness.swift", "e9e7e3d:docs/manual/lid-close-dimming-verification.md"]
---

# EVID-BLK-013 「オンのまま」で閉じたディスプレイの隙間の光は、内蔵ディスプレイの輝度に合わせて点いたり消えたりした

## 確かめた事実

`e9e7e3d:docs/manual/lid-close-dimming-verification.md` の C2 の操作3を行った。ディスプレイを1回閉じたまま、補助で内蔵ディスプレイの輝度を30秒ごとに切り替え、隙間の光をオーナーが目で見た。時刻は日本時間である。

| 時刻 | 書いた輝度 | 隙間の光 |
| --- | --- | --- |
| 15:53:03 | `1.0` | 見えた |
| 15:53:33 | `0.0` | 見えなかった |
| 15:54:03 | `1.0` | 見えた |
| 15:54:33 | 開始値 `0.44537094` | （開ける前に戻した） |

4回の書き込みの後の読み取りは、すべて `AppleClamshellState=1`、`CGDisplayIsActive=1`、`CGDisplayIsAsleep=0`、`ExternalConnected=0` で、読み戻した輝度は書いた値と同じだった。

## 確かめ方

手順は `e9e7e3d:docs/manual/lid-close-dimming-verification.md` の準備と C2 の操作3。開閉を別の時計で秒まで控えていないが、4行ともディスプレイが閉じた状態を示している。

## 適用範囲

「オンのまま」で閉じたディスプレイの隙間から漏れる光が、内蔵ディスプレイのバックライトのものであり、DisplayServices の輝度 0 で消えることの根拠に使ってよい。`EVID-BLK-009` の光の光源の根拠に使ってよい。

## 未確認のこと

- 輝度による電力の差。この回では評価していない（C5）。
- 最大より低い普段の輝度で、どれだけ光が漏れるか。
