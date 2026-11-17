---
schema: hypothesis
id: HYP-SYS-004
title: Developer ID で署名し公証した配布物は、ad-hoc 署名の版と同じに動き、Sparkle で更新できる
status: open
affects: ["DEC-SYS-021", "DEC-SYS-019"]
evidence: []
---

# HYP-SYS-004 Developer ID で署名し公証した配布物は、ad-hoc 署名の版と同じに動き、Sparkle で更新できる

## 主張

`DEC-SYS-021` の手順で、Developer ID で署名し、Hardened Runtime（entitlements なし）を付けて公証した Release 構成の配布物について、次のすべてが成り立つ。

1. ブラウザでダウンロードした zip を展開して開くと、開いてよいかの確認だけが出る。「このまま開く」を選ぶ必要はない。
2. 既存の機能が ad-hoc 署名の版と同じに動く。対象は、LED の点灯と消灯、抑止の開始と解除、ヘルパーの設置と `on`・`off`、CLI の `on`・`off`・`status`、グローバルホットキー、LaunchAgent への引き渡し、Sparkle の更新の確認である。
3. v0.1.0（ad-hoc 署名）で設置したヘルパー、sudoers のルール、起動時の LaunchDaemon、LaunchAgent は、アプリを Developer ID 署名の版に手で入れ替えても、そのまま使える。ログイン項目とバックグラウンド項目は重複しない。
4. Sparkle 2.10.1 は、Developer ID で署名し公証した版を、同じ Team ID で署名し公証した新しい版へ、利用者の追加の操作なしに更新できる。

## 外れたときに起きること

- 1 が外れたら、`DEC-SYS-021` の署名か公証の手順を直す。
- 2 が外れたら、原因の機能に必要な最小の entitlements を足すか、`DEC-SYS-021` を見直す。
- 3 が外れたら、v0.1.0 の利用者向けに、入れ替えの後に必要な操作（ヘルパーの修復など）をリリースノートで案内する。
- 4 が外れたら、`DEC-SYS-019` の検証の設定と、`DEC-SYS-021` の署名のしかたを見直す。

## 確かめ方

オーナーが実機で確かめる。`launchctl`、ヘルパーの設置、アプリの起動はエージェントが実行しない。

1. 環境: 対応環境の Mac。v0.1.0 を入れ、ヘルパーを設置した状態から始める。
2. 主張1〜3: Developer ID の署名を入れた最初のリリース用の PR で、確認用のビルドを PR のコメントからダウンロードする。`codesign -dv --verbose=2` で Authority が Developer ID Application、`spctl --assess -vv` で `source=Notarized Developer ID` を確かめる。v0.1.0 と入れ替えて開き、主張2の機能を1つずつ操作する。Mac を再起動し、ログイン後に起動することとヘルパーの LaunchDaemon が動いたことを確かめる。
3. 主張4: Developer ID で署名した版を2つ公開した後に確かめる。前の版を入れたまま「アップデートを確認」を選び、更新の後に Gatekeeper の画面が出ず、新しい版が LaunchAgent の管理下で1つだけ動くことを確かめる。
4. 結果と未確認の項目を根拠に記録する。

## 結果

未確認。
