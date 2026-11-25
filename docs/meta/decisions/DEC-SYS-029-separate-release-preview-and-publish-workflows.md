---
schema: decision
id: DEC-SYS-029
title: リリースの確認用のビルドと公開を、別のワークフローに分ける
status: accepted
supersedes: []
superseded_by: []
requirements: []
based_on: ["DEC-SYS-015", "DEC-SYS-021", "DEC-SYS-023", "DEC-SYS-028", "EVID-SYS-007", "HYP-SYS-007"]
---

# DEC-SYS-029 リリースの確認用のビルドと公開を、別のワークフローに分ける

## 結論

- `DEC-SYS-015` の「リリース（`.github/workflows/release.yml`）」のうち、確認用のビルドと公開を、2つのワークフローに分ける。確認用のビルドは `.github/workflows/release-preview.yml`（Release preview）が、`main` への PR を開いたとき、開き直したとき、更新したときに行う。公開は `.github/workflows/release.yml`（Release）が、`main` への PR を閉じたときに行う。確認用のビルドで appcast も作ること（次の項目）を除き、対象のブランチ、作るもの、権限、`sign-and-notarize.yml` の呼び出し（`DEC-SYS-021`、`DEC-SYS-028`）は変えない。
- appcast の署名と検査は、再利用ワークフロー `.github/workflows/release-appcast.yml` に切り出し、Release と Release preview の両方から、署名と公証の後に呼ぶ。確認用のビルドでも公開と同じ定義で appcast を作って確かめ、公開の前に、DMG の受け渡し、appcast の生成、署名の検査が通ることを確かめる。確認用のビルドで作った appcast は artifact に置くだけで、公開しない。
- 1つのワークフローの中で、イベントによって動くジョブを切り替えない。`develop` への PR の確認用ビルド（`DEC-SYS-023`）と同じ形にする。
- 各ワークフローでは、最初のジョブだけが動かす条件を持つ。Release の最初のジョブ（Package release）は、マージされたこと、同じリポジトリのブランチであること、`release/v*` か `hotfix/*` であることを条件にする。後続のジョブは `if:` を持たず、`needs` の鎖でつなぐ。既定の `success()` により、前のジョブがすべて成功したときだけ進み、最初のジョブが skipped なら後続も skipped になる。
- `!cancelled()` を使うのは、Release preview の結果のコメントだけにする。ビルド、署名と公証、appcast のどれかが失敗したときも `failed` を書き込むためである。
- Release preview は、同じ PR の古い実行を取り消す。Release は concurrency を持たず、実行を取り消さない。
- 分けたワークフローを hotfix で `main` に入れ、公開できなかった v0.2.0 を、その hotfix で公開する。hotfix では `MARKETING_VERSION` を 0.2.0 のままにし、`CURRENT_PROJECT_VERSION` だけを `main` の値より1つ上げる。`prepare-release` は、`main` の版と最新のタグが一致することを前提にするので、この状態では使えない。

## 背景

PR #26 をマージしたとき、Release ワークフローは成功として終わったが、Sign release appcast と Publish が skipped になり、v0.2.0 は公開されなかった（`EVID-SYS-007`）。確認用と公開用のジョブが同じ依存の図にあり、マージのときは確認用のジョブが skipped になる。Sign and notarize は `!cancelled()` で進めていたが、その後のジョブは既定の `success()` で評価され、skipped になった。`DEC-SYS-021` で Sign and notarize を間に入れてから、マージで公開したのは今回が初めてだった。確認用のビルドは毎回動いていたので、それまで気づかなかった。

失敗した実行を再実行しても、マージしたコミットのワークフローで動くので直らない。直したワークフローで公開するには、`main` への PR をもう一度マージする必要がある。

## 選択肢

