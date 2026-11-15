---
schema: evidence
id: EVID-HLP-003
title: CI でビルドした ad-hoc 署名の配布物を別の Mac に入れても、sudoers のルールと起動時の LaunchDaemon からヘルパーが動く
observed_on: 2026-11-15
environment: macOS 27.2.1（ビルド 26B131）、Mac15,7。開発機とは別の Mac で、Capsaicin を入れていない状態から始めた
sources: ["https://github.com/koutyuke/Capsaicin/pull/4", "https://github.com/koutyuke/Capsaicin/actions/runs/43720813722", "docs/specs/helper.md"]
---

# EVID-HLP-003 CI でビルドした ad-hoc 署名の配布物を別の Mac に入れても、sudoers のルールと起動時の LaunchDaemon からヘルパーが動く

## 確かめた事実

使ったのは、リリース用の PR（#4）の CI がコミット `5c5728e62b298c0bd338ec18e0bd429058963220` から作った `Capsaicin-0.1.0.zip` である。開発機ではビルドしていない。ブラウザ（Arc）でダウンロードして Finder で展開し、`/Applications` に置いた。

- `Capsaicin.app` には `com.apple.quarantine` が付いていた。`codesign -dv` は `Signature=adhoc`、`TeamIdentifier=not set` を示した。
- 初めて開くとき、開いてよいかの確認が出た。「システム設定」で「このまま開く」を選ぶ必要はなかった。
- 設定の「ヘルパー」から設置すると、3つのファイルが置かれた。所有者は root で、モードは sudoers のルールが 0440、ヘルパーが 0755、LaunchDaemon の plist が 0644 だった。plist のラベルは `io.github.koutyuke.capsaicin.helper`、引数はヘルパーの絶対パスと `off`、`RunAtLoad` は `true` だった。
- `sudo -n` でヘルパーの `on` と `off` を実行すると、パスワードを求められず、どちらも終了コード 0 で終わった。`SleepDisabled` は `on` の後に 1、`off` の後に 0 になった。
- アプリを終了した後に `sudo -n` で `on` を実行し、`SleepDisabled` が 1 であることを確かめてから再起動した。ログイン後、アプリを起動せずに読むと、`SleepDisabled` は 0 で、`launchctl print system/io.github.koutyuke.capsaicin.helper` は `last exit code = 0` を示した。
- 設定の「ヘルパー」から削除すると、3つのファイルはなくなり、`SleepDisabled` は 0 だった。

## 確かめ方

`HYP-HLP-003` の「確かめ方」の手順で行った。確かめに使ったコマンドは次のとおりである。

```sh
xattr -l /Applications/Capsaicin.app
codesign -dv /Applications/Capsaicin.app
ls -l /Library/PrivilegedHelperTools/io.github.koutyuke.capsaicin.helper /etc/sudoers.d/capsaicin /Library/LaunchDaemons/io.github.koutyuke.capsaicin.helper.plist
plutil -p /Library/LaunchDaemons/io.github.koutyuke.capsaicin.helper.plist
sudo -n /Library/PrivilegedHelperTools/io.github.koutyuke.capsaicin.helper on
sudo -n /Library/PrivilegedHelperTools/io.github.koutyuke.capsaicin.helper off
pmset -g
sudo launchctl print system/io.github.koutyuke.capsaicin.helper
sw_vers
sysctl -n hw.model
```

## 適用範囲

ad-hoc 署名で配布したアプリが、別の Mac でも sudoers のルールと起動時の LaunchDaemon でヘルパーを使えることの根拠に使ってよい。再起動後の `last exit code = 0` は、起動後に LaunchDaemon が実行されたことを示す。

再起動の後に `SleepDisabled` が 0 だったことを、`disablesleep` が再起動をまたいで残るかどうか（`HYP-BLK-007`）の根拠に使ってはいけない。LaunchDaemon が戻した値と区別できないためである。

## 未確認のこと

- 3つのファイルのグループ。使った `ls` がグループを表示しなかった。
- 設置したヘルパーに付いていた拡張属性の中身。`ls -l` は拡張属性があることだけを示した。
- 1台の Mac、1つの macOS のバージョンでしか確かめていない。ほかのバージョンと機種での挙動。
- Arc 以外のブラウザでダウンロードした場合の挙動。
