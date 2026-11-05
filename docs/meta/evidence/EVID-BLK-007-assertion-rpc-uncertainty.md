---
schema: evidence
id: EVID-BLK-007
title: 電源管理アサーションの RPC 失敗と nil は不在を確定しない
observed_on: 2026-11-06
environment: MacOSX27.2 SDK のヘッダーとコミットを固定した Apple 公開ソースの調査（実機での障害再現ではない）
sources:
  - /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk/System/Library/Frameworks/IOKit.framework/Versions/A/Headers/pwr_mgt/IOPMLib.h
  - https://github.com/apple-oss-distributions/IOKitUser/blob/323ead896d04424f87184d8f6ff0cce811aab106/pwr_mgt.subproj/IOPMAssertions.c
  - https://github.com/apple-oss-distributions/PowerManagement/blob/d415e45501842834a280930c3eed9186544a67f0/pmconfigd/PMAssertions.c
---

# EVID-BLK-007 電源管理アサーションの RPC 失敗と nil は不在を確定しない

## 確かめた事実

- `IOPMAssertionRelease` は、サーバーで実際に解放された後でも RPC の失敗を返しうる。失敗だけでは、解放前か解放後かを確定できない（IOKitUser、2582〜2652 行）。
- `IOPMAssertionCopyProperties` は nullable な辞書を返し、返された辞書の解放責任は呼び出し元にある。`nil` は不在だけでなく、読み取り・RPC・デコードの失敗でも返る（IOKitUser、3322〜3329 行と共通処理 3398〜3455 行）。
- 正しい呼び出し元 PID と ID で問い合わせ、一意な名前と種類も一致すれば、自分のアサーションの同一性を肯定できる。一方、同じ PID 内でも ID は再利用されるので、ID だけでは同一性を示せない（PowerManagement、1242〜1276 行、3351〜3367 行、5937〜6036 行）。
- `IOPMCopyAssertionsByProcess` はアクティブなアサーションの一覧を取得する。成功と `nil` の組み合わせを含め、この一覧の結果だけでは、対象が存在しないことの確実な証明にならない（IOKitUser、3207〜3294 行と共通処理 3398〜3455 行）。
- 作成の RPC が失敗しても、サーバーにアサーションが作られている可能性がある。出力 ID が保証されるのは成功時である（IOKitUser、2304〜2435 行）。

## 確かめ方

SDK の `IOPMLib.h` で戻り値と所有権の契約を読み、上記コミットのクライアント側 RPC 処理と、サーバー側の問い合わせ・検索・ID 割り当てを照合した。

## 適用範囲

調べた API では、これらの失敗時に信頼できる不在確認を得られないことの根拠に使える。すべての API で不在確認が不可能だという証明ではない。採用する不明状態の扱いは `DEC-BLK-006` にある。

## 未確認のこと

実行中の macOS のバイナリーと公開ソースが一致するか、実機でこれらの障害経路が発生するかは未確認である。この調査は実機の障害再現や復旧の成功を示さない。
