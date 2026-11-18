---
schema: evidence
id: EVID-LCY-005
title: 公証した Debug ビルドが作った agent の項目が残る間、同じ Team ID の Apple Development で署名し直した手元のビルドの agent も起動の制約で止まった
observed_on: 2026-11-18
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、worktree の `9c53397` から `just build` で作り、`just sign-debug`（既定の「Apple Development」、TeamIdentifier GG7W7F3CTU）で署名し直した Debug ビルド。agent の項目は `EVID-LCY-004` と同じ、PR の公証したビルドが作ったもの
sources: ["justfile", "Packages/CapsaicinKit/Sources/CapsaicinPlatform/Lifecycle/LaunchAgent.swift"]
---

# EVID-LCY-005 公証した Debug ビルドが作った agent の項目が残る間、同じ Team ID の Apple Development で署名し直した手元のビルドの agent も起動の制約で止まった

## 確かめた事実

オーナーが `just build`、`just sign-debug`、`just start` を実行した。PM が `/usr/bin/log show`、`codesign -dvv`、`lsof`、`ps` で次を確かめた。

- 手元のビルドの署名は `Authority=Apple Development: …`、`TeamIdentifier=GG7W7F3CTU` で、フラグはなかった。
- 17:57:50 に、アプリは agent を登録した（`Register (…) error: 0`）。BTM は `EVID-LCY-004` と同じ項目（uuid DB59879B-…、`identifier=8.io.github.koutyuke.capsaicin.debug`、`[enabled, allowed, notified]`）を使った。
- `launchctl kickstart` の後、xpcproxy は `OS_REASON_CODESIGNING | Launch Constraint Violation … (Constraint not matched)` で終わった。launchd は `Requesting LWCR update on next spawn` を記録し、`job state = spawn failed` にした。
- アプリは 5 秒後に `Agent launch timed out: Agent job has no PID` を記録し、終了せずに動き続けた（PID 51418、PPID 1、実行ファイルは worktree の絶対パス）。`just start` は 10 秒待って失敗し、署名し直しとログの確かめ方を表示した。

`EVID-LCY-004` では、同じ項目のまま「Developer ID Application」で署名し直したビルドの agent は起動した。

## 確かめ方

オーナーの操作のログを PM が読んだ。PM は `launchctl` と `sfltool` を実行していない。

## 適用範囲

- 使ってよい: Developer ID で署名したビルドが作った agent の項目が残る Mac で、手元のビルドをどの証明書で署名し直すかを判断するとき。`DEC-LCY-009` の、起動を確かめられないときにアプリが動き続ける実装が働いたことの根拠。
- 使ってはいけない: Apple Development の署名で agent が使えないことの一般の根拠。`EVID-LCY-003` の試作では、項目のない状態から Apple Development の署名で登録し、agent は起動した。

## 未確認のこと

- 起動の制約が求める条件の中身（証明書の種類か、項目を作った署名の要件か）。
- 項目を作り直せば、Apple Development の署名で起動するか。
