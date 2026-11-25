---
schema: evidence
id: EVID-SYS-007
title: 確認用と公開用を1つにした Release ワークフローは、マージで公開のジョブを skipped にし、成功として終わった
observed_on: 2026-11-25
environment: GitHub Actions、PR #26（`release/v0.2.0` → `main`）のマージ、マージのコミット `0b5c258`
sources: ["https://github.com/koutyuke/Capsaicin/actions/runs/45636519614", "https://github.com/koutyuke/Capsaicin/actions/runs/43723141263", "https://github.com/koutyuke/Capsaicin/actions/runs/45611133120", "https://docs.github.com/en/actions/reference/workflows-and-actions/expressions", "0b5c258:.github/workflows/release.yml"]
---

# EVID-SYS-007 確認用と公開用を1つにした Release ワークフローは、マージで公開のジョブを skipped にし、成功として終わった

## 確かめた事実

- **v0.2.0 のマージ:** PR #26 をマージしたときの Release ワークフローの実行（run 45636519614、`pull_request` の `closed`）は、成功として終わった。ジョブの結果は、Package release と Sign and notarize が成功、Mark release preview building、Package release preview、Comment release preview、Sign release appcast、Publish が skipped だった。タグ `v0.2.0` と GitHub Release は作られず、Latest は v0.1.0 のままだった。
- **そのときのワークフロー:** `0b5c258` の `.github/workflows/release.yml` では、Sign and notarize が `needs: [preview-package, release-package]` と `!cancelled()` を含む `if:` を持っていた。Sign release appcast は `needs: [release-package, sign-and-notarize]` で `if:` を持たず、Publish の `if:` は状態を確かめる関数を含まなかった。マージのときは Package release preview が skipped になる。Sign release appcast は、直接の依存の Package release と Sign and notarize がどちらも成功したのに skipped になった。
- **既定の条件:** GitHub Docs の「Expressions」の「Status check functions」は、状態を確かめる関数を含めない限り、既定で `success()` を当てると書いている（"A default status check of `success()` is applied unless you include one of these functions."）。
- **v0.1.0 のマージ:** Sign and notarize がなかったときの v0.1.0 のマージの実行（run 43723141263、`pull_request` の `closed`）では、Publish は Package release だけに依存しており、成功した。`closed` のイベントの内容から、マージされたこと、マージのコミット、PR の本文とラベルを読めた。
- **同じ形の確認用ビルド:** `debug-preview.yml` は、条件を持つ最初のジョブ、`if:` を持たないビルド、`if:` を持たない `sign-and-notarize.yml` の呼び出し、`!cancelled()` の結果のコメント、の順につながっている。その実行（run 45611133120）では、4つのジョブがすべて成功した。

## 確かめ方

- `gh run view 45636519614 --json jobs` と `gh run view 43723141263 --json event,jobs` と `gh run view 45611133120 --json jobs` で、ジョブの結果を読んだ。
- `gh release list` と `git ls-remote --tags origin` で、v0.2.0 のリリースとタグがないことを読んだ。
- `0b5c258` の `.github/workflows/release.yml` と、`.github/workflows/debug-preview.yml` を読んだ。
- GitHub Docs の「Expressions」を読んだ。

## 適用範囲

- 使ってよい: Release ワークフローのジョブの依存と条件を決めるとき。`closed` のイベントで公開できることを判断するとき。
- 使ってはいけない: 分けた後の `release.yml` と `release-preview.yml` が動くこと。それは `HYP-SYS-007` で確かめる。

## 未確認のこと

- GitHub Docs の「Workflow syntax」の `jobs.<job_id>.needs` の節に、失敗や skipped が依存の鎖の下流に及ぶと書かれていることは、ページの要約で読んだだけで、原文では確かめていない。上の実行の結果は、この規則と食い違わない。
- マージのときに、どのコミットのワークフローの定義を使うかは、文書の原文では確かめていない。
