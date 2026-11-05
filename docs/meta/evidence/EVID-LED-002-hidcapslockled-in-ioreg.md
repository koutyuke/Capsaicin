---
schema: evidence
id: EVID-LED-002
title: 内蔵キーボードと Karabiner-Elements の仮想キーボードのサービスに HIDCapsLockLED が "Auto" である
observed_on: 2026-11-06
environment: macOS 27.0.1（ビルド 26A434）、Mac16,8（Apple M4 Pro）、Karabiner-Elements の DriverKit 仮想キーボード 1.8.0 が有効、外付けキーボードは未接続
sources: ["https://github.com/apple-oss-distributions/IOHIDFamily/blob/777ccd9698845aadf711e32d843c8c9b777431d9/IOHIDEventSystemPlugIns/IOHIDKeyboardFilter.mm"]
---

# EVID-LED-002 内蔵キーボードと Karabiner-Elements の仮想キーボードのサービスに HIDCapsLockLED が "Auto" である

## 確かめた事実

- `ioreg -l -w0` の出力で、`HIDCapsLockLED` は4つのサービスの `HIDEventServiceProperties` の中にあり、どれも値は `"Auto"` だった。
- 4つのうち、所属する機器が分かったのは次の3つである。
  - `AppleHIDKeyboardEventDriverV2`（機器名「Apple Internal Keyboard / Trackpad」）
  - `AppleHIDKeyboardEventDriver`（機器名「Karabiner DriverKit VirtualHIDKeyboard 1.8.0」）
  - `AppleM68Buttons`
- 残りの1つは `AppleUserHIDEventDriver` のサービスで、出力の並びからは機器を特定できなかった。
- このうち2つのサービスには、`HIDCapsLockLEDOn = No` という別のプロパティもあった。

## 確かめ方

一般ユーザーの権限で次を実行し、該当する行とその上にある `+-o` のノード名を読んだ。

```sh
ioreg -l -w0 | grep -n '"HIDCapsLockLED"'
ioreg -l -w0 | awk '/\+-o /{node=$0} /"HIDCapsLockLED"/{print node}'
```

## 適用範囲

観測した環境で `HIDEventServiceProperties` の `HIDCapsLockLED` が `"Auto"` だったことと、内蔵キーボードと Karabiner-Elements の仮想キーボードがこのプロパティを持つことの根拠に使ってよい。

この初期化用辞書の観測は、実行中の上書きモードを読み戻せる保証ではない。Apple の公開ソースのキーボードフィルターは、読み取りで実際の LED 状態を `"On"` / `"Off"` として返す。`"Auto"` への復旧は、書き込みの戻り値が成功であることと、別途承認された実機試験で LED が通常の Caps Lock 連動に戻ることを組み合わせて判定する。参照: [IOHIDKeyboardFilter.mm の読み取り処理と近傍の設定処理](https://github.com/apple-oss-distributions/IOHIDFamily/blob/777ccd9698845aadf711e32d843c8c9b777431d9/IOHIDEventSystemPlugIns/IOHIDKeyboardFilter.mm#L815-L816)。

## 未確認のこと

- 値を `"On"` に書き換えたときに LED が光るか（`HYP-LED-001`）。
- `HIDCapsLockLEDOn` の意味と、`HIDCapsLockLED` との関係。
- macOS 26 で同じか（`HYP-SYS-001`）。
