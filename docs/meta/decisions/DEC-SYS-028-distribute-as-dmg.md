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
- DMG はボリューム名を `Capsaicin` にし、`Capsaicin.app` と、`/Applications` を指すシンボリックリンク `Applications` を入れる。ほかには、Finder の表示の設定（`.DS_Store`）と背景画像（`.background.tiff`）だけを隠しファイルとして入れる。形式は APFS・lzfse 圧縮（`ULFO`）にする。
- DMG を開いたウインドウは、白い背景に2つのアイコンを横に並べる。左上にアプリのアイコンと名前、アイコンの間に先へ向かって大きくなる3つの山の矢印、下にアプリの HUD をかたどった「Capsaicin → Applications」を描く。ファイル名のほかに説明の文は書かない。背景画像は `scripts/dmg/background.swift` が描き、配置は `scripts/dmg/settings.py` に書く。
- ビルドのジョブで、`just dist` と `just dist-debug` が dmgbuild を使い、ad-hoc 署名のアプリを入れた見た目だけの DMG（`Capsaicin-layout.dmg`）を作る。dmgbuild は `flake.lock` で固定し、手元では devShell、CI では `nix build .#dmgbuild` で入れる。CI のビルドのジョブは今までどおり devShell を評価しない（`DEC-SYS-015`）。
- 署名のジョブ（`DEC-SYS-021`）は、アプリを今までどおり署名・公証・staple した後、見た目の DMG を shadow file を付けてマウントし、中のアプリを署名したものに入れ替える。中身が上の4つのほかにあれば止める。マウントしたときに macOS が作る記録（`.fseventsd`）は、検査から除いて消す。変更を `diskutil image create from --shadow` で `ULFO` の DMG に書き出し、Developer ID で署名し、公証し、staple する。アプリと DMG のどちらも `stapler validate` と `spctl --assess` を通らなければ、artifact を作らずに止める。署名のジョブでは Apple のツールだけを動かし、dmgbuild は動かさない。
- ビルドのジョブから署名のジョブへアプリを渡す形は、`just dist` と `just dist-debug` が作る ad-hoc 署名の zip のまま変えない。zip と見た目の DMG は CI の中だけで使い、利用者には渡さない。
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

DMG の見た目:

- 背景も配置も付けない。Finder の既定の表示になり、アイコンの位置が決まらず、移す向きも示せない（不採用）。
- Finder を AppleScript で操作して `.DS_Store` を書かせる。CI のランナーで Finder の画面を動かすことになり、結果も安定しない（不採用）。
- 署名のジョブで dmgbuild を動かす。手順は短いが、秘密情報を扱うジョブでサードパーティのコードを動かすことになる（不採用）。
- ビルドのジョブで dmgbuild が作った `.DS_Store` と背景画像だけを渡し、署名のジョブが新しいボリュームに入れる。試作では、背景もアイコンの配置も消え、Finder の既定の表示に戻った。`.DS_Store` は作ったボリュームに結び付いている（不採用）。
- ビルドのジョブで dmgbuild が見た目の DMG を作り、署名のジョブが shadow file を通して中のアプリだけを入れ替える（採用）。ボリュームを作り直さないので、見た目が保たれる。試作で、入れ替えた後も背景と配置が残ることを確かめた。

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
- 見た目を決めるのはビルドのジョブで、署名のジョブはアプリを入れ替えるだけにすれば、`DEC-SYS-021` の、署名のジョブでは checkout もサードパーティのコードも動かさないという分け方を保てる。入れ替えた後の中身は署名のジョブが確かめてから署名する。
- dmgbuild を CI で Nix から入れるのは、Xcode の Python が 3.9 で、dmgbuild が求める 3.10 以上に足りないためである。`flake.lock` で固定すれば、手元と CI で同じ版を使える。

## 影響

- `DEC-SYS-015` と `DEC-SYS-021` の「zip」は、利用者に渡すものについては、この判断の DMG に変わる。`DEC-SYS-019` の `enclosure` と EdDSA 署名の対象も DMG に変わる。`DEC-SYS-023` の確認用のビルドも DMG になる。それぞれの判断のほかの結論は変えない。
- 署名のジョブは公証を2回待つので、確認用のビルドと公開が数分遅くなる。
- ビルドのジョブは Nix を入れて dmgbuild を取ってくるので、その分遅くなる。
- dmgbuild は内部で `hdiutil` を使う。macOS 27 では非推奨の警告が出るが、DMG は作れる。
- dmgbuild はボリュームを最小の大きさに縮める。署名のジョブは古いアプリを消してから写すので、署名で増える分は空きに収まる。収まらなければ `ditto` が失敗してジョブが止まる。
- アプリの拡張子を隠す印（Finder の情報）は付けない。付けるとバンドルの直下に Finder の情報が残り、`codesign --verify --strict` が通らない。印がなくても、拡張子をすべて表示する設定でなければ `.app` は表示されない。
- 隠しファイルを表示する設定の人には、ウインドウの外に置いた `.background.tiff` までスクロールできる。背景画像は下へ描き足してあり、途中で途切れない。
- インストール済みの版は、次の版を Sparkle で DMG から更新する。Sparkle 2 は DMG を扱えるが、この経路は実機でまだ確かめていない（`HYP-SYS-006`）。
- DMG をマウントしたまま中のアプリを開くと、App Translocation の一時的な場所で動き、Sparkle の更新もできない。DMG は利用者がアプリを移すよう促すだけで、この状態を防ぐものではない。
- README のインストールの手順、`docs/manual/release.md` の確認の手順、`AGENTS.md` の `dist` の説明を DMG に合わせる。
- 公開済みの版の zip と appcast は、そのまま残る。

## 覆す条件

- `HYP-SYS-006` が外れ、Sparkle が DMG から更新できないと分かったら、更新だけ zip に戻すかを比べ直す。
- Apple の公証で DMG を扱えなくなるか、DMG での配布を Apple が勧めなくなったら見直す。
- `diskutil image` での DMG の作成が CI で繰り返し失敗し、再実行で直らないときは、作り方を見直す。
- `hdiutil` が macOS から外れて dmgbuild が動かなくなったら、見た目の DMG の作り方を見直す。
- Finder が `.DS_Store` の背景や配置を読まなくなったら、見た目を付けるかを見直す。
