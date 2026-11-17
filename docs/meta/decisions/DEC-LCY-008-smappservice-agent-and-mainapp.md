---
schema: decision
id: DEC-LCY-008
title: クラッシュ時の再起動を SMAppService の agent、ログイン時の起動を SMAppService の mainApp で行う
status: accepted
supersedes: ["DEC-LCY-001", "DEC-LCY-002"]
superseded_by: []
requirements: ["REQ-LCY-001", "REQ-LCY-003", "REQ-LCY-005"]
based_on: ["DEC-HLP-005", "EVID-LCY-001", "EVID-LCY-002", "EVID-LCY-003", "HYP-LCY-006", "HYP-LCY-007"]
---

# DEC-LCY-008 クラッシュ時の再起動を SMAppService の agent、ログイン時の起動を SMAppService の mainApp で行う

## 結論

`DEC-LCY-001` と `DEC-LCY-002` の振る舞いを保ったまま、`~/Library/LaunchAgents` の plist を SMAppService に置き換える。

- アプリ自身を実行する agent を、`Contents/Library/LaunchAgents/` の plist（`BundleProgram`、`RunAtLoad=false`、`KeepAlive={Crashed=true}`）で持ち、`SMAppService.agent` で常に登録する。
- 直接起動されたアプリ（Finder、ログイン時の起動、Sparkle の再起動）は、これまでどおり `launchctl kickstart` で agent からの起動を求め、自分は終了する。launchd が起動したアプリだけを動かす。引き渡せたかは `kickstart` の成否で決める。
- 「ログイン時に起動する」は、`SMAppService.mainApp` の register と unregister で切り替える。ログイン時に起動したアプリも直接起動なので、agent に引き渡す。mainApp の unregister は、動いているアプリを終了しない。
- `~/Library/LaunchAgents` に plist を書かず、`launchctl bootstrap` と `bootout` も使わない。
- daemon と agent は、システム設定でアプリの1つの項目にまとまり、そのスイッチは両方を止める（`EVID-LCY-003`）。設定画面は、項目がオフのとき、ヘルパーとクラッシュ時の再起動の両方が止まっていることを示す。
- 登録し直しは、デーモンと同じ規則で行う（`DEC-HLP-005`）。起動時に前回登録した版と今の版を比べ、違えば登録し直す。
- 登録や引き渡しに失敗したとき、連続してクラッシュしたときの振る舞い（`SPEC-LCY-004`、`SPEC-LCY-005`）は、agent が承認待ちの場合を加えて直す。

## 背景

`DEC-HLP-004` で、ログイン時の起動とクラッシュ時の再起動も SMAppService に移す方向を採った。試作で、agent は登録とログインでは起動せず、`kickstart` で起動し、クラッシュでは起動し直し、正常終了では起動し直さないことを確かめた。mainApp はログイン時にアプリを起動し、unregister すると起動しなかった（`EVID-LCY-003`）。

## 選択肢

- いまの `~/Library/LaunchAgents` の plist に `AssociatedBundleIdentifiers` を足す。変更は小さいが、plist をアプリの外に書き続け、更新の後に古いパスを指す危険も残る（不採用）。
- agent と mainApp に移す（採用）。

## 理由

- plist がアプリのバンドルに入るので、更新でアプリと定義がずれない。デーモンと同じ登録の仕組みで扱える。
- システム設定の項目が、アプリ名の1つにまとまる。従来型の plist は、`exec` のアイコンの別の項目として出ていた。
- 振る舞い（launchd の管理下で動かす、クラッシュで起動し直す、ログイン時に起動する）は変わらないので、`SPEC-LCY-006` などの再起動した後の処理を保てる。

## 影響

- `specs/lifecycle.md` の起動と登録の節、`specs/settings.md` の「ログイン時に起動する」を直す。
- 「ログイン時に起動する」のオンとオフが、agent の登録の有無から mainApp の登録の有無に変わる。
- `justfile` の `app` グループのレシピ（`DEC-SYS-024`）は、`~/Library/LaunchAgents` の Debug の plist を前提にしている。実装の変更で合わせて直す。
- v0.1.0 の `~/Library/LaunchAgents` の plist は、`DEC-HLP-005` と同じく手順書で片付ける。

## 覆す条件

- Developer ID で署名して公証した版で、agent と mainApp が試作と違う振る舞いをしたら、`AssociatedBundleIdentifiers` を足す案と比べ直す。
