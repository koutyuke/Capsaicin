---
schema: evidence
id: EVID-LCY-006
title: Sparkle 2.10.1 のインストーラーは、元のアプリのプロセスが終了してから最後のインストールと起動し直しを行う
observed_on: 2026-11-18
environment: プロジェクトが固定している Sparkle 2.10.1（revision `ab7d71291238df6e0492143b120c9b696a35f603`、`Package.resolved`）のソース。実機では確かめていない
sources: ["Capsaicin.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"]
---

# EVID-LCY-006 Sparkle 2.10.1 のインストーラーは、元のアプリのプロセスが終了してから最後のインストールと起動し直しを行う

## 確かめた事実

- `Sparkle/InstallerProgress/InstallerProgressAppController.m` の `registerApplicationBundlePath:reply:`（295〜311 行）は、更新するバンドルの `NSRunningApplication` のうち最初の1つを監視の対象にし、終了しているかを返す。`listenForTerminationWithCompletion:`（336〜350 行）は、その `isTerminated` を KVO で見て、終了したら完了を呼ぶ。
- `Autoupdate/AppInstaller.m`（399〜414 行）は、対象が終了していなければ終了を待ち、終了したら `_targetTerminated` を立てて `finishInstallationAfterHostTermination` に進む。
- `finishInstallationAfterHostTermination`（765 行から）は `_targetTerminated` を前提にし（`assert`）、最後のインストールの後に `relaunchApplication` を呼ぶ。起動し直しは `InstallerProgressAppController.m` の `relaunchApplication`（387〜408 行）が `NSWorkspace` で行う。

したがって、Sparkle が起動し直した新しい版のプロセスが動き出す時点で、監視の対象だった元のプロセスは終了している。

## 確かめ方

`TASK-114` で Codex が取得済みのソース（`.build/spm/checkouts/Sparkle`、HEAD が上の revision と一致）を読み、PM が引用の行を読み直して確かめた。

## 適用範囲

同じ bundle ID のアプリのプロセスが1つだけ動いている場合に当てはまる。複数動いているときは、最初の1つだけを待つ（295〜311 行のコメント）。単一インスタンスにすれば、この制約は問題にならない。

## 未確認のこと

実機での更新の流れでは確かめていない。次に更新の流れを確かめるときに、単一インスタンスの判定で譲って終了しないことを合わせて見る。
