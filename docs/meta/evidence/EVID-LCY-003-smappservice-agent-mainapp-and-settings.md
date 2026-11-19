---
schema: evidence
id: EVID-LCY-003
title: SMAppService の agent は kickstart とクラッシュで起動し、mainApp でログイン時に起動し、システム設定ではアプリの1項目にまとまった
observed_on: 2026-11-18
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、試作 CapsaicinProbe を Apple Development の証明書で署名、/Applications に配置
sources: ["8e003dc:docs/meta/tasks/TASK-103-smappservice-probe.md"]
---

# EVID-LCY-003 SMAppService の agent は kickstart とクラッシュで起動し、mainApp でログイン時に起動し、システム設定ではアプリの1項目にまとまった

## 確かめた事実

試作の agent は、アプリ自身の実行ファイルを `--probe-agent` 付きで起動する plist（`RunAtLoad=false`、`KeepAlive={Crashed=true}`）である。`EVID-HLP-004` と同じ試作で確かめた。

### agent と mainApp

- agent を登録すると `enabled` になったが、launchd はジョブを登録しただけで起動しなかった。ログインのたびに smd が agent のジョブを登録し直したが、起動はしなかった。
- `launchctl kickstart gui/<uid>/<agent のラベル>` で、launchd が agent からアプリを起動した（`non-ipc demand`）。
- そのアプリが `SIGSEGV` で終了すると、30 ms 後に launchd が起動し直した。起動し直したアプリが正常に終了すると、起動し直さなかった。
- mainApp を登録してログインし直すと、アプリが自動で起動した。起動したのはアプリのジョブ（`application.…`）で、agent のジョブではなかった。プロセスは1つだけだった。
- mainApp を unregister しても、動いているアプリは終了しなかった。その後ログインし直すと、アプリは起動しなかった。agent は `enabled` のままだった。

### システム設定の表示

daemon、agent、mainApp を登録した状態で、「一般 > ログイン項目と機能拡張」を見た（画面写真はオーナーの手元にある）。

- 「ログイン時に開く」に `CapsaicinProbe.app` が1件出た。
- 「アプリのバックグラウンドでのアクティビティ」には、`CapsaicinProbe.app` が1件だけ出た。daemon と agent は1つの項目にまとまり、名前はアプリ名だった。開発元の名前は出ず、ⓘ のボタンもなかった。アイコンは汎用のものだった。
- その項目のスイッチをオフにすると、daemon と agent はどちらも `requiresApproval` になった。オンに戻すと、どちらも `enabled` に戻った。
- 比べると、`~/Library/LaunchAgents` に置いた従来型の plist（Capsaicin の Debug 版）は、`Capsaicin` という名前と `exec` のアイコンで別の項目として出て、ⓘ があった。アプリに結び付かない従来型の項目は、開発元の名前（`Determinate Systems, Inc.` など）で出ていた。

### 登録を外した後

- daemon、agent、mainApp をすべて unregister しても、`sfltool dumpbtm` の項目は `[disabled, allowed, …]` で残り、システム設定にも `CapsaicinProbe.app` が出続けた。
- `/Applications` のアプリを消しても残った。ゴミ箱に古い版のアプリが3つあり、ゴミ箱を空にすると、システム設定から消えた。

## 確かめ方

オーナーが、agent の登録、`kickstart`、agent から起動したアプリの `SIGSEGV` と正常終了、mainApp の登録と解除のそれぞれの後のログアウトとログイン、システム設定の確認、すべての登録の解除の順に操作し、ログアウトとログインの前後で試作の画面の記録をとった。launchd のログと `sfltool dumpbtm` の出力で裏付けた。agent から起動したウインドウの記録（launchd から起動されたかの印）は残していないので、agent からの起動は launchd のログで確かめた。

## 適用範囲

- 使ってよい: アプリのログイン時の起動とクラッシュ時の再起動を SMAppService の agent と mainApp で行う設計と、システム設定での見え方、ヘルパーを削除した後の見え方を判断するとき。
- 使ってはいけない: アイコンの見え方の根拠。試作にはアイコンがないので、アプリのアイコンが使われるかは分からない。

## 未確認のこと

- アイコンを持つアプリでの、バックグラウンドの項目のアイコン。
- ゴミ箱に古い版がないときに、アプリを消しただけで項目が消えるか。
- 1台、1つの macOS のバージョンでしか確かめていない。
