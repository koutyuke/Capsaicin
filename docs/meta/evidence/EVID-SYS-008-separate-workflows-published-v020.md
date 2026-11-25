---
schema: evidence
id: EVID-SYS-008
title: 分けた Release preview は hotfix の PR で appcast まで通り、分けた Release はマージで v0.2.0 を公開した
observed_on: 2026-11-25
environment: GitHub Actions、PR #27（`hotfix/split-release-workflows` → `main`）、head `5104039`、マージのコミット `f767bf2`
sources: ["https://github.com/koutyuke/Capsaicin/pull/27", "https://github.com/koutyuke/Capsaicin/actions/runs/45642696751", "https://github.com/koutyuke/Capsaicin/actions/runs/45644678289", "https://github.com/koutyuke/Capsaicin/releases/tag/v0.2.0"]
---

# EVID-SYS-008 分けた Release preview は hotfix の PR で appcast まで通り、分けた Release はマージで v0.2.0 を公開した

## 確かめた事実

- **PR の更新:** PR #27 を開いたとき、Release preview ワークフロー（run 45642696751）が動いた。Mark release preview building、Package release preview、Sign and notarize、Sign release appcast、Comment release preview の5つのジョブがすべて成功した。Sign release appcast のログには `One item, archive signature, tag URL, and feed signature checked` が出た。PR の `Release preview` コメントは、`5104039` の `ready`（Developer ID · notarized · stapled）になった。
- **PR の更新で Release は動かない:** PR #27 のブランチで動いた実行は、CI が1回、PR policy が3回、Release preview が1回、Release が1回だった。Release の1回は、マージのとき（`closed`）の実行だけである。
- **マージ:** PR #27 をマージしたときの Release ワークフロー（run 45644678289、`pull_request` の `closed`）は、Package release、Sign and notarize、Sign release appcast、Publish の4つのジョブがすべて成功した。実行のジョブに、Release preview のジョブは含まれていなかった。
- **公開物:** タグ `v0.2.0` の GitHub Release「Capsaicin 0.2.0」が、Latest として公開された。プレリリースではなく、immutable で、対象はマージのコミット `f767bf2` だった。添付は `Capsaicin-0.2.0.dmg`、`SHA256SUMS.txt`、`appcast.xml` の3つだった。
- **公開物の検査:** ダウンロードした DMG は `SHA256SUMS.txt` と一致し、`gh attestation verify` は終了コード 0 で通った。`spctl --assess --type open --context context:primary-signature -vv` は `accepted`、`source=Notarized Developer ID`（Team ID `GG7W7F3CTU`）だった。`appcast.xml` の項目は、`sparkle:version` が 5、`sparkle:shortVersionString` が 0.2.0 で、`https://github.com/koutyuke/Capsaicin/releases/download/v0.2.0/Capsaicin-0.2.0.dmg` を指していた。

## 確かめ方

- `gh run list --branch hotfix/split-release-workflows` で、PR #27 のブランチで動いた実行を数えた。
- `gh run view 45642696751 --json jobs` と `gh run view 45644678289 --json event,jobs` でジョブの結果を、`gh run view 45642696751 --log` で appcast の検査の出力を読んだ。
- `gh release view v0.2.0` と `gh release list` で、公開の状態と添付ファイルを読んだ。
- `gh release download v0.2.0` で添付ファイルを取得し、`shasum -a 256 -c SHA256SUMS.txt`、`gh attestation verify Capsaicin-0.2.0.dmg --repo koutyuke/Capsaicin`、`spctl --assess` を実行し、`appcast.xml` を読んだ。

## 適用範囲

- 使ってよい: `DEC-SYS-029` の2つのワークフローと `release-appcast.yml` が、同じリポジトリの `hotfix/*` から `main` への PR で、確認用のビルドと公開を行えることを判断するとき。
- 使ってはいけない: `release/v*` からの PR（同じワークフローの同じ条件だが、この根拠では動かしていない）。公開した appcast から Sparkle で更新できること。

## 未確認のこと

- `release/v*` から `main` への PR での実行。
- Sparkle が、公開した `appcast.xml` から更新を見つけて入れられること（`HYP-SYS-004` の主張3、`HYP-SYS-006` の主張3）。
