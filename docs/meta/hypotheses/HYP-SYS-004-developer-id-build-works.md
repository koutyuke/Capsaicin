---
schema: hypothesis
id: HYP-SYS-004
title: Developer ID で署名し公証した Release の配布物は、entitlements なしで既存の機能が動き、Sparkle で更新できる
status: open
affects: ["DEC-SYS-021", "DEC-SYS-019", "DEC-HLP-005"]
evidence: []
---

# HYP-SYS-004 Developer ID で署名し公証した Release の配布物は、entitlements なしで既存の機能が動き、Sparkle で更新できる

## 主張

`DEC-SYS-021` と `DEC-SYS-028` の手順で、Developer ID で署名し、Hardened Runtime（entitlements なし）を付けて公証した Release 構成の DMG について、次のすべてが成り立つ。DMG を開いてアプリを「アプリケーション」フォルダーへ移す手順と、そのときの Gatekeeper の画面は `HYP-SYS-006` で扱う。

1. 既存の機能が entitlements なしで動く。対象は、LED の点灯と消灯、抑止の開始と解除、ヘルパーのインストール（システム設定での許可を含む）と `on`・`off`、ヘルパーが要る設定（「Appleメニューからのスリープも防ぐ」と、「ディスプレイを閉じたとき」の「Macをスリープ（標準）」以外の選択肢）、CLI の `on`・`off`・`status`、グローバルホットキー、「ログイン時に起動」、「このアプリについて」の「今すぐ確認」による更新の確認である。
2. v0.1.0 の利用者が、v0.1.0 のアプリで設置したものを v0.1.0 の手順で片付けてからアプリを入れ替えると、v0.1.0 の方式のファイル（ヘルパー、sudoers のルール、LaunchDaemon、LaunchAgent）は残らない。新しい版のヘルパーと「ログイン時に起動」は、バックグラウンド項目にそれぞれ1つだけ登録される。v0.1.0 の手順は、タグ `v0.1.0` の `README.ja.md` の「アンインストール」の手順1〜3（「ヘルパー」の「削除」、メニューバーからの終了、LaunchAgent の `bootout` と plist の削除）である。
3. Sparkle 2.10.1 は、Developer ID で署名し公証した版を、同じ Team ID で署名し公証した新しい版へ、利用者の追加の操作なしに更新できる。

## 外れたときに起きること

- 1 が外れたら、原因の機能に必要な最小の entitlements を足すか、`DEC-SYS-021` を見直す。ヘルパーとの接続だけが落ちるなら、`DEC-HLP-005` の相手の制限と署名の組み合わせを見直す。
- 2 が外れたら、v0.1.0 の利用者に渡す移行の手順（`DEC-HLP-005`）に、残ったものを片付ける操作を足す。
- 3 が外れたら、`DEC-SYS-019` の検証の設定と、`DEC-SYS-021` の署名のしかたを見直す。

## 確かめ方

オーナーが実機で確かめる。アプリの起動、ヘルパーのインストール、Sparkle の更新、`launchctl` はエージェントが実行しない。

1. 環境: 対応環境の Mac。v0.1.0 を入れ、ヘルパーを設置した状態から始める。
2. 主張2: Developer ID で署名した Release 構成を初めて含むリリース用の PR で、確認用のビルドを入れる前に、v0.1.0 の手順1〜3を行う。アプリを入れ替えた後、次のコマンドで v0.1.0 の方式のファイルが1つも存在しないことを確かめる。

   ```sh
   /bin/ls -ld /Library/PrivilegedHelperTools/io.github.koutyuke.capsaicin.helper
   /bin/ls -ld /etc/sudoers.d/capsaicin
   /bin/ls -ld /Library/LaunchDaemons/io.github.koutyuke.capsaicin.helper.plist
   /bin/ls -ld "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.plist"
   ```

   主張1でヘルパーをインストールし「ログイン時に起動」をオンにした後、`sfltool dumpbtm` の出力で、`io.github.koutyuke.capsaicin` を親に持つデーモンと、アプリのログイン項目がそれぞれ1つだけあることを確かめる。

3. 主張1: 同じ確認用のビルドを `docs/manual/release.md` の「通常のリリース」の手順3で「アプリケーション」フォルダーに入れる。`codesign -dv --verbose=2` の出力に `Authority=Developer ID Application` と `flags=0x10000(runtime)` があり、`spctl --assess -vv` が `source=Notarized Developer ID` を示すことを確かめる。主張1の機能を1つずつ操作する。設定の「ヘルパー」でインストールし、「システム設定を開く」から許可して、状態が「有効」になることも確かめる。Mac を再起動し、ログイン後にアプリが起動することと、ヘルパーの状態が「有効」のままであることを確かめる。
4. 主張3: Developer ID で署名した安定版を2つ公開した後に確かめる。前の版を入れたまま、設定の「このアプリについて」で「今すぐ確認」を選ぶ。`HYP-SYS-006` の主張3と同じ操作で確かめてよい。更新の後に Gatekeeper の画面が出ないことと、新しい版が1つだけ動くことを確かめる。
5. 結果と未確認の項目を根拠に記録する。

## 結果

未確認。
