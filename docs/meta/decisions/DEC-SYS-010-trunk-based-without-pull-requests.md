---
schema: decision
id: DEC-SYS-010
title: main だけで開発し、Pull Request を無効にして Issue だけを受け付ける
status: accepted
supersedes: []
superseded_by: []
requirements: []
based_on: ["DEC-SYS-009"]
---

# DEC-SYS-010 main だけで開発し、Pull Request を無効にして Issue だけを受け付ける

## 結論

- 公開リポジトリ（`koutyuke/Capsaicin`）では、`main` だけを共有のブランチにする。オーナーがレビューを済ませた変更を `main` にコミットして push する。作業用のブランチと worktree は手元だけに置き、push しない。
- Pull Request は、リポジトリの設定（Settings > General > Features）で無効にする。Issue は受け付ける。
- `main` には、ブランチの削除と force push を禁止するルールセットを付ける。ステータスチェックの必須化は付けない。
- リリースは、`main` のコミットに注釈付きのタグ `v{MARKETING_VERSION}` を付けて作る。`v*` のタグには、削除と更新を禁止するルールセットを付け、リリースは immutable にする。リリース用のブランチは作らない。
- リリースの手順は `docs/manual/release.md` にある。

## 背景

開発者はオーナー1人で、変更はエージェントが手元の worktree で作り、オーナーがレビューしてから `main` に取り込んでいる。ソースは公開する（`DEC-SYS-009`）が、外部からのコードの変更は受け付けず、不具合の報告と要望だけを受け付けたい。

## 選択肢

- GitHub Flow（作業ブランチを push して Pull Request で `main` に入れる）。Pull Request を無効にする方針と両立せず、1人の開発ではレビューの場が手元とリモートで二重になる（不採用）。
- git-flow（`develop` とリリースブランチを持つ）。並行して保守する版がなく、ブランチの管理だけが増える（不採用）。
- Pull Request を「Collaborators only」にする。外部からは作れなくなるが、オーナー自身も使わないので、無効にするのと差がない（不採用）。
- `main` だけのトランクベースで、Pull Request を無効にする（採用）。

## 理由

- 今の作業の流れ（手元でレビューして `main` に入れる）を変えずに公開できる。
- ステータスチェックを必須にすると、Pull Request を経ない `main` への push そのものが拒否される。CI は push の後に走らせ、落ちたら次のコミットで直す。
- タグとリリースを変更不可にすると、配布した zip と、そのビルド元のコミットとの対応が後から変わらない。

## 影響

- CI は `main` への push で走る（`DEC-SYS-013`）。`pull_request` のイベントは使わない。
- Pull Request を無効にすると、Dependabot などのボットも Pull Request を作れない。Action の版の更新は手で行う。
- Issue のテンプレートを `.github/ISSUE_TEMPLATE/` に置き、README に Pull Request を受け付けないことを書く。
- 過去の版の不具合は、その版を直さず、次の版で直す。
- Pull Request の無効化とルールセットは、リポジトリの設定で行う。コードで管理しない。

## 覆す条件

- 共同の開発者が加わったら、GitHub Flow と、ステータスチェックの必須化を比べ直す。
- 外部からのコードの変更を受け付けることにしたら、Pull Request を有効にし、受け付ける条件を決める。
- 過去の版を並行して保守する必要が生じたら、リリースブランチを検討する。
