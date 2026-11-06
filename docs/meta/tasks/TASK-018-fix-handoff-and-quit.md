---
schema: task
id: TASK-018
title: launchd への引き渡しとメニューの終了を直す
status: done
requirements: []
depends_on: [TASK-015]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-018 launchd への引き渡しとメニューの終了を直す

## 目的

実機での確認（`docs/manual/verification.md` の 2.1）で、2つの不具合が見つかった。

1. Finder から起動したアプリが終了しない。launchd が起動したアプリと2つ並んで動き、メニューバーにアイコンが2つ出る。
   - 原因: 引き渡せたかを、`kickstart` の成否ではなく、`SMAppService.statusForLegacyPlist` の照会で決めている。初めて登録した直後は、この照会が「記録がない」を返す（`EVID-LCY-002`）。
   - 同じ理由で、launchd が起動したアプリも、初めての起動では「クラッシュ時に再起動されない」と誤って表示する。
2. メニューの「終了」を押しても終了しない。
   - 原因: `MenuBarController` が `NSApplication.shared.delegate as? AppDelegate` で終了の処理を探している。SwiftUI の `@NSApplicationDelegateAdaptor` を使うと、`NSApp.delegate` には SwiftUI 内部の代理オブジェクトが入る。そのため、この型変換は常に `nil` になる。

`SPEC-LCY-005` と `DEC-LCY-002` のとおりに動くよう直す。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Lifecycle/LaunchAgent.swift`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/Lifecycle/LaunchAgentTests.swift`
- `Sources/Capsaicin/App/`
- `Sources/Capsaicin/MenuBar/MenuBarController.swift`
- `Tests/CapsaicinTests/App/`、`Tests/CapsaicinTests/MenuBar/`

触らない: ほかのすべてのファイル（`docs/`、`project.yml`、String Catalog を含む）。

## 作るもの

1. `LaunchAgent.registerAndStart(launchAtLogin:)` は、`kickstart` が成功したら `.ready` を返す。このときバックグラウンド項目の照会はしない。失敗したときの値（`.launchFailed`・`.registrationFailed`）は今のままにする。
2. `LaunchAgent.restartStatus()` は、照会の結果が `.requiresApproval` のときだけ `.disabled` を返し、それ以外は `.ready` を返す。この関数を呼ぶのは launchd が起動したプロセスだけなので、launchd が起動できた以上、バックグラウンド項目は無効ではない（`EVID-LCY-002`）。
   - 呼ぶのが launchd 由来のプロセスだけであることをコメントに書く。
   - 呼び出し元が `AppRuntime.start()` の launchd の分岐だけであることを確かめる。
3. メニューの「終了」は、`NSApp.delegate` を探さずに `AppDelegate.quitByUser()` を呼ぶ。
   - `MenuBarController` に、`openSettings` と同じ形のクロージャー `quit` を足す。
   - `AppComposition.make` が `AppDelegate` から終了の処理を受け取り、`AppServices` を通して `menuBar.quit` に渡す。
   - `AppDelegate` を弱参照で捕まえ、循環参照を作らない。
4. テストを今の挙動に合わせる。
   - `LaunchAgentTests` では、`registration` が照会を呼ばないこと（`statusURLs` が空）を確かめる。`authorization` の期待値は 2 に合わせる。
   - `AppRuntimeTests` の `fallback` の引数に `.ready` 以外が渡る経路は、今のまま残す。
   - `MenuBarController` の「終了」が `quit` を呼ぶことのテストは、`MenuBarTests` の既存のやり方で書ける場合だけ足す。

## 守ること

- 短く素直に書く（`TASK-010` を参照）。上の 1〜4 以外を変えない。
- テストでアプリを起動しない。`launchctl` を実行しない。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。`git commit` をしない。

## 完了条件

- 上の 1〜4 がある。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`

## レビュー

PM が差分を読んでレビューした。`kickstart` が成功したら照会せずに `.ready` を返し、`restartStatus()` は承認待ちだけを無効とする。`restartStatus()` を呼ぶのは、`AppRuntime.start()` の launchd の分岐だけである。メニューの「終了」は、`AppDelegate` を弱参照で捕まえたクロージャーを `AppComposition` から受け取る。`MenuBarTests` には、コマンドを実行する仕組みがない。そのため、終了のテストは足していない。`just check` と `just build` が通った。実機での確認は `verification.md` の 2.1 からやり直す。

`just check` では、Git が無視するファイル（`.direnv/` と、利用者のグローバルの除外設定にあるファイル）も Markdown lint の対象になり、検査が落ちた。これはチケットの範囲外なので、PM が別のコミットで直した。lint の対象を、Git が無視しないファイルに限った。
