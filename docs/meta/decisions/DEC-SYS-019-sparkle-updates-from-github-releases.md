---
schema: decision
id: DEC-SYS-019
title: Sparkle 2 で、GitHub Releases の安定版だけをアプリから更新する
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-SYS-008", "REQ-SET-007"]
based_on: ["DEC-SYS-004", "DEC-SYS-015", "DEC-SYS-016", "HYP-SYS-002"]
---

# DEC-SYS-019 Sparkle 2 で、GitHub Releases の安定版だけをアプリから更新する

## 結論

- 更新の確認、手動の更新、自動の更新を、Sparkle 2（SwiftPM）で行う。`docs/product/overview.md` の非目標から「自動アップデート」を外す。公証しないこと（`DEC-SYS-004`）は変えない。
- Release 構成だけで更新を有効にする。Debug 構成は更新を確かめない。
- 配信するのは安定版だけである。プレリリース（`DEC-SYS-016`）は配信しない。ベータ版の経路（Sparkle のチャンネル）は作らない。
- 各 GitHub Release に、その版の1件だけを載せた `appcast.xml` を添付する。`SUFeedURL` は `https://github.com/koutyuke/Capsaicin/releases/latest/download/appcast.xml` にする。項目の `enclosure` は、その版のタグの固定 URL（`releases/download/v<版>/…`）を指す。プレリリースにも `appcast.xml` を添付する。
- 更新の zip と appcast を EdDSA で署名する。Info.plist で `SUVerifyUpdateBeforeExtraction` と `SURequireSignedFeed` を有効にする。秘密鍵はオーナーがログインキーチェーンを使わずに作り、リポジトリの Actions secret と、別の2か所の控えに置く。署名は、リポジトリを checkout しない macOS のジョブだけで行い、出力に `sparkle:edSignature` がなければ公開を止める。
- 自動の確認は既定でオンにし、許可を求めない（`SUEnableAutomaticChecks` を YES）。自動のダウンロードとインストールは既定でオフにし、利用者が選べる（`SUAutomaticallyUpdate` を NO）。定期の確認で新しい版が見つかってもウインドウを出さず、控えめに知らせる（Sparkle の gentle reminders）。見せ方は `DEC-UI-014`、抑止との関係は `DEC-LCY-005` にある。
- Release ワークフローで、公開する版の `CFBundleVersion` が、直前の latest の版より大きいことを確かめる。Sparkle はこの値で新旧を比べる。
- ヘルパーの版を照合する仕組みは、今は入れない。ヘルパー、sudoers のルール、LaunchDaemon のどれかを変える版を出すときに、インストール済みのものとの不一致を見つけて既存の修復（`SPEC-HLP-004`）へ案内する仕組みを、その版に含める。照合には実行ファイルのハッシュではなく、互換性の版の番号を使う。

## 背景

`DEC-SYS-004` の時点では v1 の利用者は作者だけで、自動アップデートは非目標だった。その後、GitHub のリポジトリを公開し、リリース用の PR のマージで GitHub Release を作る流れができた（`DEC-SYS-015`）。v0.1.0 を安定版として公開し、配布先ができた。オーナーは、更新の確認、手動の更新、自動の更新をアプリに入れると決めた。

アプリは ad-hoc 署名で公証しない。Developer ID を持たないので、Sparkle で鍵を入れ替える代わりの経路（Developer ID の Team ID の一致）は使えない。

## 選択肢

更新の方式:

- GitHub の API で最新版を確かめ、リリースのページを開くだけにする。依存は増えないが、手動と自動の更新ができない（不採用）。
- Homebrew の tap と `brew upgrade` に任せる。Homebrew を使わない利用者に届かず、アプリの中で確認できない（不採用）。
- Sparkle 2 を使う（採用）。

appcast の置き場所:

