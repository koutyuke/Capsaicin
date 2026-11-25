---
schema: hypothesis
id: HYP-SYS-007
title: 分けた release-preview.yml は PR の更新で確認用のビルドを作り、分けた release.yml はマージで公開まで進む
status: open
affects: ["DEC-SYS-029"]
evidence: []
---

# HYP-SYS-007 分けた release-preview.yml は PR の更新で確認用のビルドを作り、分けた release.yml はマージで公開まで進む

## 主張

`DEC-SYS-029` で分けた2つのワークフローについて、同じリポジトリの `release/v*` か `hotfix/*` から `main` への PR で、次のすべてが成り立つ。

1. PR を開いたとき、開き直したとき、更新したときは、Release preview ワークフローが動き、Mark release preview building、Package release preview、Sign and notarize、Sign release appcast、Comment release preview の5つのジョブがすべて成功して、PR の `Release preview` コメントが `ready` になる。Sign release appcast は、署名と公証をした DMG を受け取り、署名した appcast を作って検査に通す。Release ワークフローは動かない。
2. PR をマージしたときは、Release ワークフローが動き、Package release、Sign and notarize、Sign release appcast、Publish の4つのジョブがすべて成功する。タグ `v{版}` の GitHub Release ができ、`Capsaicin-{版}.dmg`、`SHA256SUMS.txt`、`appcast.xml` が添付される。Release preview ワークフローは動かない。
3. マージした PR の Release ワークフローは、その PR で変えた `release.yml` の定義で動く。

## 外れたときに起きること

- 1 が外れたら、マージの前に `release-preview.yml` を直す。
- 2 か 3 が外れたら、公開されない。`DEC-SYS-029` を見直し、`docs/manual/release.md` の「失敗したとき」に従って、直した版を次の PATCH で出す。

## 確かめ方

1. 主張1: `DEC-SYS-029` を入れる hotfix の PR で、Actions の実行の一覧に Release preview が出て、5つのジョブが成功し、コメントが `ready` になることを確かめる。Sign release appcast のログで、「One item, archive signature, tag URL, and feed signature checked」が出ていることも確かめる。同じ PR のイベントで Release が動いていないことも確かめる。
2. 主張2・3: その PR をマージした後、`gh run view <実行の ID> --json jobs` で Release の4つのジョブがすべて success であることと、`gh release view v{版}` で3つの添付ファイルがあることを確かめる。分ける前の `release.yml` は Release preview のジョブを持っていたので、マージの実行に Release preview のジョブが含まれないことで、主張3を確かめる。
3. 結果を根拠に記録する。

## 結果

未確認。
