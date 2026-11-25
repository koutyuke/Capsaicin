---
schema: evidence
id: EVID-LED-012
title: Karabiner-Elements は、把握している Caps Lock の状態で実機の LED を書き直し、「Manipulate caps lock LED」をオフにしたキーボードには書かない
observed_on: 2026-11-12
environment: macOS 27.2.1（26B131）、Mac16,8、Capsaicin の Debug ビルド（fa6cae8）、Karabiner-Elements 16.3.0、内蔵キーボードと Lofree Flow Lite（USB）
sources: ["/usr/bin/log", "/usr/sbin/ioreg", "https://raw.githubusercontent.com/pqrs-org/Karabiner-Elements/v16.3.0/src/share/hid_keyboard_caps_lock_led_state_manager.hpp", "https://raw.githubusercontent.com/pqrs-org/Karabiner-Elements/main/src/apps/CoreService/include/core_service/daemon/device_grabber_details/entry.hpp"]
---

# EVID-LED-012 Karabiner-Elements は、把握している Caps Lock の状態で実機の LED を書き直し、「Manipulate caps lock LED」をオフにしたキーボードには書かない

## 確かめた事実

Capsaicin は実機のキーボードだけに `"On"` を書き、仮想キーボードには書かない版である。LED はオーナーの目視による。

### 実機での結果

| 条件 | 操作 | 実機の LED |
| --- | --- | --- |
| Karabiner-Elements が既定の設定で動作中 | 抑止を始め、Caps Lock に触れない | 内蔵と Lofree（USB）が、解除までの約3分間点灯した |
| Karabiner-Elements が既定の設定で動作中 | 抑止中に Caps Lock をオンにし、オフにする | オンで点灯、オフで消灯した |
| 上の続き | 画面をロックして解除する（Capsaicin が書き直す） | 点灯に戻った。その後どれだけ保たれたかは見ていない |
| Karabiner-Elements をメニューバーから終了 | 抑止中に Caps Lock をオン・オフする | 点灯したままだった。Caps Lock の入力は切り替わった |
| 使っているキーボードの「Manipulate caps lock LED」をオフ | 抑止中に Caps Lock をオンにし、オフにする | 点灯したままだった |
| 使っているキーボードの「Manipulate caps lock LED」をオフ | 抑止せずに Caps Lock をオン・オフする | 消灯したままだった |

- 1行目は `fa6cae8:docs/manual/led-fix-verification.md` の手順3で、2026-11-11 に行った。抑止の前・中・後のどれでも、修飾キーを厳密に照合するルールは内蔵と Lofree の両方で成立した。仮想キーボードの `HIDCapsLockLED` は `"Auto"` のままで、書き込みの対象に入らなかった。
- 2行目の操作の間（2026-11-11 23:54〜23:56）、WindowServer のログで LED の状態が変わったのは、仮想キーボードのサービスだけだった。モードは `"Auto"` のままで、Caps Lock の状態が 0 と 1 の間で切り替わった。内蔵のサービスは Capsaicin が書いた `"On"` のままで、`"Auto"` へ戻す書き込みは、どのプロセスからもなかった。

### Karabiner-Elements のソース

- 16.3.0 の `hid_keyboard_caps_lock_led_state_manager.hpp`:
  - 3秒ごとのタイマーで、保持している LED の状態を実機の Caps Lock の LED に書き直す。
  - 状態が変わったときは、その場でも書く。
  - 状態をまだ持っていない間は、何も書かない。
- main の `device_grabber_details/entry.hpp`（2026-11-12 に確認）:
  - この書き直しは、機器の「Manipulate caps lock LED」がオンで、かつ機器を占有しているときだけ始まる。それ以外では止まる。
  - 仮想の機器は対象にしない。

## 確かめ方

- 手順3は `fa6cae8:docs/manual/led-fix-verification.md`。
- 2行目以降は、オーナーが手順書によらずに行った。2行目のログは、`log show --info` で `updateCapslockLED` を含む行を読んだ。
- ソースは、`sources` の URL を読んだ。

## 適用範囲

- Karabiner-Elements が LED を管理するキーボードでは、Capsaicin が書いた点灯が、Caps Lock の操作をきっかけに消されることの根拠に使ってよい。
- 消された後に `"On"` を書き直しても、3秒以内にまた消されることの根拠に使ってよい。これはソースによるもので、実機では、書き直しの直後に点灯へ戻ったことまでを見た。
- 「Manipulate caps lock LED」をオフにしたキーボードでは、抑止中の点灯が Caps Lock の操作の後も保たれることの根拠に使ってよい。その代わり、抑止していない間は、そのキーボードの LED が Caps Lock を示さなくなる。
- `EVID-LED-009` の「実機だけに書くと一瞬点いてすぐ消えた」と、今回の1行目の「約3分間点灯した」の違いは、Karabiner-Elements が Caps Lock の状態を把握していたかどうかで説明がつく。ただし、それぞれの時点で把握していたかは確かめていない。

## 未確認のこと

- 16.3.0 で、「Manipulate caps lock LED」の設定による出し分けが main と同じか。実機の結果は main のソースと合っている。
- 「Manipulate caps lock LED」をオフにした状態で、点灯がどれだけ長く保たれるか。時間は測っていない。
- 「Manipulate caps lock LED」をオフにして確かめたキーボードが、内蔵か外付けか。記録していない。`EVID-LED-009` では内蔵で確かめた。
- Karabiner-Elements 以外の、キーボードを占有するアプリでの振る舞い。