- (a) 1つのワークフローのまま、Sign release appcast と Publish に `!cancelled()` と依存の結果の条件を足す。変更は小さいが、イベントごとに動くジョブが同じ図に混ざったままになる。ジョブを足すたびに同じ条件を書く必要があり、書き忘れると同じ形で公開が止まる（不採用）。
- (b) 確認用のビルドと公開を、2つのワークフローに分ける（採用）。
- (c) 公開を、タグの push や手動の実行（`workflow_dispatch`）に移す。マージした時点の PR の本文をリリースノートにする流れ（`DEC-SYS-015`）を作り直すことになる（不採用）。

版の扱い:

- v0.2.0 のまま公開する（採用）。`CURRENT_PROJECT_VERSION` だけを手で上げる。オーナーが実機で確かめた 0.2.0 を、そのリリースノートのまま出せる。PR の規則と公開のジョブの検査（`v0.2.0` のタグがないこと、ビルド番号が上がっていること）は通る。
- オーナーが `0b5c258` にタグ `v0.2.0` を作り、`prepare-release patch` で v0.2.1 として公開する。GitHub Release のない `v0.2.0` のタグが、削除も更新もできないまま残る（不採用）。
- `prepare-release` に、マージしたが公開していない版を扱う処理を足す。めったに起きない状態のための処理で、hotfix の範囲を超える（不採用）。

## 理由

- 通常の経路では、どちらのワークフローにも skipped になるジョブがなくなる。依存の鎖だけで、前のジョブが成功したときに進むことが決まり、条件の書き忘れで止まる余地がない。
- 公開の後半（appcast の生成と検査）は、v0.1.0 を公開した後に足したもので、まだ本番で動いたことがない。確認用のビルドで同じ定義を動かせば、マージの後にしか通らないのは Publish のジョブだけになる。Publish は、確認用のビルドでも使う Action で artifact を受け取り、チェックサムとリリースノートを書き、attestation を付けて GitHub Release を作る。attestation と GitHub Release の作成は、v0.1.0 の公開で動いた手順とほぼ同じである（`EVID-SYS-007`）。
- 同じ形の `debug-preview.yml` が、署名の再利用ワークフローを含めて動いている（`EVID-SYS-007`）。
- マージで公開する流れ、`closed` のイベントから読むもの、ルールセットが必須にするチェック（All checks passed、PR policy）は変わらない。

## 影響

- `.github/workflows/release.yml` を公開だけにし、`.github/workflows/release-preview.yml` と `.github/workflows/release-appcast.yml` を足す。`docs/manual/release.md` に、公開を確かめるときにジョブの結果と GitHub Release を見ることと、ワークフローの誤りで公開できなかったときの直し方を足す。
- Sparkle の秘密鍵（`DEC-SYS-019`）を、マージのときだけでなく、リリース用と hotfix の PR を更新するたびに使う。鍵を渡すのは、checkout をせずリポジトリのコードを動かさない appcast のジョブだけである。ただし `pull_request` のイベントでは、ワークフローの定義を PR のマージ用の ref から読むので、マージ前のブランチの定義で鍵を扱う機会が増える。リポジトリに書き込める人は、もともとほかのワークフローで secret を読めるので、その人たちに対する境界は変わらない。Developer ID と公証の secret も、確認用のビルドで同じように扱っている。確認用の appcast は、PR の head からビルドして署名と公証をした DMG を指すもので、Actions の artifact として残る。
- 確認用のビルドは、appcast の分だけ数分遅くなる。
- 確認用のビルドは、appcast にリリースノートを埋め込むため、PR の本文が空だと失敗する。
- Publish のジョブが正しく動くかは、マージするまで確かめられない（`HYP-SYS-007`）。
- v0.2.0 のビルド番号は、確認したビルド（4）と公開するビルド（5）で変わる。v0.2.0 のリリース用の PR の本文は、hotfix の PR の本文に載せ直す。

## 覆す条件

- `HYP-SYS-007` が外れ、分けたワークフローでも公開まで進まないと分かったら、見直す。
- GitHub Actions のジョブの条件や依存の扱いが変わったら、見直す。
