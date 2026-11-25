---
schema: evidence
id: EVID-LED-005
title: 起動後に作り直された仮想キーボードに、Capsaicin の LED の書き込みが届いていなかった
observed_on: 2026-11-10
environment: macOS 27.2.1（26B131）、Mac16,8、Karabiner-Elements 16.3.0、Capsaicin の Debug ビルド（bd2d317 前後の作業ツリー）、外付けの機器の接続状況は未記録
sources: ["/usr/bin/log", "/usr/bin/hidutil", "/usr/sbin/ioreg"]
---

# EVID-LED-005 起動後に作り直された仮想キーボードに、Capsaicin の LED の書き込みが届いていなかった

## 確かめた事実

WindowServer は、`HIDCapsLockLED` の書き込みを受けるたびに、対象のサービスの登録 ID、書いた値、書いたプロセスを `com.apple.iohid` のログに残す（`updateCapslockLED:0->1 capsLockLED:On ... pid:... process:Capsaicin`）。2026-11-09 19:46 から 2026-11-10 21:54 までの Capsaicin の書き込みは次のとおりだった。

| Capsaicin の pid | 期間 | 記録のあるサービス（登録 ID） |
| --- | --- | --- |
| 25031 | 11-09 19:46〜20:19 | 内蔵 `4294970569` と仮想 `4295946296`（`On` 9回、`Auto` 4回ずつ） |
| 63803 | 11-09 21:08〜21:10 | 内蔵 `4294970569` と仮想 `4295946296`（`On` 18回、`Auto` 7回ずつ） |
| 67412 | 11-09 22:18〜11-10 18:31 | 内蔵 `4294970569` だけ（`On` 99回、`Auto` 22回） |
| 40027 | 11-10 21:04〜21:54（再起動後） | 内蔵 `4294970549` と仮想 `4294975366`（`On` 40回、`Auto` 13回ずつ） |

- 仮想キーボードは Karabiner-Elements の `Karabiner DriverKit VirtualHIDKeyboard 1.8.0` である。再起動後の登録 ID は、`hidutil list` の `0x100000cb5`（内蔵、`4294970549`）と `0x100001f86`（仮想、`4294975366`）に一致した。
- 11-09 22:18:26 に、`com.apple.hiservices-xpcservice` が新しい登録 ID `4295967546` のキーボードのサービスへ書いていた。それ以降、`4295946296` への書き込みはどのプロセスにもない。
- pid 67412 の最初の書き込みは 22:18:52 で、約20時間のあいだ `4295967546` を含め仮想キーボードへの記録は一度もない。同じ期間に `com.apple.hiservices-xpcservice` は、登録 ID が変わった複数のサービスへ書いていた。
- LED が `1` の間も、ログの `capsLockState` は `0` だった。
- 直近5日間、`process == "Capsaicin"` かつ subsystem が `io.github.koutyuke.capsaicin` のエラーログは0件だった。
- 2026-11-06、別の作業で、HUD に「一部を戻せません」が出た直後の状態を読んでいる。`resume-record.json` は `"misalignments":{"led":"notApplied"}` だった。`ioreg` では内蔵キーボードが `HIDCapsLockLED = "On"`、仮想キーボードが `"Auto"` だった。

## 確かめ方

```sh
/usr/bin/log show --last 3d --info --style compact \
  --predicate 'eventMessage CONTAINS "updateCapslockLED"'
/usr/bin/log show --last 5d --style compact \
  --predicate 'subsystem == "io.github.koutyuke.capsaicin" AND messageType == error AND process == "Capsaicin"'
/usr/bin/hidutil list --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}'
```

ログの各行から pid、登録 ID、値を取り出し、pid と登録 ID の組ごとに数えた。

## 適用範囲

- Capsaicin が、起動中に作り直されたキーボードのサービスへ書かないことがあった事実として使ってよい。
- Karabiner-Elements の仮想キーボードが、`HIDCapsLockLED` の書き込みを受け付けることの根拠に使ってよい（pid 25031、63803、40027）。

## 未確認のこと

- 書き込みに失敗した呼び出しがこのログに残るか。残らないなら、失敗した書き込みはこの表に現れない。
- pid 67412 が、起動の26秒前に現れた `4295967546` に書かなかった理由。起動後にもう一度作り直されたのか、一覧に入らなかったのかは、このログからは分からない（`HYP-LED-005`）。
- 11-06 の「一部を戻せません」で、どのサービスへの書き込みが失敗したか。アプリはサービスごとの結果をログに出していない。
- 抑止中に接続した外付けの機器へ書かなかったか。11-10 21 時台のログには、内蔵と仮想以外への書き込みがどのプロセスからもなく、機器を接続した記録も見つけられなかった。
