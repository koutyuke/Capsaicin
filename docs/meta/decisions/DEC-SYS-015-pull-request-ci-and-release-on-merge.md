---
schema: decision
id: DEC-SYS-015
title: CI を PR で必須にし、main へのリリース用の PR のマージで GitHub Release を作る
status: accepted
supersedes: ["DEC-SYS-013"]
superseded_by: []
requirements: []
based_on: ["DEC-SYS-004", "DEC-SYS-006", "DEC-SYS-008", "DEC-SYS-014", "HYP-HLP-003"]
---

# DEC-SYS-015 CI を PR で必須にし、main へのリリース用の PR のマージで GitHub Release を作る

## 結論

### CI（`.github/workflows/ci.yml`）

`develop` と `main` への push と PR、手動の実行で、次のジョブを並列に実行する。ジョブの分け方とツールの入れ方は、`DEC-SYS-013` から変えない。

| ジョブ | 実行するもの | ツールの入れ方 |
| --- | --- | --- |
| Format and lint | `just fmt-check lint test-scripts` | Nix の devShell（`cachix/install-nix-action`） |
| Package tests | `just test-package` | `just` と XcodeGen の配布バイナリ |
| App tests | `just test-app` | `just` と XcodeGen の配布バイナリ |

- 1つが失敗しても残りは最後まで実行する。合否は Ubuntu で動く「All checks passed」のジョブだけで判断する。
- テストのジョブは、`just` と XcodeGen を上流の GitHub リリースの配布物から取得し、`.github/build-tools.env` の SHA-256 と照合してから使う。版は `flake.lock` と一致させ、`just lint-build-tools` で確かめる。
- 同じ PR の古い実行は取り消す。`develop` と `main` への push の実行は取り消さない。

### PR の規則（`.github/workflows/pr-policy.yml`）

PR を開いたとき、更新したとき、ラベルを変えたときに、Ubuntu の軽いジョブ「PR policy」で次を確かめる。

- `develop` への PR: 種類のラベル（`T-*`）がちょうど1つある。
- `main` への PR: head が `release/v*` か `hotfix/*` である。`release/*` なら `S-Release` があり、ブランチ名の版と `project.yml` の `MARKETING_VERSION` が一致する。`hotfix/*` なら `S-Hotfix` と種類のラベルがちょうど1つあり、`I-Breaking` がない。どちらも、`v{MARKETING_VERSION}` のタグがまだなく、`CURRENT_PROJECT_VERSION` が `main` の値より大きい（`DEC-SYS-022`）。

### ルールセット

| 対象 | 規則 | 例外 |
| --- | --- | --- |
| `main` | 削除と force push の禁止、PR の必須化、「All checks passed」と「PR policy」の必須化、ベースに追いついていることの必須化 | なし |
| `develop` | 削除と force push の禁止、PR の必須化、「All checks passed」と「PR policy」の必須化 | リポジトリの管理者（オーナー）は直接 push できる |
| `v*` のタグ | 削除と更新の禁止 | なし |

### リリース（`.github/workflows/release.yml`）

`release/v*` か `hotfix/*` から `main` への PR で動く。

- **確認用のビルド**: PR を開いたときと更新したときに、`just dist` で Release 構成・ad-hoc 署名の zip を作り、Actions の artifact としてアップロードする。PR には、ダウンロード先を示すコメントを1つだけ置き、更新のたびに書き換える。
- **公開**: PR がマージされたら、マージのコミットで `just dist` を実行し、zip にビルドの来歴の attestation（`actions/attest-build-provenance`）を付ける。マージした時点の PR の本文をリリースノートにして、タグ `v{MARKETING_VERSION}` の GitHub Release を作り、zip と `SHA256SUMS.txt` を添付してから公開する。PR に `S-Prerelease` があればプレリリースにする（`DEC-SYS-016`）。
- マージ前に必須のチェックがベースに追いついた状態で通っているので、公開のときに CI を実行し直さない。

### 共通

- macOS のジョブは GitHub のホストランナー `xcode-27` で動かし、Xcode 27.2 を選んで使う。
- 外部の Action はコミットの SHA で固定し、版をコメントで添える。書き込みの権限は、それが要るジョブにだけ与える（公開のジョブに `contents: write` と attestation の権限、PR へのコメントのジョブに `pull-requests: write`）。

## 背景

ブランチとリリースの運用を `DEC-SYS-014` に変えた。CI は `main` への push だけで動き、リリースは注釈付きタグの push で動いていた（`DEC-SYS-013`）。PR を使うので、マージの前に CI を通せるようになる。リリースノートは、タグの本文ではなく、リリース用の PR の本文に置く。

## 選択肢

- タグの push でリリースする形を残し、マージの後にオーナーがタグを打つ。マージとタグ打ちの二度手間になり、PR の本文をリリースノートにできない（不採用）。
- ワークフローがタグを push し、そのタグで別のワークフローを動かす。`GITHUB_TOKEN` で作ったタグは別のワークフローを起動しない（不採用）。
- マージの後にも CI を実行し直す。ベースに追いついた状態で必須のチェックが通っているので、同じ内容を二度確かめることになり、macOS のランナーを余計に使う（不採用）。
- PR のマージで、ビルドから公開までを1つのワークフローで行う（採用）。
- 試運転のモードを足す。版を消費しないで確かめられるが、本番で使わない分岐が増える。試すときは `0.0.x` の版で本番と同じ流れを通す（不採用）。

## 理由

- リリースが「PR のマージ」の1回の操作で済み、オーナーがマージの直前に直した本文が、そのままリリースノートになる。
- GitHub のリリースは immutable なので、公開の前に、CI が作った配布物と同じ構成のビルドを実機で確かめられると、問題のある版を出す危険が減る。
- PR の規則を CI と別の軽いジョブにするので、ラベルを付け直すたびに macOS のジョブが動かない。

## 影響

- `pull_request` のトリガーを使う。外部からの PR は、初めて貢献する人の実行に承認が要る設定（`first_time_contributors`）のままにする。
- 確認用のビルドで、リリース用の PR ごとに macOS のランナーを1つ使う。CI と合わせても、GitHub Free の macOS の同時実行の上限（5つ）に収まる。
- 戻しマージ（`DEC-SYS-014`）はワークフローで行わない。`develop` への直接 push を `GITHUB_TOKEN` に許すには、ルールセットの例外の設定が要り、その可否を確かめていないためである。
- CI のランナーでは `sudo xcode-select` で Xcode を選ぶ。使い捨てのランナーなので、開発機への永続的な変更を禁じる `AGENTS.md` の規則の対象外である。
- CI は macOS 27 の上で動くので、macOS 26 での動作は確かめられない（`HYP-SYS-001`）。CI はアプリを起動しないテストだけを実行する（`DEC-SYS-008`）。
- 最初の正式なリリースの前に `HYP-HLP-003` を確かめる。

## 覆す条件

- `xcode-27` ランナーが廃止されたり、Xcode 27.2 がなくなったりしたら、ランナーと Xcode の版を見直す。
- `just` か XcodeGen が macOS 向けの配布物を出さなくなったら、テストのジョブも Nix に戻す。
- `GITHUB_TOKEN` をルールセットの例外にできると確かめられたら、戻しマージをワークフローで自動にするかを見直す。
- macOS の同時実行の上限が変わったら、ジョブの分け方を見直す。
- Apple Developer Program に加入したら、署名と公証をリリースに足す（`DEC-SYS-004`）。
