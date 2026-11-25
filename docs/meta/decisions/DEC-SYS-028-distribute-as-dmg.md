---
schema: decision
id: DEC-SYS-028
title: 公開物、Sparkle の更新、確認用のビルドを、署名して公証した DMG で配る
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-SYS-008"]
based_on: ["DEC-SYS-015", "DEC-SYS-019", "DEC-SYS-021", "DEC-SYS-023", "HYP-SYS-006"]
---

# DEC-SYS-028 公開物、Sparkle の更新、確認用のビルドを、署名して公証した DMG で配る

## 結論

- 利用者が受け取るものを、zip から DMG に変える。対象は、GitHub Release に添付する公開物、Sparkle の appcast の `enclosure`、リリース用の PR と `develop` への PR の確認用のビルド（`DEC-SYS-015`、`DEC-SYS-023`）のすべてである。名前は zip の名前の拡張子を `.dmg` に変えたもの（`Capsaicin-{版}.dmg`、`Capsaicin-debug-pr{PR番号}-{コミットの先頭7桁}.dmg`）にする。
- DMG はボリューム名を `Capsaicin` にし、`Capsaicin.app` と、`/Applications` を指すシンボリックリンク `Applications` だけを入れる。形式は APFS・lzfse 圧縮（`ULFO`）にし、`diskutil image create from` で作る。macOS 27 では `hdiutil create` が非推奨で、`diskutil image` を使うよう警告が出る。背景画像やアイコンの配置は付けない。
- 署名のジョブ（`DEC-SYS-021`）は、アプリを今までどおり署名・公証・staple した後に DMG を作り、DMG を Developer ID で署名し、公証し、staple する。アプリと DMG のどちらも `stapler validate` と `spctl --assess` を通らなければ、artifact を作らずに止める。
- ビルドのジョブから署名のジョブへアプリを渡す形は、`just dist` と `just dist-debug` が作る ad-hoc 署名の zip のまま変えない。この zip は CI の中だけで使い、利用者には渡さない。
- 署名のジョブは DMG を `actions/upload-artifact` の `archive: false` でアップロードする。PR のコメントの Download からは DMG を直接ダウンロードできる。
- Sparkle の appcast の EdDSA 署名、`SHA256SUMS.txt`、ビルドの来歴の attestation は、staple した後の DMG に対して作る。`SHA256SUMS.txt` は公開のジョブが DMG から作る。

## 背景

`DEC-SYS-015` と `DEC-SYS-021` では、公開物も確認用のビルドも zip だった。ブラウザでダウンロードした zip を「ダウンロード」フォルダーで展開し、そのまま開くと、アプリは App Translocation の一時的な場所で動く。この状態ではヘルパーをインストールできず、設定の「ヘルパー」でエラーになる。利用者がアプリを「アプリケーション」フォルダーへ移すかどうかは、README の手順を読むかに任されていた。

Sparkle の文書は、Web で配る形として、Developer ID で署名して公証し、`/Applications` へのシンボリックリンクを入れた DMG を勧めている。Sparkle 2 は DMG・zip・tar・aar・pkg のどれからでも更新でき、Web で配るものと同じアーカイブを更新に使える（[Sparkle: Distributing your App](https://sparkle-project.org/documentation/)、[Publishing an update](https://sparkle-project.org/documentation/publishing/)）。

## 選択肢

利用者に渡す形:

- zip のままにする。変更はないが、App Translocation の状態で開く利用者を減らせない（不採用）。
- 初めてのダウンロードは DMG、Sparkle の更新は zip にする。更新の経路は変わらないが、公開物が2つになり、署名、公証、attestation、`SHA256SUMS.txt` をそれぞれに作る（不採用）。
- 公開物、更新、確認用のビルドをすべて DMG にする（採用）。

公証の回数:

- DMG だけを公証して staple する。公証は1回で済むが、DMG から取り出したアプリにはチケットが staple されていない。オフラインで初めて開くと、Gatekeeper がチケットを確かめられない（不採用）。
- アプリを公証して staple してから DMG を作り、DMG も公証して staple する（採用）。公証を2回待つ。

確認用のビルドの形:

- 確認用のビルドだけ zip のままにする。公開物と違う形で確かめることになる（不採用）。
- `archive: false` で DMG をそのままアップロードする（採用）。`actions/upload-artifact` v7 は、`archive: false` のときファイル1つだけを圧縮せずにアップロードし、artifact の名前はファイル名になる。`actions/download-artifact` v8 は、そのファイル名を `name` に指定して受け取れる。

## 理由

- DMG を開くと、`Capsaicin.app` と「アプリケーション」へのリンクが並び、アプリを移してから開く手順が画面から分かる。
- 公開物と更新が同じファイルなので、署名、公証、attestation、`SHA256SUMS.txt` の対象が1つで済む。
- アプリにもチケットを staple しておけば、DMG から取り出した後にオフラインで初めて開いても Gatekeeper を通る。
- 確認用のビルドも DMG にすれば、マージの前に公開物と同じ形で、開き方と署名を確かめられる。
- ビルドのジョブと署名のジョブの間の受け渡しは、実行権限とフレームワークのシンボリックリンクを保つために何かで包む必要がある。今の `ditto` の zip で足りるので変えない。

## 影響

- `DEC-SYS-015` と `DEC-SYS-021` の「zip」は、利用者に渡すものについては、この判断の DMG に変わる。`DEC-SYS-019` の `enclosure` と EdDSA 署名の対象も DMG に変わる。`DEC-SYS-023` の確認用のビルドも DMG になる。それぞれの判断のほかの結論は変えない。
- 署名のジョブは公証を2回待つので、確認用のビルドと公開が数分遅くなる。
- インストール済みの版は、次の版を Sparkle で DMG から更新する。Sparkle 2 は DMG を扱えるが、この経路は実機でまだ確かめていない（`HYP-SYS-006`）。
- DMG をマウントしたまま中のアプリを開くと、App Translocation の一時的な場所で動き、Sparkle の更新もできない。DMG は利用者がアプリを移すよう促すだけで、この状態を防ぐものではない。
- README のインストールの手順、`docs/manual/release.md` の確認の手順、`AGENTS.md` の `dist` の説明を DMG に合わせる。
- 公開済みの版の zip と appcast は、そのまま残る。

## 覆す条件

- `HYP-SYS-006` が外れ、Sparkle が DMG から更新できないと分かったら、更新だけ zip に戻すかを比べ直す。
- Apple の公証で DMG を扱えなくなるか、DMG での配布を Apple が勧めなくなったら見直す。
- `diskutil image` での DMG の作成が CI で繰り返し失敗し、再実行で直らないときは、作り方を見直す。
