---
schema: hypothesis
id: HYP-LCY-003
title: アプリは launchd から起動されたかを判定できる
status: open
affects: []
evidence: []
---

# HYP-LCY-003 アプリは launchd から起動されたかを判定できる

## 主張

LaunchAgent から起動されたアプリには、環境変数 `XPC_SERVICE_NAME` に LaunchAgent のラベルが入り、Finder や `open` から直接起動されたアプリには入らない（または別の値が入る）。

## 外れたときに起きること

採用中の要件・仕様への影響はない。`DEC-LCY-010` の構成では、アプリは LaunchAgent への引き渡しを行わず、この判定を使わない。

## 確かめ方

1. 環境: 対応環境の Mac。起動時に `XPC_SERVICE_NAME` を記録する試作アプリ。
2. Finder から起動、`open` で起動、`launchctl kickstart` で LaunchAgent から起動、の3通りで値を記録する。
3. 成功: LaunchAgent から起動したときだけ、値が LaunchAgent のラベルと一致する。失敗: ほかの起動でも同じ値になる、または LaunchAgent から起動しても値がない。

LaunchAgent の登録は永続的なシステム変更である。承認を得て行い、終わったら `launchctl bootout` で外し、plist を削除する。

## 結果

未確認。
