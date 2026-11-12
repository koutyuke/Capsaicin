---
schema: evidence
id: EVID-BLK-005
title: xnu では SleepDisabled が低バッテリーと熱の判定より先にすべてのスリープ要求を止める
observed_on: 2026-11-06
environment: Web 上のソースコード（apple-oss-distributions/xnu の main ブランチ。対応する macOS のバージョンは不明）
sources: ["https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/iokit/Kernel/IOPMrootDomain.cpp"]
---

# EVID-BLK-005 xnu では SleepDisabled が低バッテリーと熱の判定より先にすべてのスリープ要求を止める

## 確かめた事実

- `IOPMrootDomain::setProperties` は `SleepDisabled` のキーを受け取ると、`kPowerEventUserDisabledSleep` の電源イベントを送る。その処理で `userDisabledAllSleep = (kOSBooleanTrue == (OSBoolean *) arg0);` とし、1つの真偽値として持つ。
- `checkSystemSleepAllowed(options, sleepReason)` は、`gSleepDisabledFlag` の次に `if (userDisabledAllSleep)` を確かめ、真なら `kPMUserDisabledAllSleep`（コメントは「user-space sleep kill switch」）でスリープを止める。この確認は `options == 0` で抜ける前にあるので、`checkSystemSleepEnabled()` と `checkSystemCanSleep()` の両方に効く。
- 同じ関数で、`lowBatteryCondition`、`thermalWarningState`、`thermalEmergencyState` のときにスリープを許す分岐は、`userDisabledAllSleep` の確認より後にある。
- `privateSleepSystem()` は、`checkSystemSleepEnabled()` が偽ならスリープの要求を受け付けない。

## 確かめ方

上記の URL のソースを 2026-11-06 に読んだ。ファイルが大きいので、範囲を分けて読んだ。

## 適用範囲

- `disablesleep` が、手動・ディスプレイを閉じたとき・自動を区別しない1つの値としてスリープの要求を止めることの根拠に使ってよい（`HYP-BLK-006` の主張2）。
- カーネルの `checkSystemSleepAllowed` では、低バッテリーや熱によるスリープの許可より `SleepDisabled` が優先されることの根拠に使ってよい。

## 未確認のこと

- 低バッテリーのときに、カーネルの `checkSystemSleepAllowed` を通らない経路（powerd による強制的なスリープやシステム終了など）があるか。そのため、`HYP-BLK-005` はまだ確かめていない。
- main ブランチのソースが、macOS 26 や開発用の Mac（macOS 27.0.1）のカーネルと同じか。
- 実機での挙動（`HYP-BLK-006` の主張1）。
