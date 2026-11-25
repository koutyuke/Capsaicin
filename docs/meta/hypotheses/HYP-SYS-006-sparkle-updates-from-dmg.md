---
schema: hypothesis
id: HYP-SYS-006
title: Sparkle 2 は、Applications へのリンクを含む DMG から更新でき、DMG で配った版は開いて使える
status: open
affects: ["DEC-SYS-028"]
evidence: ["EVID-SYS-005", "EVID-SYS-006"]
---

# HYP-SYS-006 Sparkle 2 は、Applications へのリンクを含む DMG から更新でき、DMG で配った版は開いて使える

## 主張

`DEC-SYS-028` の手順で作り、Developer ID で署名・公証・staple した DMG について、次のすべてが成り立つ。

1. ブラウザでダウンロードした DMG を開くと、`Capsaicin.app` と `Applications` のリンクが表示される。アプリを `Applications` へドラッグして開くと、開いてよいかの確認だけが出て、App Translocation の一時的な場所では動かない。
2. PR のコメントの Download から、圧縮されていない DMG を直接ダウンロードできる。
3. インストール済みの版は、appcast の `enclosure` が DMG を指していても、Sparkle で新しい版へ利用者の追加の操作なしに更新できる。更新の後のアプリは「アプリケーション」フォルダーの同じ場所にあり、Gatekeeper の画面が出ない。
4. Debug の確認用ビルドの `Capsaicin.app` を、`docs/manual/release.md` の手順どおり `Capsaicin Debug.app` に改名して「アプリケーション」フォルダーに置くと、正式版と並べて開け、ヘルパーをインストールできる。

## 外れたときに起きること

- 1 が外れたら、DMG の作り方か署名・公証の手順を直す。
- 2 が外れたら、確認用のビルドのアップロードのしかたと、PR のコメントの案内を見直す。
- 3 が外れたら、`DEC-SYS-028` の覆す条件に従い、更新だけ zip に戻すかを比べ直す。
- 4 が外れたら、`docs/manual/release.md` の、Debug の確認用ビルドを正式版と並べて入れる手順を見直す。

## 確かめ方

オーナーが実機で確かめる。アプリの起動と Sparkle の更新はエージェントが実行しない。

1. 主張1・2: DMG に変えた後の最初の確認用のビルド（`S-Preview` を付けた `develop` への PR、またはリリース用の PR）で、コメントの Download をブラウザで開き、ファイル名が `.dmg` で終わることを確かめる。DMG を開いてアプリを「アプリケーション」へ移して開き、`codesign -dv --verbose=2` と `spctl --assess -vv` で Developer ID と `source=Notarized Developer ID` を確かめる。設定の「ヘルパー」でヘルパーをインストールできることも確かめる。
2. 主張4: `develop` への PR の Debug の確認用ビルドで、`docs/manual/release.md` の手順どおりに正式版と並べて入れ、両方を開いて、Debug のアプリでヘルパーをインストールできることを確かめる。
3. 主張3: DMG で配る最初の安定版を公開した後、前の安定版を入れたまま、設定の「このアプリについて」で「今すぐ確認」を選んで更新する。更新の後に Gatekeeper の画面が出ないこと、アプリが「アプリケーション」の同じ場所にあること、新しい版が1つだけ動くことを確かめる。
4. 結果と未確認の項目を根拠に記録する。

## 結果

未確認。主張1・2・4は、Debug の確認用ビルドで確かめた（`EVID-SYS-005`）。主張1・2は、リリース用の PR の Release の確認用ビルドでも確かめた。このときは、開いてよいかの確認も出なかった（`EVID-SYS-006`）。主張3は、DMG で配る最初の安定版を公開した後に確かめる。
