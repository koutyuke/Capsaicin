---
schema: evidence
id: EVID-BLK-006
title: xnu では蓋閉じスリープの無効化をビットの組で持ち、どれかが立っていれば蓋を閉じても眠らない
observed_on: 2026-11-06
environment: Web 上のソースコード（apple-oss-distributions/xnu の main ブランチ。対応する macOS のバージョンは不明）
sources: ["https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/iokit/Kernel/IOPMrootDomain.cpp"]
---

# EVID-BLK-006 xnu では蓋閉じスリープの無効化をビットの組で持ち、どれかが立っていれば蓋を閉じても眠らない

## 確かめた事実

- `setClamShellSleepDisable(disable, bitmask)` は、`clamshellSleepDisableMask` に、無効にするならビットを立て、有効に戻すならビットを下ろす。蓋が閉じていて、値が変わり 0 になったときは、蓋の状態を評価し直す。
- `shouldSleepOnClamshellClosed()` は `!clamshellDisabled && !(desktopMode && acAdaptorConnected) && !clamshellSleepDisableMask` を返す。`clamshellSleepDisableMask` のビットが1つでも立っていれば、蓋を閉じてもスリープしない。
- スリープからの復帰の途中では、`kClamshellSleepDisableInternal` のビットを立て、完全に復帰したら下ろす。

## 確かめ方

上記の URL のソースを 2026-11-06 に読んだ。

## 適用範囲

`kPMSetClamshellSleepState`（`EVID-BLK-004`）で立てるビットが、蓋閉じスリープを止める仕組みの根拠に使ってよい。

## 未確認のこと

- `kClamshellSleepDisablePowerd` のビットを powerd がほかの理由で書き換えるか。スリープと復帰の後も、立てたビットが残るか（`HYP-BLK-002`）。
- `clamshellDisabled` がどこで設定されるか（読んだ範囲には出てこなかった）。
