---
schema: evidence
id: EVID-BLK-004
title: xnu の RootDomainUserClient は kPMSetClamshellSleepState に権限の確認をしない
observed_on: 2026-11-06
environment: Web 上のソースコード（apple-oss-distributions/xnu の main ブランチ。対応する macOS のバージョンは不明）
sources: ["https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/iokit/Kernel/RootDomainUserClient.cpp"]
---

# EVID-BLK-004 xnu の RootDomainUserClient は kPMSetClamshellSleepState に権限の確認をしない

## 確かめた事実

- `RootDomainUserClient::externalMethod()` の振り分け表で、`kPMSetClamshellSleepState` の項目は `.checkEntitlement = NULL` で、スカラーの入力を1つ受け取る。
- `externalMethodDispatched()` の `kPMSetClamshellSleepState` の処理は、`clientHasPrivilege()` を呼ばずに、`fOwner->setClamShellSleepDisable(arguments->scalarInput[0] ? true : false, IOPMrootDomain::kClamshellSleepDisablePowerd)` を呼び、`kIOReturnSuccess` を返す。同じファイルのスリープやディスプレイの電源の処理には、権限の確認がある。

## 確かめ方

上記の URL のソースを 2026-11-06 に読んだ。`kPMSetClamshellSleepState` の値が 12 であることは、SDK のヘッダーで確かめてある（`EVID-BLK-002`）。

## 適用範囲

カーネルの側では、`kPMSetClamshellSleepState` の呼び出しに root や entitlement が要らないことの根拠に使ってよい。

## 未確認のこと

- main ブランチのソースが、macOS 26 や開発用の Mac（macOS 27.0.1）のカーネルと同じか。
- 一般ユーザーの権限のアプリが `IOPMrootDomain` のユーザークライアントを開けるか、sandbox などで止められないか（`HYP-BLK-002`）。
- 設定する値の印が `kClamshellSleepDisablePowerd` であり、powerd が同じ印を書き換えて、設定が取り消されないか（`HYP-BLK-002`）。
