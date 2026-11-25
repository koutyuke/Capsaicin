---
schema: evidence
id: EVID-LCY-004
title: 公証した Debug ビルドが作った agent の項目が残る間、ad-hoc 署名の手元のビルドの agent は起動の制約で止まり、同じ Team ID で署名し直すと起動した
observed_on: 2026-11-18
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、worktree の `b4e5628` から `just build` で作った ad-hoc 署名の Debug ビルド。/Applications には PR #15 の Developer ID 署名・公証済みの Debug ビルド（Team ID GG7W7F3CTU、bundle ID は同じ `io.github.koutyuke.capsaicin.debug`）を置いていた
sources: ["justfile", "ed65a2d:Packages/CapsaicinKit/Sources/CapsaicinPlatform/Lifecycle/LaunchAgent.swift", "Sources/Capsaicin/App/AppRuntime.swift", "project.yml"]
---

# EVID-LCY-004 公証した Debug ビルドが作った agent の項目が残る間、ad-hoc 署名の手元のビルドの agent は起動の制約で止まり、同じ Team ID で署名し直すと起動した

## 確かめた事実

### ad-hoc 署名の手元のビルドでの `just start`（17:19:08）

オーナーが worktree で `just start` を実行した。`/usr/bin/log show` で次を確かめた。

- `just start` が Debug のジョブを外し（`bootout initiated by: launchctl … <-just`）、手元のビルドを開いた。カーネルと amfid は、実行ファイルが `adhoc signed`（`-423`）であると記録した。
- アプリは SMAppService で agent を登録し、`Register (…) error: 0` を記録した。BTM は既存の項目を使った（`registerLaunchItem: found existing item: … type=agent, disposition=[enabled, allowed, notified], identifier=8.io.github.koutyuke.capsaicin.debug`）。この項目は、/Applications の公証したビルドで登録したときに作られたものである。
- アプリが `launchctl kickstart` を実行し、launchd は agent の起動を始めた。xpcproxy は `OS_REASON_CODESIGNING | Launch Constraint Violation … (Constraint not matched)` で終わり、launchd は `removing service since it exited with consistent failure` でジョブを外した。
- アプリは 40 ms 後に自分から終了した（`terminate:`）。画面には何も出なかった。`LaunchAgent.registerAndStart` は `kickstart` のコマンドの成功だけを見て `.ready` を返し、`AppRuntime.start` はそれを引き渡しの完了とみなして終わる。

### 項目の残り方（オーナーの確認）

- /Applications のアプリを削除してゴミ箱を空にしても、agent の項目は `[disabled, allowed, notified]` で残った。その後の手元のビルドの登録は、同じ項目を使い直した。
- 同じ bundle ID の Debug ビルドが、4つの worktree の `.build` に残っていた。

### 署名し直した手元のビルド（17:35）

- オーナーが手元のビルドを `codesign --force --deep --preserve-metadata=identifier,entitlements,flags --sign "Developer ID Application"` で署名し直した（TeamIdentifier GG7W7F3CTU）。agent は 17:35:05 と 17:35:33 に `Successfully spawned … because non-ipc demand` で起動し、PID 17649（PPID 1）で動き続けた。
- `xcodebuild` に `CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM=GG7W7F3CTU` を渡すビルドは、KeyboardShortcuts のリソースバンドルの自動署名とぶつかって失敗した。
- 手元の証明書の「Apple Development」と「Developer ID Application」は、どちらも組織単位（OU）が GG7W7F3CTU だった。

### `just` のレシピがアプリを見つけられない

- 署名し直した後も、`just start` は `The Debug job runs another executable:`（パスが空）で失敗した。agent の定義は `Program` ではなく `BundleProgram`（`Contents/MacOS/Capsaicin`）を使う。xpcproxy のログは `Resolved (io.github.koutyuke.capsaicin.debug, 3, Contents/MacOS/Capsaicin, …) to program: <絶対パス>` だった。
- agent から起動した PID 17649 のコマンドラインは、`ps -o args=` で相対パスの `Contents/MacOS/Capsaicin` だった。`lsof -a -p 17649 -d txt` は、worktree の `.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/MacOS/Capsaicin` の絶対パスを返した。`justfile` の `debug_process`（`/Build/Products/Debug/Capsaicin[.]app/Contents/MacOS/Capsaicin$`）はコマンドラインを `pgrep -f` で照らすので、`stop`、`status`、`start` の事前の確認は、agent から起動したアプリを見つけられない。

## 確かめ方

オーナーの操作のログを、PM が `/usr/bin/log show`、`ps`、`lsof`、`codesign -dv`、`security find-certificate` で読んだ。`launchctl` と `sfltool` は PM は実行していない。署名し直しと、項目の残り方の確認はオーナーが行った。

## 適用範囲

- 使ってよい: 同じ bundle ID の Team ID 付きのビルドで agent を登録した Mac で、ad-hoc 署名の手元のビルドの agent が起動しない理由を判断するとき。`justfile` のプロセスの見つけ方と、直接起動したアプリが `kickstart` の成功だけで終了することの問題を判断するとき。
- 使ってはいけない: ad-hoc 署名のビルドが agent を一度も使えないことの根拠。項目がない状態から ad-hoc で登録した場合は試していない（`EVID-HLP-004` のデーモンは、新しい登録なら ad-hoc でも起動した）。

## 未確認のこと

- BTM の項目がない状態から、ad-hoc 署名のビルドで agent を登録したときに起動するか。
- 起動の制約が求めているものが Team ID なのか（「Apple Development」で署名し直したビルドでも起動するか）。
- `launchctl print` が `BundleProgram` のジョブで `program = ` の行を出さないか（`just start` の空のパスからの推測）。
- 項目が `[disabled, allowed, notified]` になった理由。
