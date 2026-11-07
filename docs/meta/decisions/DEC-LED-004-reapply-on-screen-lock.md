---
schema: decision
id: DEC-LED-004
title: 画面のロックの開始と終了を分散通知で受け、LED を点け直す
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-LED-001", "REQ-LED-004"]
based_on: ["EVID-LED-003", "EVID-LED-004"]
---

# DEC-LED-004 画面のロックの開始と終了を分散通知で受け、LED を点け直す

## 結論

loginwindow が配信する `com.apple.screenIsLocked` と `com.apple.screenIsUnlocked` を `DistributedNotificationCenter` で即時配信（`.deliverImmediately`）として受け取り、どちらでも LED を点け直す。

## 背景

画面のスリープ、スクリーンセーバー、画面のロックで LED が消える（`EVID-LED-003`、`EVID-LED-004`）。画面のスリープは `NSWorkspace.screensDidWakeNotification` で点け直せた。スクリーンセーバーとロックだけのときは画面が眠らないので、この通知は来ない。

## 選択肢

- `com.apple.screenIsLocked` と `com.apple.screenIsUnlocked` を受ける（採用）。
- スクリーンセーバー用の `com.apple.screensaver.didstop` も別に受ける。スクリーンセーバーの開始と終了でも上の2つが配信されるので、要らない（不採用）。
- `IOHIDEventSystemClient` でプロパティの変化を監視し、`"Auto"` に戻されたら書き直す。非公開の関数がさらに増え、Karabiner-Elements など LED を扱うほかのソフトと書き込みを取り合うおそれがある（不採用）。
- 一定の間隔で書き直す。`SPEC-LED-002` は定期的な書き直しをしない（不採用）。
- `NSWorkspace.sessionDidBecomeActiveNotification` を受ける。ユーザーの切り替えでしか届かず、ロックでは届かない（不採用）。

## 理由

- 1つの仕組みで、スクリーンセーバーとロックの両方の戻りを拾える（`EVID-LED-004`）。
- ロックの開始でも書き直せば、ロック画面の間も点灯させられる見込みがある。開始時の書き直しが OS の書き換えより先になってしまっても、解除のときに点け直せる。
- 通知の名前が使えなくなっても、LED を点け直すきっかけが減るだけで、ほかの動作には影響しない。

## 影響

- アプリは抑止の有無にかかわらず2つの分散通知を受け取る。抑止していないときは、`CapsLockLEDController` は何も書かない。
- メニューバーのアプリはほぼ常に非アクティブなので、即時配信を指定しないと AppKit が配信を止めてしまう。

## 覆す条件

- macOS の更新で、2つの通知が配信されなくなったら見直す。
- ロックの開始時の書き直しが毎回 OS の書き換えより先になり、ロック画面で点灯させられないと分かったら、ロック画面での点灯を諦めるか、別のきっかけを探す。
