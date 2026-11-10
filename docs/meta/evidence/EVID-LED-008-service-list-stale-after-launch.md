---
schema: evidence
id: EVID-LED-008
title: Capsaicin の書き込み先は起動後のキーボードの増減に追従せず、なくなったサービスへの書き込みが失敗し続けた
observed_on: 2026-11-11
environment: macOS 27.2.1（26B131）、Mac16,8、Capsaicin の Debug ビルド（cf9d459）、Karabiner-Elements 16.3.0、Lofree Flow Lite（Bluetooth Low Energy・2.4 GHz）
sources: ["/usr/bin/log", "/usr/bin/hidutil", "/usr/sbin/ioreg", "~/capsaicin-led-check/20261111-010115/verification-results.txt", "~/capsaicin-led-check/20261111-010115/session-state.json", "~/capsaicin-led-check/20261111-010115/session-applog.txt"]
---

# EVID-LED-008 Capsaicin の書き込み先は起動後のキーボードの増減に追従せず、なくなったサービスへの書き込みが失敗し続けた

## 確かめた事実

`docs/manual/led-remapper-verification.md` の B2 を行った。書き込みの対象と失敗は、アプリのログ（`LED 書き込み: mode=… targets=… failedTargets=…`）で読んだ。登録 ID は、同じ時点の `hidutil list` と照合した。

| 場面 | Capsaicin の pid | OS が認識したサービス | ログの `targets` | ログの `failedTargets` | 目視と HUD |
| --- | --- | --- | --- | --- | --- |
| 抑止中に 2.4 GHz のレシーバーを接続 | 31829 | 内蔵 `0x100000cb5`、レシーバー `0x100010f33` | 内蔵だけ | なし | Lofree は10秒後も消灯。解除時は通常のオフの表示 |
| 抑止中に Bluetooth で接続 | 34863 | 内蔵、Lofree `0x10001126b` | 内蔵だけ | なし | Lofree は10秒後も消灯。解除時は通常のオフの表示 |
| 抑止中にスリープし、30秒後に復帰 | 38582 | 内蔵、仮想 `0x100011788`（復帰前は `0x1000113cf`） | 内蔵、`0x1000113cf` | `0x1000113cf` | 内蔵は点灯。解除時に「一部を戻せません」 |
| Bluetooth を切り、2.4 GHz に替えた（B1 の初回） | 17247 | 内蔵、レシーバー `0x1000102a5` | 内蔵、前の Bluetooth `0x100010036` | `0x100010036` | Lofree は消灯。「Caps Lock の LED を切り替えられていません」と、解除時の「一部を戻せません」 |
| 上のそれぞれの後に Capsaicin を起動し直した | 44005 ほか | — | その時点のサービスすべて | なし | 点灯し、解除で通常の動作に戻った |

- 接続のたびに、書き直しそのものは走っていた（接続の直後に `mode=On` の行が増えた）。書き直しの対象が、起動後の最初の書き込みで得た一覧のままだった。
- なくなったサービスは一覧に残り、`"On"` も `"Auto"` も失敗を返し続けた。1つでも失敗すると LED 全体が失敗になり、警告と「一部を戻せません」につながった。
- スリープと復帰で、Karabiner-Elements の仮想キーボードは登録 ID が変わった。
- 書き込みが失敗した呼び出しは、WindowServer の `updateCapslockLED` のログに残らなかった。失敗した相手は、アプリのログでだけ分かった。

## 確かめ方

手順は `docs/manual/led-remapper-verification.md` の B0 と B2。記録は `~/capsaicin-led-check/20261111-010115/` の `B2-*`、`B1-lofree-2.4g-*`、`session-applog.txt` にある。

```sh
/usr/bin/hidutil list --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}'
/usr/bin/log show --start "$T0" --style compact \
  --predicate 'subsystem == "io.github.koutyuke.capsaicin" AND category == "LED"'
```

## 適用範囲

- `CapsLockLEDController` が持ち続けるクライアントの一覧が、作成後のサービスの追加と削除を反映しないことの根拠に使ってよい。
- 「一部を戻せません」の原因が、なくなったサービスへの書き込みの失敗でありうることの根拠に使ってよい。
- `EVID-LED-005` の未確認の点（失敗した書き込みは WindowServer のログに残るか、一覧に入らなかったのか）への答えに使ってよい。

## 未確認のこと

- 同じプロセスでクライアントを作り直せば、新しいサービスが一覧に入るか。確かめたのはプロセスごと起動し直した場合だけである。
- サービスの追加と削除を、公開の通知で受けられるか。
