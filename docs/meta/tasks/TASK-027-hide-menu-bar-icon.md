---
schema: task
id: TASK-027
title: メニューバーのアイコンを隠す設定と、設定画面の「終了」ボタンを足す
status: done
requirements: ["REQ-MENU-005", "REQ-SET-002"]
depends_on: []
assignee: 実装者（Codex、OpenCode 経由）
---

# TASK-027 メニューバーのアイコンを隠す設定と、設定画面の「終了」ボタンを足す

## 目的

オーナーが、メニューバーのアイコンを隠せる設定を求めた。アイコンを隠してもアプリは常駐し、ホットキー、LED、HUD、CLI で使えるようにする。

アイコンを隠すとメニューの「終了」が使えなくなるので、設定画面のサイドバーの下端に「終了」ボタンを置く（`DEC-UI-008`）。設定画面の入口は、起動中のアプリを開き直す経路（`SPEC-SET-001`、TASK-024 で実装済み）を使う。

振る舞いは `SPEC-MENU-006`、配置は `SPEC-SET-001`、設定項目は `SPEC-SET-002` の「一般」の表にある。先に読むこと。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinCore/Settings/Settings.swift`（`showsMenuBarIcon` の追加）
- `Packages/CapsaicinKit/Tests/CapsaicinCoreTests/SettingsTests.swift`
- `Sources/Capsaicin/MenuBar/MenuBarController.swift`
- `Sources/Capsaicin/Settings/SettingsView.swift`
- `Sources/Capsaicin/Settings/SettingsWindowController.swift`（終了の処理を受け渡すのに必要な場合だけ。後述の注意を守る）
- `Sources/Capsaicin/Settings/SettingsGeneral.xcstrings`（新しいキーの追加だけ）
- `Sources/Capsaicin/App/AppComposition.swift`
- `Tests/CapsaicinTests/MenuBar/MenuBarTests.swift`
- `Tests/CapsaicinTests/Settings/SettingsTests.swift`

触らない: `docs/`、ほかの `.xcstrings`（`SettingsSleep`・`SettingsHelper`・`CLI` は別のチケット TASK-025 が編集中）、`docs/manual/verification.md`。

オーナーの未コミットの変更がある: `Sources/Capsaicin/Settings/SettingsWindowController.swift`（`titlebarAppearsTransparent` と `titlebarSeparatorStyle` の2行を消している）、`Tests/CapsaicinTests/Settings/SettingsTests.swift`（`#expect(window.titlebarAppearsTransparent)` の1行を消している）。この変更は巻き戻さず、残したまま編集する。

## 作るもの

1. `Settings` に `showsMenuBarIcon`（既定値 `true`）を足す。`CodingKeys` と `init(from:)` にも足し、欠けたキーは既定値で補う（既存の項目と同じ書き方）。既定値と読み込みのテストを Core の `SettingsTests` に足す。
2. `MenuBarController` は、設定が `false` のときステータスアイコンを隠す。`NSStatusItem` を作ったまま `isVisible` を切り替える。設定の変更は `AppModel.changeSettings` から `refresh()` が呼ばれる経路で反映できるはずなので、新しいコールバックは足さない。`start()` でアイコンを作った直後に設定を反映し、起動時に一瞬でも表示しない。
3. 設定の「一般」の「切り替え時にHUDを表示」の下に、スイッチの行を足す。キーと日本語は次のとおり。
   - `menuBarIcon.label`: `メニューバーにアイコンを表示`
   - `menuBarIcon.help`: `オフにしてもCapsaicinは動き続けます。設定を開くにはFinderやSpotlightからCapsaicinをもう一度開き、終了するには設定画面の左下にある「Capsaicinを終了」を押します。`
4. 設定画面のサイドバーの下端に「終了」ボタンを置く（`SPEC-SET-001`）。
   - 文言はメニューの「終了」と同じ `MenuContent.text("menu.quit")` を使い、新しいキーを作らない。
   - 押したときは、メニューの「終了」と同じ `quit` を呼ぶ（`AppDelegate.quitByUser()` に届くもの）。`NSApp.terminate` を直接呼ばない。直接呼ぶと、終了の理由が利用者の終了と判定されない（`SPEC-LCY-002`）。
   - `List` の中の行にせず、選択と ↑↓ の移動の対象から外す。SwiftUI の標準の手段（例: `safeAreaInset(edge: .bottom)`）で置く。
   - 下の2項目は、ボタンのすぐ上に寄せる。`SettingsSidebarSpacer` の空きの高さの計算を、ボタンの分を除くように直す。ボタンの上下の余白は 10 pt。

## 守ること

- 起こりにくい場面への防御（アイコンの再作成、二重の確認ダイアログ、表示の監視など）を足さない。終了の確認ダイアログも出さない。
- 新しい抽象化や型を足さない。差分の目安は、テストを除いて 60 行程度。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。テスト名には書く。
- `git commit` しない。アプリを起動しない（LaunchAgent の登録を伴う）。`sudo`、`launchctl`、`pmset` の設定変更をしない。

## 完了条件

- 設定がオフならステータスアイコンが表示されず、オンに戻すと表示される。起動時もこの設定に従う。
- 「一般」に新しい行があり、(i) に上の説明が出る。
- サイドバーの下端に「Capsaicinを終了」ボタンがあり、下の2項目がその上に寄り、ボタンの上下が 10 pt である。押すと `quit` が呼ばれる。
- 既存のサイドバーのテスト（`render`、`sidebarSpacing`、`checkSidebar`）を新しい配置に合わせて直し、ボタンの位置を確かめている。期待値を弱めない。
- `MenuBarTests` で、設定の切り替えにアイコンの表示が追従することを確かめている。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- `.build/settings/general-light.png` などの描画結果を見て、ボタンの位置と余白を確かめる。
- 実機での確認（隠したままのログイン、Finder から開き直す、終了の後片付け）は、オーナーが行う。

## 報告してほしいこと

- 変えたファイルと、その要点
- 検証の結果（失敗があればその出力）
- 判断に迷ったことと、どう決めたか

## レビュー

Codex（`openai/gpt-6.1-sol`）が実装し、PM がレビューした。アイコンは `NSStatusItem` を作ったまま `isVisible` を切り替え、起動直後と `refresh()` で設定を反映する。終了ボタンは `List` の外に `safeAreaInset(edge: .bottom)` で置き、メニューと同じ `quit` を `SettingsWindowController` 経由で受け取る。下の2項目を寄せる空きは、ボタンの上の余白が 10 pt を持つので、固定の 10 pt を引かなくした。過剰な防御や新しい型はなかった。

PM が直したこと: 実装の後に TASK-028 のコミットが同じテストファイルに行を足しており、合わせると SwiftLint の `file_length` と `function_body_length` を超えた。終了ボタンを探す処理と位置の確認を `checkSidebarBottom(_:)` にまとめ、押した回数の確認をループの後の1回にした。確かめる内容は変えていない。

`nix develop --command just check` と `nix develop --command just build` が通ることを PM が確かめた。オフスクリーンの描画ではサイドバーの vibrancy が描かれないので、見た目は実機で確かめる。実機での確認（隠したままのログイン、Finder から開き直す、終了の後片付け）はオーナーが行う。
