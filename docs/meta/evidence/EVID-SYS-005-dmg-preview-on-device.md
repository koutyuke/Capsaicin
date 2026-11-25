---
schema: evidence
id: EVID-SYS-005
title: 署名・公証・staple した Debug の確認用 DMG は、そのままダウンロードでき、移したアプリは App Translocation なしで動き、正式版と並べてヘルパーをインストールできた
observed_on: 2026-11-25
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、PR #25 の `006b65a` の Debug の確認用ビルド（0.1.0 (20261125091022)）、並べた正式版は v0.1.0 (3)
sources: ["https://github.com/koutyuke/Capsaicin/pull/25", "https://github.com/koutyuke/Capsaicin/actions/runs/45582616235", "docs/manual/release.md", "scripts/dmg/settings.py"]
---

# EVID-SYS-005 署名・公証・staple した Debug の確認用 DMG は、そのままダウンロードでき、移したアプリは App Translocation なしで動き、正式版と並べてヘルパーをインストールできた

## 確かめた事実

PR #25 の `006b65a` で、`DEC-SYS-028` の手順で作った Debug の確認用ビルドを確かめた。

- ダウンロード: PR のコメントの Download をブラウザで開くと、`Capsaicin-debug-pr25-006b65a.dmg` が zip に包まれずに届いた（オーナーの目視）。
- DMG のウインドウ: DMG を開くと、白い背景に、左上のロゴ、`Capsaicin.app` と `Applications` のリンク、その間の3つの山、下の HUD が、`scripts/dmg/settings.py` の位置どおりに出た。隠しファイルを表示する設定でも、ウインドウの中に隠しファイルは出なかった（オーナーの画面写真）。
- 署名: 「アプリケーション」に移した `Capsaicin Debug.app`（`io.github.koutyuke.capsaicin.debug`）は、Developer ID Application（Team ID `GG7W7F3CTU`）で署名されていた。`spctl --assess -vv` は `accepted`、`source=Notarized Developer ID` で、`stapler validate` も通った。
- 起動: 開いたときに出たのは、開いてよいかの確認だけだった（オーナーの目視）。動いているアプリの実行ファイルのパスは `/Applications/Capsaicin Debug.app/Contents/MacOS/Capsaicin` で、App Translocation の場所ではなかった。
- 正式版との並置: 正式版 `/Applications/Capsaicin.app`（`io.github.koutyuke.capsaicin`、v0.1.0）と `Capsaicin Debug.app` が、別々のプロセスとして同時に動いた。
- ヘルパー: `Capsaicin Debug.app` の設定の「ヘルパー」でインストールすると、バックグラウンド項目に `io.github.koutyuke.capsaicin.debug.helper`（Team ID `GG7W7F3CTU`、親は `io.github.koutyuke.capsaicin.debug`）のデーモンが登録され、`capsaicin-helper` が root で動いた。

## 確かめ方

DMG のダウンロード、アプリの移動と改名（`docs/manual/release.md` の手順）、アプリの起動、ヘルパーのインストールはオーナーが行った。エージェントは次の読み取りだけを行った。

- `codesign -dv --verbose=2`、`spctl --assess -vv`、`xcrun stapler validate` を、「アプリケーション」にある2つのアプリに実行した。
- `ps -axo pid,user,comm` で、動いているアプリとヘルパーの実行ファイルのパスとユーザーを読んだ。
- `sfltool dumpbtm` で、ヘルパーのデーモンの登録を読んだ。

## 適用範囲

- 使ってよい: `DEC-SYS-028` の DMG について、ダウンロード、DMG の見た目、署名と公証、App Translocation、Debug の確認用ビルドを正式版と並べて入れる手順を判断するとき。
- 使ってはいけない: Sparkle による DMG からの更新。Release 構成の DMG を「アプリケーション」へそのままドラッグしたときの振る舞い。

## 未確認のこと

- Sparkle で、DMG を指す appcast から更新できるか（`HYP-SYS-006` の主張3）。DMG で配る最初の安定版を公開した後に確かめる。
- 並べた正式版は ad-hoc 署名の v0.1.0 で（`DEC-SYS-021`）、Developer ID で署名した正式版と並べてはいない。bundle ID が違うので結果は変わらないと考えるが、推論である。
- DMG のウインドウは、Finder で拡張子とパスバーを表示する設定の Mac でだけ見た。
