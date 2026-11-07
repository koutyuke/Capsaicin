---
schema: task
id: TASK-024
title: 起動中のアプリを開き直したら設定画面を開く
status: done
requirements: ["REQ-SET-002"]
depends_on: []
assignee: Claude（PM）
---

# TASK-024 起動中のアプリを開き直したら設定画面を開く

## 目的

オーナーが、アプリの起動後に Finder などからアプリをもう一度開いたら、設定画面が出るようにしたいと依頼した。

Capsaicin は Dock にアイコンを出さないので、起動中に開き直しても何も起きず、設定画面への入口はメニューバーだけだった。開き直すと AppKit が `applicationShouldHandleReopen(_:hasVisibleWindows:)` を呼ぶので、そこでメニューの「設定…」と同じ処理を呼ぶ。

初めて起動したときは設定画面を開かない。起動したプロセスは LaunchAgent に引き渡して終わり（`SPEC-LCY-005`）、ログイン時の起動でも画面を出さないためである。

## 範囲

書いてよい:

- `Sources/Capsaicin/App/AppDelegate.swift`
- `Sources/Capsaicin/App/AppRuntime.swift`
- `Sources/Capsaicin/App/AppComposition.swift`
- `Tests/CapsaicinTests/App/AppRuntimeTests.swift`（初期化の引数の追加だけ）
- `docs/specs/settings.md`（`SPEC-SET-001`）

触らない: `Sources/Capsaicin/Settings/SettingsWindowController.swift` と `docs/manual/verification.md`（オーナーの未コミットの変更がある）。

## 完了条件

- 起動中のアプリを Finder、Launchpad、Spotlight などから開くと、設定画面が前面のキーウインドウとして開く。開いていれば前面に出る。
- 開き直しの処理は、メニューの「設定…」と同じ処理を通る。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 開き直しの動作は、オーナーが実機で確かめる。開き直しは AppKit が Apple Event を受けて呼ぶもので、アプリを起動しないテストでは再現できないため、単体テストは追加しない。

## レビュー

PM が実装した。`AppRuntime` に `openSettings` を渡し、`AppDelegate` の `applicationShouldHandleReopen(_:hasVisibleWindows:)` から呼ぶ。メニューの「設定…」も同じ `AppServices.openSettings()` を通る。標準の再オープンの処理（新しいウインドウを開くなど）は要らないので `false` を返す。起動の処理が終わる前に開き直された場合は、設定ウインドウがまだないので何もしない。

`nix develop --command just check` と `nix develop --command just build` が通ることを確かめた。アプリの起動は LaunchAgent の登録を伴うので、エージェントは実行していない。開き直しの動作はオーナーが実機で確かめる。
