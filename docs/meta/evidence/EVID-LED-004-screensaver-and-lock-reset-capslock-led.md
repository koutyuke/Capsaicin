---
schema: evidence
id: EVID-LED-004
title: スクリーンセーバーと画面のロックでも LED が消え、loginwindow はどちらでも画面のロックを配信する
observed_on: 2026-11-08
environment: macOS 27.0.1（ビルド 26A434）、Mac16,8（Apple M4 Pro）、Karabiner-Elements 16.3.0 が起動中、外付けキーボードは未接続、「ディスプレイがオフになってからパスワードを要求」は1分
sources: []
---

# EVID-LED-004 スクリーンセーバーと画面のロックでも LED が消え、loginwindow はどちらでも画面のロックを配信する

## 確かめた事実

画面の復帰で LED を点け直す修正（`TASK-038`）を入れたアプリで、抑止中に次を試し、オーナーが LED を目で見た。

| 操作 | 結果 |
| --- | --- |
| スクリーンセーバーを起動して戻る（ロックなし、画面は点いたまま） | LED は消え、戻っても点かない |
| Control + Command + Q でロックし、すぐ解除する（画面は点いたまま） | ロック画面で LED が消え、解除しても点かない |
| `pmset displaysleepnow` で画面を消して戻る（ロックなし） | 点灯し直す |
| 画面を消して90秒待ち、ロックがかかってから戻る | ロック画面でも解除後も点灯している |
| 「蓋を閉じたら画面を消す」をオンにして蓋を閉じ、開ける（ロックあり・なし） | 点灯し直す |
| Apple メニューの「スリープ」から復帰する（ロックあり・なし） | 点灯し直す |

システムログ（`/usr/bin/log show`）では、loginwindow が次の分散通知を配信していた。

- スクリーンセーバーの起動時（01:47:14、02:01:56）: `com.apple.screensaver.didstart` の直後に `com.apple.screenIsLocked`。パスワードを要求しない場合でも配信される。
- スクリーンセーバーの終了時（01:47:56、02:02:01）: `com.apple.screensaver.didstop` の直後に `com.apple.screenIsUnlocked`。
- Control + Command + Q のロックと解除（02:03:07、02:03:10）: `com.apple.screenIsLocked` と `com.apple.screenIsUnlocked`。

## 確かめ方

上の操作をオーナーが行い、直後の LED を目で見た。通知は次のコマンドで確かめた。

```sh
/usr/bin/log show --last 1h --style compact | grep -E "sendDistributedNotification: com.apple.screenIs|posting notification: com.apple.screensaver.did"
```

AppKit は非アクティブのアプリへの分散通知の配信を止める。これは SDK の `NSDistributedNotificationCenter.h` の `suspended` の説明に書かれている。

## 適用範囲

観測した環境で、スクリーンセーバーと画面のロックでも LED が消えることと、`com.apple.screenIsLocked` と `com.apple.screenIsUnlocked` がスクリーンセーバーとロックの両方で配信されることの根拠に使ってよい。

## 未確認のこと

- この回は `ioreg` の記録を取っていない。LED が消えたのが `HIDCapsLockLED` の `"Auto"` への書き換えによるものかは、画面のスリープ（`EVID-LED-003`）と同じだろうと推測しているだけである。
- LED が消える時刻が、`com.apple.screenIsLocked` の配信の前か後か。後なら、ロックの開始で書き直してもロック画面では消えたままになる。
- `com.apple.screenIsLocked` と `com.apple.screenIsUnlocked` は SDK に定数がなく、Apple の文書にもない。今後の macOS で配信され続けるかは分からない。
