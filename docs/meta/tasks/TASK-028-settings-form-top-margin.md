---
schema: task
id: TASK-028
title: 設定ウインドウの上端に標準の帯を出し、右側の内容をシステム設定と同じ高さに置く
status: done
requirements: ["REQ-SET-002"]
depends_on: ["TASK-020"]
assignee: PM
---

# TASK-028 設定ウインドウの上端に標準の帯を出し、右側の内容をシステム設定と同じ高さに置く

## 目的

`TASK-020` の後、オーナーが実機で見たところ、2つの点で右側の内容が下にずれて見えた。

1. Xcode では上端のツールバーに背景と区切り線が出て帯に見えるが、こちらには出なかった。
2. ツールバーの下端と最初のグループの間が 20 pt あり、macOS 26 のシステム設定（12 pt）より広かった。

## 範囲

書いてよい:

- `Sources/Capsaicin/Settings/SettingsView.swift`
- `Sources/Capsaicin/Settings/SettingsWindowController.swift`
- `Tests/CapsaicinTests/Settings/SettingsTests.swift`
- `docs/specs/settings.md`
- `docs/meta/decisions/DEC-UI-006-settings-window-full-height-sidebar.md`

## 作るもの

1. ツールバーがなかったころの `titlebarAppearsTransparent = true` と `titlebarSeparatorStyle = .none` を外し、標準のツールバーの背景と区切り線を出す。
2. 右側の `Form` の最初のグループを、ツールバーの下端から 12 pt に置く。
3. 見出しのないセクションで、最初のグループの上端がツールバーの下端から 12 pt であることをテストで確かめる。

## 守ること

- 標準の部品の見た目を描き直さない（`SPEC-UI-005`）。
- テストでアプリを起動しない。`scripts/manual/` を実行しない。

## 完了条件

- 上の 1〜3 がある。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`

## レビュー

PM が実装した。テストの中で寸法を書き出して調べた。

- 右側は SwiftUI の `ScrollView`（`HostingScrollView`）で、`contentInsets.top` は 52 pt である。grouped の `Form` は、文書の中で内容の上に 20 pt の余白を持つ。
- `.contentMargins(.top, 12, for: .scrollContent)` は、この 20 pt を置き換えず足し合わされた（最初のグループが 84 pt に下がった）。`safeAreaPadding(.top, -8)` は効かなかった。
- `.contentMargins(.top, -8, for: .scrollContent)` で、最初のグループが 64 pt（52 + 12）に上がる。スクロールの端の効果の領域は 52 pt のままである。
- 見出しのあるセクション（解除の条件、操作）では、見出しが 12 pt の位置に来て、グループはその下に続く。

追加したテストは、余白の変更を外すと失敗し、付けると通ることを確かめた。`just check` と `just build` が通った。上端の帯の見え方は `cacheDisplay` では確かめられないため、オーナーが実機で確かめる。
