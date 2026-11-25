---
schema: evidence
id: EVID-SYS-006
title: v0.1.0 を移行の手順で片付けてから入れた 0.2.0 の Release の確認用 DMG は、古いファイルを残さず、ヘルパーとログイン時の起動が動いた
observed_on: 2026-11-25
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、PR #26 の `625c544` の Release の確認用ビルド（0.2.0 (4)）、移行の前は GitHub Release の v0.1.0 (3)
sources: ["https://github.com/koutyuke/Capsaicin/pull/26", "https://github.com/koutyuke/Capsaicin/actions/runs/45626358598", "https://github.com/koutyuke/Capsaicin/releases/tag/v0.1.0"]
---

# EVID-SYS-006 v0.1.0 を移行の手順で片付けてから入れた 0.2.0 の Release の確認用 DMG は、古いファイルを残さず、ヘルパーとログイン時の起動が動いた

## 確かめた事実

v0.1.0 を使っていた状態から、v0.2.0 のリリースノートの「v0.1.0 からの移行」の手順で 0.2.0 に移った。0.2.0 は PR #26 の Release の確認用ビルド（`Capsaicin-0.2.0.dmg`、SHA-256 `1d66b6916153121d751ce531962cbc0bd4a26ba6df6ddccc1b0042d74d3e97d8`）である。

- **v0.1.0 の状態:** GitHub Release の `Capsaicin-0.1.0.zip`（`SHA256SUMS.txt` と一致し、`gh attestation verify` が通った）から入れ、ヘルパーを設置し、「ディスプレイを閉じたとき」を「オンのまま」にしてスリープ防止を始めた。v0.1.0 の4つのファイル（ヘルパー、`/etc/sudoers.d/capsaicin`、LaunchDaemon の plist、LaunchAgent の plist）があり、`SleepDisabled` は 1 だった。ヘルパーの LaunchDaemon は launchd に読み込まれていなかった。バックグラウンド項目には、v0.1.0 のデーモンと LaunchAgent の2つがあった。
- **手順1（終了）:** メニューから「Capsaicinを終了」を選ぶと、プロセスがなくなり、`SleepDisabled` は 0 に戻った。LaunchAgent はアプリを起動し直さなかった。
- **手順2（コマンド）:** 4行のうち、出力は3行目の `Boot-out failed: 3: No such process` だけだった。読み込まれていなかったデーモンを外そうとしたためである。読み込まれていた LaunchAgent は、1行目で何も表示せずに外れた。実行の後、4つのファイルはなく、2つのジョブはどちらも読み込まれていなかった。バックグラウンド項目には、v0.1.0 の2つの項目が `enabled, allowed` のまま残っていた。
- **手順3・4（入れ替え）:** ブラウザでダウンロードした DMG からアプリを置き換えて開くと、ダイアログは1つも出なかった（オーナーの目視）。アプリには `com.apple.quarantine` が付いており、`Authority=Developer ID Application`（Team ID `GG7W7F3CTU`）、`flags=0x10000(runtime)`、`spctl --assess` は `accepted`・`source=Notarized Developer ID` だった。ヘルパーをインストールして許可すると、`capsaicin-helper` が root で動き、`SleepDisabled` は 1 になった。このとき、バックグラウンド項目の v0.1.0 の2つの項目は消え、アプリとヘルパーのデーモンが1つずつになった。設定は引き継がれた（`launchesAtLogin` は true、`lidCloseDisplay` は `keepOn`）。
- **ログインし直したとき:** Capsaicin は `loginwindow` の起動の19秒後に起動し、スリープ防止は停止中で始まった（`SleepDisabled` 0）。ログアウトのときに開いていたアプリを開き直す `TALAppsToRelaunchAtLogin` は、loginwindow の設定になかった。設定の「ヘルパー」の状態は「有効」のままで（オーナーの目視）、スリープ防止を始めると `capsaicin-helper` が root で動き、`SleepDisabled` は 1 になった。
- **スリープ防止中のまま再起動したとき:** ログイン後に Capsaicin が起動し、`SleepDisabled` は 0 だった。ヘルパーのデーモンは起動の後に1回だけ動き（`runs = 1`）、終了コード 0 で終わった。v0.1.0 のファイルとジョブは残っていなかった。ログインしている利用者のバックグラウンド項目は、アプリが `[enabled, allowed, notified]`、ヘルパーのデーモンが `[enabled, allowed, not notified]` で、親はアプリだった。

