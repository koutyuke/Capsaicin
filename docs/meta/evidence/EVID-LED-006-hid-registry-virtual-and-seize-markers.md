---
schema: evidence
id: EVID-LED-006
title: 仮想キーボードの印と、キーボードを占有しているクライアントを、権限なしで IORegistry から読める
observed_on: 2026-11-10
environment: macOS 27.2.1（26B131）、Mac16,8、Karabiner-Elements 16.3.0 が内蔵キーボードを占有中、Bluetooth の機器を接続、一般ユーザーで実行
sources: ["/usr/bin/hidutil", "/usr/sbin/ioreg", "https://github.com/apple-oss-distributions/IOHIDFamily/blob/e31e90a24c27ad6cbe981650d12a1a4124065b03/IOHIDFamily/IOHIDUserDevice.cpp", "https://github.com/apple-oss-distributions/IOHIDFamily/blob/e31e90a24c27ad6cbe981650d12a1a4124065b03/IOHIDFamily/IOHIDLibUserClient.cpp", "https://github.com/apple-oss-distributions/IOHIDFamily/blob/e31e90a24c27ad6cbe981650d12a1a4124065b03/IOHIDEventSystemPlugIns/IOHIDKeyboardFilter.mm", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/IOKit.framework/Headers/hid/IOHIDKeys.h"]
---

# EVID-LED-006 仮想キーボードの印と、キーボードを占有しているクライアントを、権限なしで IORegistry から読める

## 確かめた事実

### キーボードのサービス

`hidutil list` で usage page 1・usage 6 に当たるサービスは2つだった。

| Product | VendorID | Transport | サービスのクラス | デバイスのクラス | Built-In |
| --- | --- | --- | --- | --- | --- |
| `Karabiner DriverKit VirtualHIDKeyboard 1.8.0` | `0x5ac` | なし | `AppleHIDKeyboardEventDriver` | `AppleUserHIDDevice`（UserClass `org_pqrs_Karabiner_DriverKit_VirtualHIDKeyboard`） | 0 |
| `Apple Internal Keyboard / Trackpad` | `0x0` | `FIFO` | `AppleHIDKeyboardEventDriverV2` | `AppleHIDTransportHIDDevice` | 1 |

Karabiner-Elements の仮想キーボードは、Apple の VendorID `0x5ac` を名乗っている。

### 仮想デバイスの印 `HIDVirtualDevice`

- IOHIDFamily では、ユーザー空間から作る HID デバイス（`IOHIDUserDevice`）が `HIDVirtualDevice` を持つ。作った側が指定しなければ `true` になる（`IOHIDUserDevice.cpp` の 85 行目付近）。キーボードフィルターは、一部の機能の対象からこの印を持つサービスを外している（`IOHIDKeyboardFilter.mm` の 328〜330 行目、コメントは「no virtual devices」）。
- この Mac では、`Keyboard Backlight`（`IOHIDUserDevice`）が `HIDVirtualDevice = Yes`、`Transport = "USB"` だった。
- 接続中の Bluetooth の機器は `IOHIDUserDevice` として現れ、`HIDVirtualDevice = No`、`Transport = "Bluetooth"` だった。
- Karabiner-Elements の仮想キーボード（DriverKit の `AppleUserHIDDevice`）は、`HIDVirtualDevice` を持っていなかった。

### キーボードを占有しているクライアント

- 内蔵キーボードの usage 6 のデバイスの下に、`IOUserClientCreator = "pid 849, Karabiner-Core-S"` の `IOHIDLibUserClient` があった。その `DebugState` は `ClientOpened = Yes`、`ClientOptions = 1`、`ClientSeized = No` だった。同じ機器のほかのインターフェースには、Karabiner-Core-Service の `ClientOpened = No`、`ClientOptions = 0` のクライアントもあった。WindowServer のクライアントは `ClientOptions = 0` だった。
- `ClientOptions` は、そのクライアントが `open` に渡したオプションをそのまま記録した値である（`IOHIDLibUserClient.cpp` の 700〜726 行目、1084〜1089 行目）。`1` は `kIOHIDOptionsTypeSeizeDevice`（`IOHIDKeys.h`）である。`ClientSeized` は、そのクライアントがほかのクライアントの占有で締め出されたときに `true` になる。権限のないクライアントは、キーボードを占有して開けない（`kIOReturnNotPrivileged`）。
- `DebugState` は、名前のとおりデバッグ用のプロパティである。SDK の公開ヘッダーに、この値を説明するキーはなかった。

### LED のモードの読み出し

`hidutil property --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}' --get HIDCapsLockLED` は、どちらのサービスでも `(null)` を返した。同じ時点の `ioreg` では、どちらも `HIDEventServiceProperties` に `"HIDCapsLockLED"="Auto"` があった。

どれも一般ユーザーの `hidutil` と `ioreg` で読め、権限の要求はなかった。

## 確かめ方

```sh
/usr/bin/hidutil list --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}'
/usr/sbin/ioreg -l -w0 -r -c IOHIDUserDevice | grep -E -- '^\+-o |"HIDVirtualDevice"|"Product" =|"Transport" ='
/usr/sbin/ioreg -l -w0 -r -c IOHIDDevice | grep -E -- '-o |"Product" =|"PrimaryUsage" =|IOUserClientCreator|"DebugState"'
/usr/sbin/ioreg -l -w0 -r -c IOHIDEventService | grep -E -- '-o |"Product" =|"HIDEventServiceProperties"'
```

## 適用範囲

- 「`HIDVirtualDevice` だけでは仮想キーボードを見分けられない」「`Transport` と VendorID は仮想デバイスでも実機らしい値を名乗りうる」ことの根拠に使ってよい。
- 占有しているクライアントと、そのプロセス名・オプションが権限なしで読めることの根拠に使ってよい。読める値はデバッグ用で、OS の版で変わりうる。
- `HIDCapsLockLED` を読み戻すときは、`hidutil property --get` ではなく `ioreg` を使う根拠に使ってよい。

## 未確認のこと

- Karabiner-Elements 以外の仕組み（ほかの DriverKit ドライバー、`IOHIDUserDevice` で作る仮想キーボード）が、どの印を持つか。
- 外付けキーボード（USB、Bluetooth、2.4 GHz のレシーバー）が、どの `Transport` とクラスで現れるか。
- Karabiner-Elements が占有をやめたとき（デバイスの「Modify events」をオフにしたときなど）に、`ClientOptions` がどう変わるか。
