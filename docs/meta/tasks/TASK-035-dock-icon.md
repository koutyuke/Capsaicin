---
schema: task
id: TASK-035
title: Dock にアイコンを表示する設定と、アプリのメニューの設定・終了を足す
status: done
requirements: ["REQ-MENU-006"]
depends_on: []
assignee: 実装者（Codex、OpenCode 経由の openai/gpt-6.1-sol）
---

# TASK-035 Dock にアイコンを表示する設定と、アプリのメニューの設定・終了を足す

## 目的

オーナーが、常駐アプリによくある「Dock にアイコンを表示する」設定を求めた。オンにすると Dock と ⌘Tab に出て、アプリが動いていることが分かる。既定はオフで、いまの振る舞い（Dock に出ない）を変えない。

Dock に出すと、アプリを前面にしたときにメニューバーの左にアプリのメニュー（SwiftUI の既定のもの）が見えるようになる。既定の「設定…」（⌘,）は SwiftUI の空の `Settings` シーンを開き、既定の「終了」（⌘Q）は `NSApp.terminate` を直接呼ぶので利用者の終了と判定されない（`SPEC-LCY-002`）。この2項目を、ステータスアイコンのメニューと同じ処理に差し替える。

振る舞いは `SPEC-MENU-007`、設定項目は `SPEC-SET-002` の「一般」の表、開き直しは `SPEC-SET-001` にある。先に読むこと。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinCore/Settings/Settings.swift`（`showsDockIcon` の追加）
- `Packages/CapsaicinKit/Tests/CapsaicinCoreTests/SettingsTests.swift`
- `Sources/Capsaicin/App/AppComposition.swift`
- `Sources/Capsaicin/App/AppDelegate.swift`（`applicationShouldHandleReopen` のコメントが「Dock のアイコンがない」前提なので直す。必要なら設定・終了の受け渡し）
- `Sources/Capsaicin/MenuBar/CapsaicinApp.swift`
- `Sources/Capsaicin/Settings/SettingsView.swift`
- `Sources/Capsaicin/Settings/SettingsGeneral.xcstrings`（新しいキーの追加だけ）
- `Tests/CapsaicinTests/` の既存のテストファイル（必要な場合だけ）

触らない: `docs/`、`project.yml`（`LSUIElement` は `YES` のまま。別の作業の未コミットの変更がある）、ほかの `.xcstrings`、`docs/meta/tasks/TASK-033-app-icon.md`。

## 作るもの

1. `Settings` に `showsDockIcon`（既定値 `false`）を足す。`CodingKeys` と `init(from:)` にも足し、欠けたキーは既定値で補う（`showsMenuBarIcon` と同じ書き方）。既定値と読み込みのテストを Core の `SettingsTests` に足す。
2. Dock の表示は `NSApp.setActivationPolicy` で切り替える（オンは `.regular`、オフは `.accessory`）。`Info.plist` の `LSUIElement` は `YES` のまま残し、起動時に Dock に一瞬でも出ないようにする。
   - 反映は `AppServices`（`AppComposition.swift`）で行う。`start()` の中と、設定が変わったときに通る `model.onStatusChange` の中で、現在の方針と違うときだけ `setActivationPolicy` を呼ぶ。`AppServices.start()` は LaunchAgent に引き渡して終わるプロセスでは呼ばれないので、そのプロセスで Dock に出ることはない（`DEC-LCY-002`）。
   - 設定画面で切り替えたあとも、設定画面は前面のキーウインドウのまま残る（`SPEC-MENU-007`）。`.accessory` に戻すとアプリが非アクティブになりうるので、設定画面が表示中なら前面に戻す。起動時（設定画面が出ていないとき）にアプリを前面に出してはいけない。
3. 設定の「一般」の「メニューバーにアイコンを表示」の下に、スイッチの行を足す。キーと日本語は次のとおり。
   - `dockIcon.label`: `Dockにアイコンを表示`
   - `dockIcon.help`: `オンにすると、DockとCommand-Tabのアプリの切り替えにCapsaicinが表示されます。Dockのアイコンをクリックすると設定画面が開きます。`
   - 既存のキーと同じ形（`"extractionState" : "manual"`、Xcode が書く形）で追加する。
4. `CapsaicinApp` の `.commands` で、アプリのメニューの「設定…」（`CommandGroup(replacing: .appSettings)`）と「終了」（`.appTermination`。SDK にあるかを確かめる）を差し替える。
   - 「設定…」は ⌘, で、`AppDelegate` の `runtime?.openSettings()` を呼ぶ。「終了」は ⌘Q で、`AppDelegate.quitByUser()` を呼ぶ。
   - 項目名は `MenuContent.text("menu.settings")` と `MenuContent.text("menu.quit")` を使い、新しいキーを作らない。
   - ほかの項目とメニュー（このアプリについて、隠す、編集、ウインドウなど）はシステムの既定のままにする。

## 守ること

- 起こりにくい場面への防御（方針の監視、遅延の再試行、Dock の状態の確認など）を足さない。設定画面を前面に戻す処理が非同期の待ちを要するなら、理由をコメントに書き、最小にする。
- 新しい型や抽象化を足さない。差分の目安は、テストを除いて 40 行程度。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。テスト名には書く。
- `git commit` しない。アプリを起動しない（LaunchAgent の登録を伴う）。`sudo`、`launchctl`、`pmset` の設定変更をしない。テストで `NSApp` の活性化の方針を変えない（テストの実行中に Dock にアイコンが出る）。

## 完了条件

- `Settings.showsDockIcon` の既定値が `false` で、保存値の読み込みと欠けたキーの補完をテストで確かめている。
- 「一般」に新しい行があり、(i) に上の説明が出る。
- オンなら起動時と切り替え時に `.regular`、オフなら `.accessory` になる。現在の方針と同じときは呼ばない。
- アプリのメニューの「設定…」と「終了」が、ステータスアイコンのメニューと同じ処理を呼ぶ。
- `nix develop --command just check` と `nix develop --command just build` が通る。`just fmt-check` が範囲外の未コミット変更だけで落ちる場合は、その出力を報告する。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- `.build/settings/general-light.png` などの描画結果を見て、新しい行の位置を確かめる。
- ビルドしたアプリのメインメニューの差し替えは単体テストで確かめにくいので、確かめ方を報告する。実機での確認（Dock の表示と消去、設定画面が前面に残るか、Dock のクリック、⌘Q、ログイン時）はオーナーが行う。

## 報告してほしいこと

- 変えたファイルと、その要点
- 検証の結果（失敗があればその出力）
- 判断に迷ったことと、どう決めたか

## レビュー

Codex（`openai/gpt-6.1-sol`）が実装し、PM がレビューした。`showsDockIcon`（既定はオフ）を足し、`AppServices` の `refresh(_:)` で、起動時と設定の変更時に、現在と違うときだけ活性化の方針を切り替える。設定画面が表示中なら、次のメインキューで前面のキーウインドウに戻す。アプリのメニューは `CommandGroup(replacing: .appSettings)` と `.appTermination` で、ステータスアイコンのメニューと同じ処理と文言に差し替えた。ほかの既定のメニューは残した。過剰な防御や新しい型はなかった。

`nix develop --command just check` と `nix develop --command just build` が通ることと、`.build/settings/general-light.png` で新しい行が「メニューバーにアイコンを表示」の下にあることを PM が確かめた。

実機での確認（Dock の表示と消去のあと設定画面が前面に残るか、Dock のクリック、アプリのメニューの ⌘, と ⌘Q、表示したままのログイン）はオーナーが行う。前面に戻す処理が次のメインキューで足りるかは、この確認で分かる。
