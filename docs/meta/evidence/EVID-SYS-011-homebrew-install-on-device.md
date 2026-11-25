---
schema: evidence
id: EVID-SYS-011
title: Homebrew の Cask で入れた 0.2.0 (5) は Gatekeeper の検査に通り、CLI とヘルパーが動き、brew uninstall でアプリとリンクが消えた
observed_on: 2026-11-26
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、Homebrew 7.0.16、tap koutyuke/homebrew-tap の c8cfce3、GitHub Release v0.2.0 の 0.2.0 (5)
sources: ["https://github.com/koutyuke/homebrew-tap/blob/c8cfce3a9f6f78e7616a9dd59d4f2a47f5988c45/Casks/capsaicin.rb", "https://github.com/koutyuke/Capsaicin/releases/tag/v0.2.0", "1e037d8:docs/manual/verification/homebrew-install.md"]
---

# EVID-SYS-011 Homebrew の Cask で入れた 0.2.0 (5) は Gatekeeper の検査に通り、CLI とヘルパーが動き、brew uninstall でアプリとリンクが消えた

## 確かめた事実

開始時、`/Applications/Capsaicin.app` と `~/Library` の Capsaicin の設定はなく、Capsaicin は動いていなかった。オーナーが前に入れていた GitHub Release の版は、確認の前に消されていた。`koutyuke/tap` は tap も信頼もされておらず、`SleepDisabled` は 0 だった。

入れる:

- `brew install --cask koutyuke/tap/capsaicin` は成功した。出力は順に、`Tapping koutyuke/tap`、`Trusted cask koutyuke/tap/capsaicin`、`Moving App 'Capsaicin.app' to '/Applications/Capsaicin.app'`、`Linking Binary 'capsaicin' to '/opt/homebrew/bin/capsaicin'` で、Gatekeeper や署名のエラーは出なかった。Caveats に「If you installed the helper, remove it before uninstalling: open Capsaicin's settings, go to Helper, and click Remove…」が出た。
- 入ったアプリは 0.2.0 (5) で、`com.apple.quarantine` の属性（`0181;…`）が付いていた。`spctl --assess --type execute` は `accepted`、`source=Notarized Developer ID`、署名者 `Developer ID Application`（Team ID `GG7W7F3CTU`）を返し、`stapler validate` も通った。
- `/opt/homebrew/bin/capsaicin` は `/Applications/Capsaicin.app/Contents/Helpers/capsaicin` へのシンボリックリンクだった。
- 完全な名前で入れた後、`brew trust --json=v1` の `casks` に `koutyuke/tap/capsaicin` が入った。tap（`taps`）は空のままだった。その後、短い名前の `brew info --cask capsaicin` は `0.2.0 (auto updates)` の情報を出した。

開く・使う:

- オーナーが Finder から開くと、アプリは開き、メニューバーにアイコンが出た。初めて開いたときのダイアログの有無と文面は記録していない。「CLIからの操作を許可」はオンだった。
- `capsaicin status` は `○ Sleep prevention off` を出し、終了コードは 1 だった（`SPEC-CLI-007` の停止中）。

消す:

- ヘルパーを外さずに `brew uninstall --cask capsaicin` を実行した。信頼の追加なしで成功し、出力は順に、`Quitting application 'io.github.koutyuke.capsaicin'...`、`quit successfully`、`Removing App '/Applications/Capsaicin.app'`、`Unlinking Binary '/opt/homebrew/bin/capsaicin'` だった。
- その後、`/Applications/Capsaicin.app` と `/opt/homebrew/bin/capsaicin` はなく、Capsaicin のプロセスもなかった。`SleepDisabled` は 0 で、`~/Library/Preferences/io.github.koutyuke.capsaicin.plist` は残っていた（`--zap` を付けていない）。

入れ直してヘルパーを使う:

- もう一度 `brew install --cask koutyuke/tap/capsaicin` を実行すると成功し、`spctl` は同じく `Notarized Developer ID` を返した。
- オーナーがアプリを開くと、「ヘルパー」で何も操作しないうちに、ヘルパーは「有効」だった。launchd のログでは、ヘルパーの BTM の項目は `appURL=file:///Applications/Capsaicin.app/` を指したまま残っており、エラーはなかった。
- オーナーが「ディスプレイを閉じたとき」を「ディスプレイをオフ」にした後、`capsaicin on --for 2m` で抑止を始めると、`capsaicin-helper` が root で起動し、`SleepDisabled` は 1 になった。`capsaicin status` は `●`、終了コード 0 だった。`capsaicin off` の後、`SleepDisabled` は 0 に戻り、Capsaicin のアサーションは残らなかった。

## 確かめ方

エージェントが、オーナーの承認を得て `1e037d8:docs/manual/verification/homebrew-install.md` の手順に沿って行った。開始時にアプリがなかったので、手順の操作1（ヘルパーを外して GitHub Release の版を消す）は行わなかった。アプリを開く操作、「ディスプレイを閉じたとき」の変更は、オーナーが行った。`brew install`、`brew uninstall`、`brew info`、`brew trust --json=v1`、`spctl`、`stapler validate`、`xattr`、`ls`、`ps`、`pmset -g`、`pmset -g assertions`、`log show`（launchd と backgroundtaskmanagementd）、`capsaicin status`・`on --for 2m`・`off` は、エージェントが実行した。

## 適用範囲

Homebrew の Cask で配ること（`DEC-SYS-031`）、Cask が CLI をリンクすること（`DEC-CLI-004`）、README の Homebrew の手順の根拠に使ってよい。Homebrew 7.0.16 での結果である。

## 未確認のこと

- 前の版を消したときに、ヘルパーを外していたか。外していなかったなら、残った登録が同じ場所に入れ直したアプリに引き継がれたことになる。再起動をはさんだ場合は `HYP-HLP-012` の条件にあたり、この確認では試していない。
- `brew uninstall --zap` で、Cask の `zap` に挙げたファイルが消えること。
- Sparkle が Homebrew で入れたアプリを更新した後の `brew` の表示。
