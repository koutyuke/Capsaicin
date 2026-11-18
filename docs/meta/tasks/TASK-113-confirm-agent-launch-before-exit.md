---
schema: task
id: TASK-113
title: 直接起動したアプリが、agent のジョブが動き出したことを確かめてから終了するようにする
status: in_review
requirements: ["REQ-LCY-005"]
depends_on: []
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-113 直接起動したアプリが、agent のジョブが動き出したことを確かめてから終了するようにする

## 目的

直接起動したアプリは、`LaunchAgent.registerAndStart` で agent を登録し、`launchctl kickstart` のコマンドが成功したら `.ready` を返して終了する。`kickstart` は exec の成否を待たないので、launchd が起動の制約で agent を止めても、アプリは何も示さずに消える（`EVID-LCY-004`）。`DEC-LCY-009` に従い、agent のジョブのプロセスが動いていて、その実行ファイルがこのバンドルの実行ファイルであることを確かめてから `.ready` を返す。5 秒の間に確かめられなければ `.launchFailed` を返す。`.launchFailed` のときにアプリが動き続け、「一般」に再起動されないことを示すのは、今の `AppRuntime.start` と `SettingsView` のままでよい。

振る舞いの正は `docs/specs/lifecycle.md` の `SPEC-LCY-005`。必ず読む: `DEC-LCY-009`、`DEC-LCY-008`、`EVID-LCY-004`。

## 範囲

変更してよいもの: `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Lifecycle/LaunchAgent.swift`、必要なら同じフォルダーの新しいファイル、`Packages/CapsaicinKit/Tests/` の LaunchAgent のテスト、`Sources/Capsaicin/App/AppComposition.swift`（注入の変更が要る場合だけ）。

触らないもの: `docs/`（このチケットを除く）、`justfile`、`Sources/capsaicin-helper/`、`project.yml`、`AppRuntime` の起動の順序。

## やること

1. `kickstart` の後、agent のジョブの PID を得て、そのプロセスの実行ファイルの絶対パスが `Bundle.main.executableURL`（を解決したもの）と一致するかを確かめる。一致したら `.ready`、5 秒以内に一致しなければ `.launchFailed` を返す。確かめる間隔は短く（例: 100〜200 ms）、確かめ終えたらすぐ返す。
   - ジョブの PID は `launchctl print gui/<uid>/<label>` の `pid = ` の行から読むか、`kickstart -p` の出力を使う。どちらを使うかは、exec が失敗した場合にも誤って `.ready` にならない方を選び、理由をレビューに書く。ジョブが外された（`print` が失敗する）ときは、待たずに `.launchFailed` にしてよい。
   - 実行ファイルのパスは `proc_pidpath` で引く。プロセス名や引数では照らさない（agent から起動したプロセスの引数は相対パスになる）。
   - 自分自身の PID は一致とみなさない。
2. 確かめる処理は、既存の `runLaunchctl` と同じく差し替えられるようにし、Swift Testing で次を確かめる: 起動したプロセスが一致して `.ready`、ジョブが外されて `.launchFailed`、別の実行ファイルのプロセスで `.launchFailed`、5 秒を過ぎて `.launchFailed`（待機は差し替えて実時間を使わない）、`kickstart` の失敗で `.launchFailed`。既存のテストは、意味を変えずに新しい注入に合わせる。テスト名は既存の形（`SPEC-LCY-005 …`）に合わせる。
3. 失敗したときは、既存の `Logger` で理由（ジョブがない、PID がない、実行ファイルが違う、時間切れ）を `.error` で残す。パスは `privacy: .private` にする。

## 守ること

- `AGENTS.md` を読んでから始める。アプリを起動しない。`sudo`、`launchctl`、`sfltool` を実行しない。
- 本番のコードに `REQ-*` と `SPEC-*` を書かない。コメントは日本語で、コードを言い換えるだけのコメントを書かない。
- `git commit` と `git push` をしない。

## 完了条件

- 1〜3 を満たす。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just check`
- 実機（オーナー）: ad-hoc 署名の手元のビルドを、PR のビルドが作った agent の項目が残る Mac で Finder から開くと、アプリは終了せずに動き、「一般」に再起動されないことが示される。`just sign-debug` で署名し直したビルドでは、agent に引き渡されて PPID 1 のプロセスが1つだけ動く。

## レビュー

PM がレビューした。`kickstart` の後、`launchctl print` で現在のジョブの PID を読み直し、`proc_pidpath` の絶対パスがバンドルの実行ファイルと一致したら `.ready` を返す。exec 前の xpcproxy はパスが違い、exec に失敗したジョブは外されて `print` が失敗するので、誤って `.ready` にならない。PM が2点を直した。期限の後に一致した場合も `.ready` にした（agent が動いているのに `.launchFailed` を返すと、アプリが2つ残る）。`print` のタイムアウトを残り時間からの計算をやめて 2 秒にした。テストもこれに合わせた。`just check` は通る。
