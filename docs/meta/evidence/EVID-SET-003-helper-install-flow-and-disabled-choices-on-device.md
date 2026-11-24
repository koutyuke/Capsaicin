---
schema: evidence
id: EVID-SET-003
title: ヘルパーが使えない間は「ディスプレイを閉じたとき」の選べない選択肢がグレーになり、「インストール」ではシステム設定が開かなかった
observed_on: 2026-11-24
environment: Apple Silicon（Mac16,8、MacBook Pro）、macOS 27.2.1（26B131）、Developer ID で署名した Debug 構成
sources: ["Sources/Capsaicin/Settings/SettingsView.swift", "Sources/Capsaicin/Settings/SettingsModel.swift", "Packages/CapsaicinKit/Sources/CapsaicinPlatform/Helper/HelperRegistration.swift"]
---

# EVID-SET-003 ヘルパーが使えない間は「ディスプレイを閉じたとき」の選べない選択肢がグレーになり、「インストール」ではシステム設定が開かなかった

## 確かめた事実

ブランチ `feature/helper-settings-redesign` の `0165f7e` のコードでビルドした Debug アプリで、オーナーが確かめた。

- ヘルパーが使えない間に、設定の「スリープ」で「ディスプレイを閉じたとき」のポップアップ（SwiftUI の `Picker`、`.pickerStyle(.menu)`、選べない選択肢に `selectionDisabled(true)`）を開くと、「Macをスリープ（標準）」以外の選択肢がグレーで表示され、選べなかった（`SPEC-SET-005`）。
- 設定の「ヘルパー」で「インストール…」を選び、確認で「インストール」を押しても、システム設定は開かなかった。システム設定が開いたのは、「システム設定を開く」を押したときだけだった（`SPEC-HLP-001`、`SPEC-HLP-006`）。

## 確かめ方

[`helper-approval-guidance.md`](../../manual/verification/helper-approval-guidance.md) の操作1から6に沿って、オーナーが画面を操作し、結果を口頭で PM に伝えた。

1. 設定の「スリープ」で「ディスプレイを閉じたとき」のポップアップを開き、「オンのまま」を選ぼうとする。
2. 設定の「ヘルパー」で「インストール…」を選び、確認で「インストール」を押して、システム設定が開かないことを見る。
3. 「ヘルパー」で「システム設定を開く」を押し、システム設定が開くことを見る。

## 適用範囲

- 使ってよい: macOS 26 以上のメニュー形式の `Picker` で、`selectionDisabled(true)` を付けた選択肢がグレーになり選べないことを判断するとき（`HYP-SET-004`）。ヘルパーの登録がシステム設定を開かないことを判断するとき。
- 使ってはいけない: メニューのクイック設定の項目の表示、許可した後と許可を外した後の表示。

## 未確認のこと

- キーボード（↑↓ と Return）で選べないか。オーナーの報告に含まれていない。
- 保存値が選べない選択肢のときに、閉じたポップアップのタイトルに保存値が表示されるか。
- 使ったビルドが PR Debug ビルド（`S-Preview`）か、`just sign-debug` で署名し直した手元のビルドか。
- MacBook 以外の Mac の「Appleメニューからのスリープも防ぐ」のスイッチ。
