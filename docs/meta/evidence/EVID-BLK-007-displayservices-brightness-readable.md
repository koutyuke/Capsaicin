---
schema: evidence
id: EVID-BLK-007
title: 一般ユーザーの権限で、内蔵ディスプレイの輝度を DisplayServices から読める
observed_on: 2026-11-11
environment: macOS 27.2.1（ビルド 26B131）、Mac16,8（Apple M4 Pro）、外部ディスプレイなし、電池駆動
sources: ["/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/IOKit.framework/Headers/graphics/IOGraphicsLib.h", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/IOKit.framework/Headers/IOReturn.h"]
---

# EVID-BLK-007 一般ユーザーの権限で、内蔵ディスプレイの輝度を DisplayServices から読める

## 確かめた事実

一般ユーザー（`uid=euid=501`）で動く読み取りだけの試作プログラムで、次を観測した。

- 非公開の `/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices` と、`/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay` を `dlopen` できた。
- DisplayServices に `DisplayServicesGetBrightness`、`DisplayServicesSetBrightness`、`DisplayServicesCanChangeBrightness`、`DisplayServicesGetLinearBrightness`、`DisplayServicesSetLinearBrightness` のシンボルがあった。CoreDisplay に `CoreDisplay_Display_GetUserBrightness`、`CoreDisplay_Display_SetUserBrightness` のシンボルがあった。
- オンラインのディスプレイは内蔵の1台（`CGDisplayIsBuiltin` が真）だった。
- 内蔵ディスプレイについて、`DisplayServicesCanChangeBrightness` は `1`、`DisplayServicesGetBrightness` は状態 `0` で `0.497671217` を返した。同じ時点の `AppleARMBacklight` の `IODisplayParameters` の `brightness` は `32768`（最大 `65536`）で、DisplayServices の値とほぼ一致した。
- `CoreDisplay_Display_GetUserBrightness` は `1.0` を返し、DisplayServices とレジストリの値と食い違った。
- IOKit の従来の経路は使えなかった。`IOServiceMatching("IODisplayConnect")` に一致するサービスは0件だった。`AppleARMBacklight` に `IODisplayGetFloatParameter` で `kIODisplayBrightnessKey` を求めると、`0xe00002c7`（`kIOReturnUnsupported`）を返した。

## 確かめ方

C の試作プログラムを `xcrun clang -Wall -Wextra -Werror` でビルドし、一般ユーザーで実行した。設定系のシンボルは `dlsym` で有無を調べただけで、呼んでいない。

1. 2つのフレームワークを `dlopen` し、上のシンボルを `dlsym` で引く。
2. `CGGetOnlineDisplayList` でディスプレイを列挙し、`CGDisplayIsBuiltin`、`CGDisplayIsActive`、`CGDisplayIsAsleep` を読む。
3. 内蔵ディスプレイの ID で `DisplayServicesCanChangeBrightness`、`DisplayServicesGetBrightness`、`CoreDisplay_Display_GetUserBrightness` を呼ぶ。
4. `IODisplayConnect` と `AppleARMBacklight` で `IODisplayGetFloatParameter` を呼ぶ。

レジストリの値は次のコマンドで読める。

```sh
ioreg -rn AppleARMBacklight -d1 | grep -o '"IODisplayParameters" = .*'
```

## 適用範囲

DisplayServices の輝度の取得が一般ユーザーの権限で使えること、CoreDisplay と IOKit の取得を DisplayServices の代わりにできないことの根拠に使ってよい。

## 未確認のこと

- 輝度を設定できるか。設定系の関数は呼んでいない。
- 輝度を 0 にしたときにバックライトが消えるか（`HYP-BLK-011`）。
- 蓋を閉じている間に輝度を変えられるか（`HYP-BLK-012`）。
- macOS 26 で同じ結果になるか（`HYP-SYS-001`）。
