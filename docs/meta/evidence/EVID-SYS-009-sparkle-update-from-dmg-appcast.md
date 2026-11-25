---
schema: evidence
id: EVID-SYS-009
title: Developer ID で署名した 0.2.0 (4) は、公開した appcast の DMG から 0.2.0 (5) へ Sparkle で更新できた
observed_on: 2026-11-26
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、更新前は PR #26 の Release の確認用ビルド 0.2.0 (4)、更新後は GitHub Release v0.2.0 の 0.2.0 (5)
sources: ["https://github.com/koutyuke/Capsaicin/releases/tag/v0.2.0", "https://github.com/koutyuke/Capsaicin/pull/26"]
---

# EVID-SYS-009 Developer ID で署名した 0.2.0 (4) は、公開した appcast の DMG から 0.2.0 (5) へ Sparkle で更新できた

## 確かめた事実

v0.2.0 を GitHub Release に公開した後、「アプリケーション」に入れていた PR #26 の Release の確認用ビルド 0.2.0 (4) で、Sparkle の更新を確かめた。更新前のアプリは Developer ID（Team ID `GG7W7F3CTU`）で署名・公証・staple したもので、公開した 0.2.0 (5) と同じ bundle ID（`io.github.koutyuke.capsaicin`）を持つ。公開した `appcast.xml` は `Capsaicin-0.2.0.dmg` を指す（`EVID-SYS-008`）。

- 「このアプリについて」で「今すぐ確認」を選ぶと、新しい版の案内が出た。そこからインストールすると、Capsaicin が起動し直した。Gatekeeper の画面などのダイアログが出たかを尋ねると、オーナーは「全部大丈夫だった」と答えた。
- 更新の後、`/Applications/Capsaicin.app` は 0.2.0 (5) で、「アプリケーション」にある Capsaicin はこの1つだけだった。Capsaicin のプロセスは1つで、`/Applications/Capsaicin.app/Contents/MacOS/Capsaicin` だった。
- 更新の後のアプリは、`Authority=Developer ID Application`（Team ID `GG7W7F3CTU`）、`flags=0x10000(runtime)` で、`spctl --assess --type execute` は `accepted`・`source=Notarized Developer ID`、`stapler validate` も通った。`com.apple.quarantine` は付いていなかった。
- ヘルパーのデーモンは、アプリの起動の4秒後に `capsaicin-helper` として root で動き始め、launchd のジョブは `running` だった。スリープ防止は停止中で、`SleepDisabled` は 0 だった。
- バックグラウンド項目は、ログインしている利用者のアプリの項目が `[enabled, allowed, notified]`、ヘルパーのデーモンが `[enabled, allowed, not notified]` で、親はアプリの項目だった。

## 確かめ方

「今すぐ確認」とインストールはオーナーが行った。エージェントは、更新の前後に次の読み取りだけを行った。

- `PlistBuddy` で `CFBundleShortVersionString` と `CFBundleVersion` を読み、`ls -d /Applications/Capsaicin*.app` で「アプリケーション」の Capsaicin を数えた。
- `ps -axo pid,user,lstart,comm` でプロセスを読んだ。
- `codesign -dv --verbose=2`、`spctl --assess --type execute -vv`、`xcrun stapler validate`、`xattr -p com.apple.quarantine` をアプリに実行した。
- `launchctl print system/io.github.koutyuke.capsaicin.helper`、`pmset -g`、`sfltool dumpbtm` を読んだ。

## 適用範囲

- 使ってよい: Developer ID で署名し公証した版から、同じ Team ID で署名し公証した新しい版へ、DMG を指す appcast で Sparkle が更新できることを判断するとき。
- 使ってはいけない: 更新前の版が GitHub Release で公開した安定版である場合（今回の更新前の版は、リリース用の PR の確認用ビルドだった）。版番号（`CFBundleShortVersionString`）が変わる更新。スリープ防止中に更新する場合。

## 未確認のこと

- 公開した安定版どうしの更新。次の安定版を公開したときに起きる。
- 自動の確認と、「ダウンロードしてインストール」による自動の更新。
- 更新の後に、ヘルパーのデーモンを登録し直したか（`SPEC-HLP-007`）。デーモンが動き始めたことまでは確かめたが、登録し直しの記録は読んでいない。
