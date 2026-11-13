---
schema: decision
id: DEC-SYS-013
title: CI は静的検査だけを Nix で動かし、テストとリリースのビルドは固定した配布バイナリで並列に動かす
status: accepted
supersedes: ["DEC-SYS-011", "DEC-SYS-012"]
superseded_by: []
requirements: ["REQ-SYS-005", "REQ-SYS-006"]
based_on: ["DEC-SYS-004", "DEC-SYS-006", "DEC-SYS-008", "DEC-SYS-010", "HYP-HLP-003"]
---

# DEC-SYS-013 CI は静的検査だけを Nix で動かし、テストとリリースのビルドは固定した配布バイナリで並列に動かす

## 結論

### CI（`.github/workflows/ci.yml`）

`main` への push、手動の実行、リリースからの呼び出しで、次のジョブを並列に実行する。

| ジョブ | 実行するもの | ツールの入れ方 |
| --- | --- | --- |
| Format and lint | `just fmt-check lint test-scripts` | Nix の devShell（`cachix/install-nix-action`） |
| Package tests | `just test-package` | `just` と XcodeGen の配布バイナリ |
| App tests | `just test-app` | `just` と XcodeGen の配布バイナリ |

- 1つが失敗しても残りは最後まで実行する。
- CI の合否は「All checks passed」のジョブだけで判断する。どれかが失敗、取り消し、スキップなら、このジョブも失敗する。このジョブは Ubuntu のランナーで動かす。
- テストのジョブは、`just` と XcodeGen を、上流の GitHub リリースの配布物から取得し、`.github/build-tools.env` に書いた SHA-256 と照合してから使う（`.github/actions/build-tools`）。版は `flake.lock` の版と一致させ、`just lint-build-tools`（`just lint` に含む）で一致を確かめる。
- 通常のビルドだけを確かめるジョブは置かない。`test-app` が同じ Debug のアプリをビルドする。

### リリース（`.github/workflows/release.yml`）

`v*` のタグの push で、次を行う。

1. CI を呼び出す。並列に、Package のジョブがタグと `v{MARKETING_VERSION}`（`project.yml`）の一致を確かめ、`just dist` で Release 構成・ad-hoc 署名のアプリの `Capsaicin-{版}.zip` と `SHA256SUMS.txt` を作る。
2. 両方が成功したら、Publish のジョブ（Ubuntu）が、zip にビルドの来歴の attestation（`actions/attest-build-provenance`）を付け、GitHub Release を作って2つのファイルを添付する。リリースノートは注釈付きタグの本文から取る。版が 1.0.0 未満ならプレリリースにする。

### 共通

- macOS のジョブは GitHub のホストランナー `xcode-27`（Apple Silicon、macOS 27）で動かし、Xcode 27.2 を選んで使う。
- 外部の Action はコミットの SHA で固定し、版をコメントで添える。権限は、Release を作る Publish のジョブにだけ書き込みを与える。
- 版は Semantic Versioning に従う。`project.yml` の `MARKETING_VERSION` を正とし、`CURRENT_PROJECT_VERSION` はリリースのたびに1増やす。

## 背景

ソースを公開し（`DEC-SYS-009`）、`main` だけで開発する（`DEC-SYS-010`）。配布物は公証しない（`DEC-SYS-004`）。開発ツールは Nix の devShell が供給する（`DEC-SYS-006`）。

最初の CI のログでは、ジョブごとの Nix の準備が約1分48秒かかった。内訳は、Nix の導入が31秒、flake の入力（nixpkgs のソース、treefmt-nix）の取得と評価が約57秒、devShell のツールの取得が約17秒である。テストのジョブで要るのは `just` と XcodeGen（合わせて約6 MiB）だけなのに、パッケージのビルドとテスト（約1分）より長い準備を毎回払っていた。

## 選択肢

- すべてのジョブで Nix の devShell を使う（`DEC-SYS-011`、`DEC-SYS-012`）。ツールの版が1か所で決まるが、テストのジョブごとに約1分48秒の準備がかかる（不採用）。
- テスト用に小さな devShell を作る。取得は約17秒から数秒に減るが、flake の入力の取得と評価（約57秒）は残る（不採用）。
- Nix のストアを GitHub のキャッシュに保存する。2 GiB 近いストアの復元が、cache.nixos.org からの取得より速い保証がなく、リポジトリあたり 10 GB の上限もある（不採用）。
- テストのジョブだけ、固定した配布バイナリを使う（採用）。
- 静的検査も Nix を外す。SwiftLint、SwiftFormat、Prettier、markdownlint、clang-format、Ruff などを個別に入れて版を固定することになり、手間が大きい（不採用）。
- 文書だけの変更でテストのジョブを飛ばす。テストのジョブを速くした後は、待ち時間が Format and lint のジョブで決まるので短くならず、判定を誤って検査を飛ばす危険だけが残る（不採用）。

## 理由

- テストのジョブの準備が、約1分48秒から、数 MB の取得と照合（数秒）になる。
- 配布バイナリの XcodeGen は、Nix の XcodeGen と同じプロジェクトを生成することを確かめた（`project.pbxproj` が一致）。
- 版の二重管理は、`just lint-build-tools` でずれを検出できる。
- Release ビルドは CI の結果に依存しないので、CI と並列にすると、リリースの所要時間が CI とほぼ同じになる。
- 合否を1つのジョブにまとめると、ジョブの数や名前を変えても、合否を見る場所が変わらない。
- attestation があれば、利用者は `gh attestation verify` で、zip がこのリポジトリのワークフローでビルドされたものかを確かめられる。

## 影響

- テストのジョブは、手元と違って Nix の devShell を通らない。`just` のレシピは手元と同じものを呼ぶ。
- `just` か XcodeGen の版を `flake.lock` で上げたら、`.github/build-tools.env` の版と SHA-256 も上げる。上げ忘れは `just lint` で失敗する。
- 配布バイナリの信用は、上流の GitHub リリースと、ワークフローに書いた SHA-256 による。SHA-256 は、上流の `SHA256SUMS`（`just`）と GitHub のリリースの digest で確かめてから書く。
- macOS のジョブは、CI で3つ、リリースで4つを同時に使う。GitHub Free の macOS の同時実行の上限（5つ）に収まる。
- CI のランナーでは `sudo xcode-select` で Xcode を選ぶ。使い捨てのランナーなので、開発機への永続的な変更を禁じる `AGENTS.md` の規則の対象外である。
- CI は macOS 27 の上で動くので、macOS 26 での動作は CI では確かめられない（`HYP-SYS-001`）。
- CI は、アプリを起動しないテストだけを実行する（`DEC-SYS-008`）。
- 外部の Action の版は自動では更新されない（`DEC-SYS-010`）。
- 最初のリリースを作る前に、`HYP-HLP-003` を確かめる（`docs/manual/release.md`）。

## 覆す条件

- `xcode-27` ランナーが廃止されたり、Xcode 27.2 がなくなったりしたら、ランナーと Xcode の版を見直す。
- `just` か XcodeGen が macOS 向けの配布物を出さなくなったら、テストのジョブも Nix に戻す。
- Nix の準備が大きく速くなったら（flake の評価のキャッシュなど）、テストのジョブも Nix に戻すかを比べ直す。
- macOS の同時実行の上限が変わったら、ジョブの分け方を見直す。
- Apple Developer Program に加入したら、署名と公証をリリースに足す（`DEC-SYS-004`）。
