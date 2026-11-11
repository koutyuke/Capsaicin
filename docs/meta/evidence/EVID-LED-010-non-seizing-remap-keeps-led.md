---
schema: evidence
id: EVID-LED-010
title: システム設定の修飾キーの割り当てと Raycast の Hyper Key では、LED の点灯が10分間保たれた
observed_on: 2026-11-11
environment: macOS 27.2.1（26B131）、Mac16,8、Capsaicin の Debug ビルド（cf9d459）、Karabiner-Elements は終了、Raycast、内蔵キーボードと Lofree Flow Lite（USB）
sources: ["/usr/bin/log", "/usr/sbin/ioreg", "~/capsaicin-led-check/20261111-010115/verification-results.txt", "~/capsaicin-led-check/20261111-010115/session-state.json"]
---

# EVID-LED-010 システム設定の修飾キーの割り当てと Raycast の Hyper Key では、LED の点灯が10分間保たれた

## 確かめた事実

`docs/manual/led-remapper-verification.md`（コミット `14fd1f7`） の B4 を行った。それぞれの割り当てをした状態で Capsaicin の抑止を始め、割り当てたキーを押し、10分後まで LED を目視した。

| 割り当て | 対象 | キーを押した後 | 10分後 | 占有の印 |
| --- | --- | --- | --- | --- |
| システム設定で Caps Lock を Control に | 内蔵 | 点灯 | 点灯 | なし |
| システム設定で Caps Lock を Control に | Lofree（USB） | 内蔵・Lofree とも点灯 | 内蔵・Lofree とも点灯 | なし |
| Raycast の Hyper Key を Caps Lock に | 内蔵 | 点灯 | 点灯 | なし |

- どの条件でも、書き込みの失敗はなかった。解除で LED は消え、割り当てを戻した後は Caps Lock に連動する動作に戻った。
- 占有の印は、IORegistry のキーボードのデバイスの下で、`DebugState` が `ClientOptions = 1` かつ `ClientOpened = Yes` のクライアントである（`EVID-LED-006`）。10分後の時点で、どの条件にも1つもなかった。

## 確かめ方

手順は `docs/manual/led-remapper-verification.md`（コミット `14fd1f7`） の B0 と B4。記録は `~/capsaicin-led-check/20261111-010115/` の `B4-*` にある。

## 適用範囲

- OS の修飾キーの割り当てと、Raycast の Hyper Key が、`HIDCapsLockLED` の点灯を妨げないことの根拠に使ってよい。
- これらがキーボードを占有しないことの根拠に使ってよい。

## 未確認のこと

- `hidutil` の `UserKeyMapping` を直接使う割り当て。
- Keyboard Maestro、BetterTouchTool、Hammerspoon など、ほかのアプリ。