- **LED、CLI、ホットキー:** 再起動の後に開き直した同じアプリで確かめた。設定は「CLIからの操作を許可」と Caps Lock の LED の通知がオン、「ディスプレイを閉じたとき」が「オンのまま」だった。
  - `capsaicin status` は、停止中に `○ Sleep prevention off` と終了コード 1、オンのときに `● Sleep prevention on` と終了コード 0 を返した。
  - `capsaicin on` は `✓ Sleep prevention on` と終了コード 0 を返し、`SleepDisabled` は 1 になり、`capsaicin-helper` が root で動き、Capsaicin が `PreventUserIdleSystemSleep` と `PreventUserIdleDisplaySleep` を持った。`capsaicin off` は `✓ Sleep prevention off` と終了コード 0 を返し、`SleepDisabled` は 0 に戻り、電源のアサーションはなくなった。
  - 「スリープ防止の切り替え」に Control + Esc を記録すると、押すたびにオンとオフが切り替わった（`capsaicin status` と `SleepDisabled` で確かめた）。
  - CLI でもホットキーでも、オンにすると Caps Lock の LED が点き、オフにすると消えた（オーナーの目視）。
- **公開の前の更新の確認:** 「このアプリについて」で「今すぐ確認」を選ぶと、エラーのダイアログが出た（オーナーの画面写真）。アプリの `SUFeedURL` は `https://github.com/koutyuke/Capsaicin/releases/latest/download/appcast.xml` で、このときの Latest の v0.1.0 には `appcast.xml` が添付されていなかった（添付は `Capsaicin-0.1.0.zip` と `SHA256SUMS.txt`）。

## 確かめ方

v0.1.0 の入れ直し、アプリの起動と終了、ヘルパーの設置と許可、手順2のコマンドの実行、ログインし直すことと再起動は、オーナーが行った。エージェントは各段階の後に次の読み取りだけを行った。

- `ls` で v0.1.0 の4つのファイルの有無を読んだ。
- `launchctl print` で、LaunchAgent（`gui/501/io.github.koutyuke.capsaicin`）、v0.1.0 のデーモン、0.2.0 のデーモンのジョブを読んだ。
- `ps` でプロセスの実行ファイル、ユーザー、起動の時刻を、`pmset -g` で `SleepDisabled` を、`pmset -g assertions` で電源のアサーションを読んだ。
- `sfltool dumpbtm` でバックグラウンド項目を読んだ。
- `codesign -dv --verbose=2`、`spctl --assess -vv`、`xcrun stapler validate` を、DMG と「アプリケーション」のアプリに実行した。
- `defaults read` で設定を読んだ。
- `capsaicin`（`/Applications/Capsaicin.app/Contents/Helpers/capsaicin`）の `status`・`on`・`off` を実行し、出力と終了コードを読んだ。LED の目視、ホットキーの記録と押下、「今すぐ確認」は、オーナーが行った。
- `gh release view v0.1.0` で、v0.1.0 の添付ファイルを読んだ。

## 適用範囲

- 使ってよい: v0.1.0 からの移行の手順（アプリを入れ替える前に行う場合）と、Developer ID で署名し公証した 0.2.0 の Release の DMG の、署名、公証、ヘルパーの設置と `on`・`off`、「ログイン時に起動」、再起動の後の状態、LED、CLI の `status`・`on`・`off`、グローバルホットキーを判断するとき。
- 使ってはいけない: アプリを入れ替えた後に移行の手順を行う場合。公開した後の更新の確認と、Sparkle による更新。

## 未確認のこと

- ログインし直したときと再起動したときの起動が、`SMAppService.mainApp` によるものだという直接の記録。`log show` は読めなかった。
- ログインし直す前まで、アプリの項目に付いていた `(pending authorization)` の意味。再起動の後には消えていた。
- root の利用者（UID 0）の記録に、アプリの項目が `[disabled, allowed, notified]` で1つあることの意味。入れ替えた直後からあった。
- 再起動の後に `SleepDisabled` が 0 だったのが、アプリの終了時の後片付け（`DEC-LCY-012`）とデーモンの起動時の後片付け（`DEC-HLP-005`）のどちらによるか。
- 初めて開いたときに、開いてよいかの確認も出なかった理由。
