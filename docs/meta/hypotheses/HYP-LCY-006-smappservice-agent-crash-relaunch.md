---
schema: hypothesis
id: HYP-LCY-006
title: SMAppService.agent は KeepAlive の Crashed でアプリを起動し直し、launchctl kickstart で起動できる
status: supported
affects: ["DEC-HLP-004", "DEC-LCY-002"]
evidence: ["EVID-LCY-003"]
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

オーナーが、試作のアプリ（ブランチ `spike/smappservice-probe`）と、その手順書で確かめる。agent と mainApp の登録は永続的なシステム変更である。終わったら、試作のアプリから両方を unregister し、システム設定から消えたことを確かめる。

## 結果

支持された（`EVID-LCY-003`）。agent は登録とログインでは起動せず、`kickstart` で起動し、クラッシュでは起動し直し、正常終了では起動し直さなかった。mainApp を登録するとログイン時にアプリが起動し、unregister すると起動しなかった。agent はその影響を受けなかった。mainApp を unregister しても、動いているアプリは終了しなかった。
