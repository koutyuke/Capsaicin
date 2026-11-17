---
schema: hypothesis
id: HYP-LCY-006
title: SMAppService.agent は KeepAlive の Crashed でアプリを起動し直し、launchctl kickstart で起動できる
status: open
affects: ["DEC-HLP-004", "DEC-LCY-002"]
evidence: []
---

# HYP-LCY-006 SMAppService.agent は KeepAlive の Crashed でアプリを起動し直し、launchctl kickstart で起動できる

## 主張

アプリ自身を実行する `SMAppService.agent` を、`RunAtLoad=false`、`KeepAlive={Crashed=true}` の plist で登録すると、次のすべてが成り立つ。

1. 登録したときとログインしたときには、アプリを起動しない。
2. 直接起動したアプリが `launchctl kickstart gui/<uid>/<ラベル>` を実行すると、launchd がアプリを起動する。
3. launchd が起動したアプリがクラッシュ（`SIGSEGV` など）すると、launchd が起動し直す。正常に終了したときは起動し直さない。
4. `SMAppService.mainApp` を登録すると、ログインしたときにアプリが起動する。unregister すると起動しない。この切り替えは agent に影響しない。

## 外れたときに起きること

どれかが外れたら、ログイン時の起動とクラッシュ時の再起動は、いまの LaunchAgent（`DEC-LCY-002`）に `AssociatedBundleIdentifiers` を足す方式にする（`DEC-HLP-004`）。

## 確かめ方

オーナーが、試作のアプリ（`TASK-103`）と、その手順書で確かめる。agent と mainApp の登録は永続的なシステム変更である。終わったら、試作のアプリから両方を unregister し、システム設定から消えたことを確かめる。

## 結果

未確認。
