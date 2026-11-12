---
schema: evidence
id: EVID-BLK-012
title: 自動輝度調節がオンでも閉じている間は輝度 0 のままで隙間から光が漏れず、閉じたままでも元の輝度に戻せた
observed_on: 2026-11-12
environment: macOS 27.2.1（26B131）、Mac16,8（Apple M4 Pro）、外部ディスプレイなし、電源アダプター接続、暗い部屋、Capsaicin の Debug ビルド 0.1.0（1）で抑止中（「ディスプレイを閉じたとき」は「オンのまま」、「ディスプレイを自動でオフにしない」はオン）
sources: ["e9e7e3d:scripts/manual/display-brightness.swift", "e9e7e3d:docs/manual/lid-close-dimming-verification.md", "~/Capsaicin-dimming-C3.zKXKKO/C3-auto-on.log", "~/Capsaicin-dimming-C3.zKXKKO/C3-auto-on-observation.txt", "~/Capsaicin-dimming-C3.zKXKKO/C3-restore-closed.log", "~/Capsaicin-dimming-C3.zKXKKO/C3-restore-closed-observation.txt", "~/Capsaicin-dimming-C3.zKXKKO/initial-settings.txt"]
---

# EVID-BLK-012 自動輝度調節がオンでも閉じている間は輝度 0 のままで隙間から光が漏れず、閉じたままでも元の輝度に戻せた

## 確かめた事実

`e9e7e3d:docs/manual/lid-close-dimming-verification.md` の C3 のうち、`EVID-BLK-010` で行わなかった自動輝度調節がオンの回（操作4）と、閉じたままの復元（操作5）を行った。光と明るさはオーナーの目視による。時刻は日本時間である。

### 自動輝度調節がオンの回

自動輝度調節と True Tone はオンだった。

- 補助（`watch --dim`）が閉じた通知で輝度を 0 にし、15:29:56 から 15:35:07 まで（5分11秒）ディスプレイを閉じた。閉じている間の10秒ごとの読み取り31回は、すべて `brightness=0.0`、`CGDisplayIsAsleep=0` だった。
- 閉じている間、暗い部屋でディスプレイの隙間から光は見えなかった。
- 補助が閉じた瞬間に覚えた輝度は `0.44665638` だった。8秒前の読み取りまでは `0.45242977` だったので、ディスプレイを閉じていく間に自動輝度調節が少し下げていた。
- 開いた通知で `0.44665638` に戻した。開けたとき、閉じる前と同じくらいの明るさに見えた。その後は自動輝度調節が変え、1秒後に `0.4492566`、11秒後に `0.46493584` になった。開けてから28秒後に補助を止めたので、1分間は観測していない。

### 閉じたままの復元

自動輝度調節はオフで、抑止は続けたままにした。

- 15:37:13 に閉じた通知で輝度を 0 にした（覚えた値は `0.46493584`）。
- ディスプレイを閉じたまま 15:37:42 に補助を SIGINT で止めると、補助は元の値を書き、その場の読み取りは `AppleClamshellState=1`、`brightness=0.46493584` だった。
- 観測メモによれば、15:38:33 に閉じたまま、15:39:00 に開けてから読み直しても同じ値だった。この2回の読み取りはログに残っていない。開けた直後の明るさは、閉じる前と同じくらいに見えた。

## 確かめ方

手順は `e9e7e3d:docs/manual/lid-close-dimming-verification.md` の準備と C3 の操作4〜5。記録は `~/Capsaicin-dimming-C3.zKXKKO/` にある。各ログの `event=close`、`event=open`、`event=signal-2` の行と、その間の `timer` の行を読んだ。

## 適用範囲

- 自動輝度調節がオンでも、閉じている間に DisplayServices で設定した輝度 0 が上書きされないことの根拠に使ってよい。
- 輝度 0 で閉じたディスプレイの隙間から、目に見える光が漏れないことの根拠に使ってよい。
- ディスプレイを閉じたまま輝度を書き戻せることの根拠に使ってよい。

## 未確認のこと

- 抑止を閉じたまま解除したとき、スリープより先に輝度を戻せるか。この回は抑止を続けたまま補助だけを止めた。
- `EVID-BLK-009` の光の光源。`EVID-BLK-009` とは電源、自動輝度調節、True Tone の条件が違うので、この回で光が見えなかったことだけでは、最大輝度で見えた光が内蔵ディスプレイのものだと言えない。
- 自動輝度調節がオンのとき、開けてから1分後の輝度。
