---
schema: hypothesis
id: HYP-HLP-001
title: SMAppService.daemon で登録したヘルパーは ad-hoc 署名では安定して動かない
status: open
affects: ["DEC-HLP-001"]
evidence: []
---

# HYP-HLP-001 SMAppService.daemon で登録したヘルパーは ad-hoc 署名では安定して動かない

## 主張

Apple Developer Program に加入せず、アプリとヘルパーを ad-hoc 署名（Xcode の Sign to Run Locally）にした場合、`SMAppService.daemon` で登録したヘルパーは、登録に失敗するか、再起動や再ビルドの後に起動しなくなることがある。

移行元は「ad-hoc 署名では不安定だと Apple の DTS が説明している」と述べるが、その説明の出典は確かめられていない。Apple Developer Forums では、DTS が「デーモンとアプリが同じ方法で署名されていること」を確かめるよう求めた回答は見つかった（https://developer.apple.com/forums/thread/757463 ）が、ad-hoc 署名が不安定だと述べた回答は見つかっていない。

## 外れたときに起きること

`DEC-HLP-001` で `SMAppService.daemon` を却下した理由の1つが崩れる。sudoers に頼らずに済む方式として、比べ直す。

## 確かめ方

1. 出典を探す: Apple Developer Forums と Apple の文書で、DTS が ad-hoc 署名と `SMAppService` の関係を説明した記述を探す。見つかれば根拠として残す。
2. 実際に試す: 環境は対応環境の Mac。ad-hoc 署名の試作アプリに `SMAppService.daemon` のヘルパーを入れ、登録し、Mac の再起動と、アプリの再ビルド（署名が変わる）の後にヘルパーが起動するかを確かめる。
3. 成功（主張どおり）: 登録に失敗する、または再起動か再ビルドの後に起動しないことがある。失敗: 登録でき、再起動と再ビルドの後も毎回起動する。

手順 2 は、ログイン項目と launchd へのヘルパーの登録という永続的なシステム変更を伴う。終わったら `SMAppService` の `unregister` で登録を解除し、システム設定の「ログイン項目と機能拡張」から消えたことを確かめる。消えない場合は `sfltool resetbtm` で背景項目の登録を初期化できるが、ほかのアプリの登録も初期化されるので、実行する前に利用者に確認する。

## 結果

未確認。
