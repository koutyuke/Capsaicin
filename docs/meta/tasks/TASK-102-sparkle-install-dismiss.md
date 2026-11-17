---
schema: task
id: TASK-102
title: 抑止中のインストールの確認を Sparkle への返答の前に移し、取り消したら Dismiss を返す
status: todo
requirements: ["REQ-SYS-008"]
depends_on: []
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-102 抑止中のインストールの確認を Sparkle への返答の前に移し、取り消したら Dismiss を返す

## 目的

抑止中にインストールを選び、確認で取り消すと、Sparkle の「インストールの準備完了」の画面が閉じられず、押しても進まないまま残る。`DEC-LCY-007` のとおり、確認を Sparkle に返答する前に出し、取り消したら Dismiss を返して画面を閉じる。

## 範囲

変更してよいもの:

- `Sources/Capsaicin/Update/`（新しいファイルの追加を含む）
- 更新の状態を表示するために必要な最小限の変更として、`Sources/Capsaicin/App/AppComposition.swift`、`Sources/Capsaicin/Settings/` と `Sources/Capsaicin/MenuBar/` の更新に関わる箇所
- 文言を足す場合は、該当する String Catalog（英語と日本語の両方）
- テスト: `Packages/CapsaicinKit/` の `UpdatePolicy` などの判定を置くモジュールとそのテスト、またはアプリのテスト

触らないもの: `docs/`、`project.yml`、Sparkle の版、ヘルパー、LaunchAgent、ほかの機能。

## 作るもの

- `SPUUserDriver` に準拠し、`SPUStandardUserDriver` にすべてを委ねる user driver。横取りするのは、次の2つの返答だけにする。
  - `showReadyToInstallAndRelaunch:` の返答
  - `showUpdateFoundWithAppcastItem:state:reply:` で、`state.stage` が installing（準備済みのインストーラーを再開した画面）のときの返答
- 横取りした返答が Install で、抑止中なら、Sparkle に返答する前に、いまの `confirmStoppingForInstallation()` と同じ確認を出す。続けたら Install、取り消したら Dismiss を返す。抑止中でなければ、確認を出さずにそのまま返す。Install 以外の返答は、そのまま Sparkle に渡す。
- `SPUStandardUpdaterController` は自前の user driver を差し込めないので、`SPUUpdater` と自前の user driver を直接組み立てる形に替える。`SPUStandardUserDriverDelegate` で使っている gentle reminders の振る舞い（`SPEC-MENU-009`）は保つ。
- 手動の経路では `updater(_:shouldPostponeRelaunchForUpdate:untilInvokingBlock:)` による延期をやめる。自動のインストールの待ち合わせ（`willInstallUpdateOnQuit` と `installIfReady`）は変えない。
- 確認で取り消した版は、「このアプリについて」の行（`SPEC-SET-007`）とメニュー（`SPEC-MENU-009`）で「新しい版がある」として示す。行のボタンかメニューの項目を選ぶと、Sparkle の画面を開く（`checkForUpdates` で、Sparkle が残ったインストーラーを再開する）。

## 守ること

- 仕様は `docs/specs/lifecycle.md` の `SPEC-LCY-008`、`docs/specs/settings.md` の `SPEC-SET-007`、`docs/specs/menu.md` の `SPEC-MENU-009`、判断は `docs/meta/decisions/DEC-LCY-007-dismiss-sparkle-install-on-cancel.md` と `DEC-LCY-005` にある。読んでから始める。
- Sparkle の非公開のメンバー、ウインドウの探索、`dismissUpdateInstallation()` の単独の呼び出しに頼らない。
- 委ねるだけのメソッドは、何もしない転送にとどめる。起こりにくい競合への防御や、独自の状態機械を重ねない。増えるのは、委ねる型1つと、横取りの判定だけを目安にする。
- 判定（抑止中か、どの返答を横取りするか）は、テストできる純粋な関数か小さな型に切り出し、Swift Testing で確かめる。テスト名には仕様の ID を含める（例: `@Test("SPEC-LCY-008 抑止中に取り消したら Dismiss を返す")`）。本番コードに `REQ-*` と `SPEC-*` を書かない。
- アプリを起動しない。`launchctl`、`sudo` を実行しない。`git commit` と `git push` をしない。

## 完了条件

- 抑止中に「インストールして再起動」を選んで確認で取り消すと、Sparkle に Dismiss が返る。続けると Install が返る。抑止を止めているときは確認が出ない。
- 準備済みのインストーラーを再開した画面でのインストールにも、同じ判定が効く。
- 取り消した版が「新しい版がある」として行とメニューに出る。
- 自動のインストールの待ち合わせの既存のテストが通る。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 実機での確認は、オーナーが `HYP-SYS-005` の手順で行う。

## レビュー

未レビュー。
