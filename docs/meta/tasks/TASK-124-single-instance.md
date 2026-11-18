---
schema: task
id: TASK-124
title: 同じ bundle ID のアプリを1つだけ動かす
status: todo
requirements: ["REQ-LCY-006"]
depends_on: []
assignee: OpenCode openai/gpt-6.2-sol（high）
---

# TASK-124 同じ bundle ID のアプリを1つだけ動かす

## 目的

`SPEC-LCY-009` のとおり、アプリは起動の最初に、同じ bundle ID の別のプロセスが動いているかを調べ、動いていれば何も始めずに動いている方を開き直して終了する。判断は `DEC-LCY-011`。

## 範囲

変更してよいもの: `Sources/Capsaicin/App/`、`Tests/CapsaicinTests/`、必要なら `Packages/CapsaicinKit/Sources/CapsaicinPlatform/` に判定の小さな関数とそのテスト。

変更してはいけないもの: ヘルパー、CLI、`project.yml`、`justfile`、`scripts/`、`docs/`、`AGENTS.md`。

## やること

1. `AppDelegate` の起動の最初（`AppComposition.make` やヘルパー・LED・IPC に触れる前）に、`NSRunningApplication.runningApplications(withBundleIdentifier:)` で、自分以外で終了していないプロセスを探す。
2. 見つかったら、動いている方のアプリを開き直す（その `bundleURL` を `NSWorkspace` で開くなど。開き直されたアプリは既存の `applicationShouldHandleReopen` で設定画面を開く。`SPEC-SET-001`）。そのあと自分は後片付けなしで終了する（何も始めていないので、終了処理で制御に触れない）。
3. Debug と正式版は bundle ID が違うので、互いを対象にしない。
4. テスト: 判定（自分を除く、終了したものを除く、別の bundle ID を除く）と、見つかったときに起動の処理を始めないことを、`SPEC-LCY-009` をテスト名に持つテストで確かめる。`NSRunningApplication` と開き直しは差し替えられるようにする。

ブランチ `spike/daemon-cleanup-probe` のコミット `1b42313` の `AppDelegate.swift` に判定の試作がある（開き直しはしていない）。

## 完了条件

- 上の振る舞いが実装され、`nix develop --command just check` と `nix develop --command just build` が通る。
- 報告に、判定と開き直しの方法、起動途中や終了しかけのプロセスの扱いを書く。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- アプリを起動しない。実機の確認は PM が手順書を作り、オーナーが行う。

## レビュー

（PM が書く）