- 各リリースに添付し、`latest/download` から取る（採用）。GitHub の latest はドラフトとプレリリースを除くので、プレリリースを配信しない仕組みを自分で持たなくてよい。添付ファイルは immutable で、公開後に書き換えられない。問題のある版は、プレリリースに戻せば latest から外れる。
- GitHub Pages に置く。リリースと独立して appcast を直せるが、Pages の設定、公開のジョブ、公開の直列化が要る。プレリリースを除く判断も自分で持つ（不採用）。
- ブランチにコミットし、raw の URL から取る。保護されたブランチへワークフローから書き込む例外が要る（不採用）。

署名の検証の強さ:

- `SUVerifyUpdateBeforeExtraction` と `SURequireSignedFeed` を有効にする（採用）。
- 無効にし、鍵をなくしたときに備える。ad-hoc 署名のアプリでは、鍵をなくすとどちらの設定でも以後は自動で更新できない。無効にしても救えるものがない（不採用）。

## 理由

- Sparkle は、ad-hoc 署名のアプリを ad-hoc 署名の別ビルドへ更新できる。EdDSA の署名が旧版の公開鍵で通り、新版の署名が壊れていなければ受け入れ、cdhash の一致は求めない（Sparkle 2.10.1 の `Sparkle/SUUpdateValidator.m` の `validateUpdateForHost:…`）。実機での振る舞いは `HYP-SYS-002` で確かめる。
- appcast を各リリースに添付する方式は、Release ワークフローに添付するファイルを1つ足すだけで済み、プレリリースの扱いも GitHub の latest の定義に任せられる。
- 検証を強くする費用は Info.plist の2行と CI での feed の署名だけで、鍵をなくしたときの被害は変わらない。
- `generate_appcast` は、アプリの公開鍵と秘密鍵が合わないと警告だけを出し、署名のない appcast を書き出す（`generate_appcast/Appcast.swift`）。署名のない版を公開すると、その版の利用者は以後更新できないので、公開の前に止める。
- ヘルパーは `/Library/PrivilegedHelperTools/` の固定のパスにあり、アプリを入れ替えても動き続ける。受け付ける処理が `on` と `off` のままなら、古いヘルパーでも振る舞いは変わらない。ad-hoc 署名のビルドは再現できるとは限らず、ハッシュで比べると不一致の誤検知が起きうる。

## 影響

- Sparkle がアプリの実行時の依存になる。版は SwiftPM で固定する。同梱する Sparkle と KeyboardShortcuts のライセンスを、アプリの中で読めるようにする（`DEC-UI-014`）。
- Release ワークフローに、appcast を作って署名する macOS のジョブが増える。オーナーは鍵を作り、Actions secret に登録し、控えを保管する。鍵をなくすと、以後の更新は利用者が手で入れ直すしかない。
- appcast はあとから添付できない。プレリリースを安定版に格上げしても配信できるよう、プレリリースにも添付する。問題のある版を取り下げるときは、appcast を持つ版が latest に戻るようにする。v0.1.0 には appcast がないので、最初の Sparkle 対応版を取り下げると、更新の確認が失敗する。
- 取り下げても、すでに更新した利用者の版は戻らない。Sparkle は古い版へ戻さないので、次の PATCH を出して直す。
- v0.1.0 には Sparkle が入っていないので、最初の Sparkle 対応版だけは利用者が手で入れ替える。
- `DEC-SYS-016` の覆す条件にある「アプリ内の更新の仕組み」には当たるが、プレリリースを配信しないので、版にプレリリースの印を入れる必要はない。`DEC-SYS-016` は変えない。
- ヘルパーを変える版では、互換性の版の照合を同じ版に入れる必要がある。入れ忘れると、古いヘルパーが新しい処理を拒否する。

## 覆す条件

- `HYP-SYS-002` が外れ、Sparkle で更新した版が起動できない、または起動のたびに利用者の操作が要るとき。
- Apple Developer Program に加入し、Developer ID で署名するとき（鍵の入れ替えの経路と、検証の設定を見直す）。
- プレリリースを利用者に配信する必要が出たとき（チャンネルと、`DEC-SYS-016` の版の印を見直す）。
- appcast を版から独立して直す必要が繰り返し起きたとき（GitHub Pages などへの移動を見直す）。
