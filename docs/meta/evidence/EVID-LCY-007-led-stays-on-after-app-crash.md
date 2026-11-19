---
schema: evidence
id: EVID-LCY-007
title: LED を点けたアプリを SIGKILL か SIGSEGV で終了させると、内蔵キーボードの LED は点いたまま残り、Caps Lock を押しても戻らず、アプリを開き直すと戻った
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、内蔵キーボード。デーモンによる後片付けの試作（Developer ID Application で署名）。Karabiner-Elements が入っている
sources: ["docs/meta/hypotheses/HYP-LCY-001-led-on-persists-after-exit.md", "7528138:docs/meta/tasks/TASK-114-daemon-cleanup-probe.md"]
---

# EVID-LCY-007 LED を点けたアプリを SIGKILL か SIGSEGV で終了させると、内蔵キーボードの LED は点いたまま残り、Caps Lock を押しても戻らず、アプリを開き直すと戻った

## 確かめた事実

`EVID-HLP-010` の試行で、オーナーが内蔵キーボードの LED を目視し、PM が `AppleHIDKeyboardEventDriverV2` の `HIDCapsLockLED` と `HIDCapsLockLEDOn` を読んだ。

- Karabiner-Elements で内蔵キーボードの「Modify events」と「Manipulate caps lock LED」を両方オフにし、抑止なしで LED が Caps Lock の操作に連動することを確かめてから試した。
  - `SIGKILL` の後も `SIGSEGV` の後も、LED は点いたままで、読み戻しは `HIDCapsLockLED="On"`、`HIDCapsLockLEDOn=Yes` だった。
  - オーナーが Caps Lock を手で押しても、LED は消えなかった。
  - どちらも、試作を開き直すと `HIDCapsLockLED="Auto"`、`HIDCapsLockLEDOn=No` になり、LED は通常の連動に戻った。`hidutil` や Mac の再起動は要らなかった。
- 最初の `SIGKILL` は、「Manipulate caps lock LED」がオンのまま行った。終了の後の読み戻しは `"On"` のままだったが、LED は Caps Lock の操作に連動して消えたり点いたりした。
- 「Modify events」をオンにしたまま「Manipulate caps lock LED」だけをオフにすると、抑止なしでも LED は Caps Lock の操作に連動しなかった。

## 確かめ方

`docs/manual/verification/app-crash-daemon-cleanup.md`（`b107708`）の手順で、終了の後に読み戻しと目視を別々に記録し、Caps Lock を手で押して連動を見た。戻すときは、同じ手順の「LED が点いたまま残ったとき」の1（アプリの起動）で戻った。

## 適用範囲

アプリが `HIDCapsLockLED` に `"On"` を書いたまま、後片付けを通らずに終了した場合に当てはまる。Karabiner-Elements のように LED を書き換えるアプリが同じキーボードを扱っていると、見える LED はそのアプリの制御に従い、読み戻しの値と一致しない。

## 未確認のこと

- 外付けのキーボード。
- ログアウトでの戻り方。
