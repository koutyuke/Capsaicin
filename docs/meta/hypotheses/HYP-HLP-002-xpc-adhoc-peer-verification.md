---
schema: hypothesis
id: HYP-HLP-002
title: ad-hoc 署名では XPC の通信相手を安定して検証できない
status: open
affects: ["DEC-HLP-001"]
evidence: []
---

# HYP-HLP-002 ad-hoc 署名では XPC の通信相手を安定して検証できない

## 主張

アプリとヘルパーが ad-hoc 署名の場合、従来型の LaunchDaemon のヘルパーが XPC の接続相手を、コード署名の要件（Team ID など）で、再ビルドの後も変わらない条件として検証することはできない。

## 外れたときに起きること

`DEC-HLP-001` で XPC 方式を却下した理由の1つが崩れる。残る理由は書くコードの多さだけになるので、比べ直す。

## 確かめ方

1. 環境: 対応環境の Mac。ad-hoc 署名の試作アプリと LaunchDaemon のヘルパー。
2. ヘルパー側で接続相手のコード署名を検証する条件を、アプリの再ビルドの前後で同じものにできるかを試す。ad-hoc 署名では Team ID がないことを `codesign -dv` で確かめる。
3. 成功（主張どおり）: 再ビルドの後も変わらず、ほかのプログラムを拒める条件を作れない。失敗: そのような条件を作れる。

ヘルパーを LaunchDaemon として設置するのは永続的なシステム変更である。終わったら `sudo launchctl bootout system/<ラベル>` で止め、設置した plist と実行ファイルを削除する。

## 結果

未確認。
