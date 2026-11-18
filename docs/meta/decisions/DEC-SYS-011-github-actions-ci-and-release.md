---
schema: decision
id: DEC-SYS-011
title: GitHub Actions で検査し、タグの push で GitHub Release を作る
status: superseded
supersedes: []
superseded_by: ["DEC-SYS-013"]
requirements: []
based_on: ["DEC-SYS-004", "DEC-SYS-006", "DEC-SYS-008", "DEC-SYS-010", "HYP-HLP-003"]
---

# DEC-SYS-011 GitHub Actions で検査し、タグの push で GitHub Release を作る

## 結論

- CI（`.github/workflows/ci.yml`）は、`main` への push と手動の実行で、`nix develop --command just check` と `just build` を実行する。
- リリース（`.github/workflows/release.yml`）は、`v*` のタグの push で次を行う。
  1. タグが `v{MARKETING_VERSION}`（`project.yml`）と一致することを確かめる。
  2. `just check` を実行する。
  3. `just dist` で、Release 構成・ad-hoc 署名のアプリを `Capsaicin-{版}.zip` にし、SHA-256 を `SHA256SUMS.txt` に書く。
  4. zip にビルドの来歴の attestation（`actions/attest-build-provenance`）を付ける。
  5. GitHub Release を作り、zip と `SHA256SUMS.txt` を添付する。リリースノートは注釈付きタグの本文から取る。版が 1.0.0 未満ならプレリリースにする。
- どちらも GitHub のホストランナー `xcode-27`（Apple Silicon、macOS 27）で動かし、Xcode 27.2 を選んで使う。Nix は `cachix/install-nix-action` で入れる。
- 外部の Action はコミットの SHA で固定し、版をコメントで添える。ワークフローの権限は必要な最小限にする。
- 版は Semantic Versioning に従う。`project.yml` の `MARKETING_VERSION` を正とし、`CURRENT_PROJECT_VERSION` はリリースのたびに1増やす。

## 背景

ソースを公開し（`DEC-SYS-009`）、`main` だけで開発する（`DEC-SYS-010`）。配布物は公証しない（`DEC-SYS-004`）。開発ツールは Nix の devShell が供給し、Swift と SDK はホストの Xcode を使う（`DEC-SYS-006`）。手元の開発環境は Xcode 27.2 を前提にしている。

## 選択肢

- `macos-26` ランナー。macOS 26 の上で検査できるが、入っている Xcode は 26 系で、Xcode 27.2（Swift 6.4）を前提にしたビルドができない（不採用）。
- `xcode-27` ランナー。macOS 27 の上で、Xcode 27.2 を選べる（採用）。
- 自前の macOS ランナー。開発機に常駐させることになり、`AGENTS.md` の禁止事項に触れる（不採用）。
- リリースを手元でビルドしてアップロードする。どのコミットからビルドしたかを利用者が確かめられない（不採用）。

## 理由

- 手元と同じ `nix develop --command just …` の入口を CI でも使うので、CI だけの検査手順が増えない。
- 公開リポジトリでは標準のホストランナーを無料で使える。
- attestation があれば、利用者は `gh attestation verify` で、zip がこのリポジトリのワークフローでビルドされたものかを確かめられる。公証しない配布物の信用を補える。
- 公証しない配布物を正式な版として出す前提（`HYP-HLP-003`）が確かめられていないため、1.0.0 未満はプレリリースとして区別する。

## 影響

- `justfile` に `build-release` と `dist` を足す。成果物は `.build/dist/` に置く。
- CI のランナーでは `sudo xcode-select` で Xcode を選ぶ。使い捨てのランナーなので、開発機への永続的な変更を禁じる `AGENTS.md` の規則の対象外である。
- CI は macOS 27 の上で動くので、macOS 26 での動作は CI では確かめられない。macOS 26 での確認は実機で行う（`HYP-SYS-001`）。
- CI は、アプリを起動しないテストだけを実行する（`DEC-SYS-008`）。ヘルパーの設置や `pmset` の変更は CI でも行わない。
- 外部の Action の版は自動では更新されない（`DEC-SYS-010`）。更新するときは、リリースノートと差分を読んでから SHA を差し替える。
- 最初のリリースを作る前に、`HYP-HLP-003` を確かめる（`docs/manual/release.md`）。

## 覆す条件

- `xcode-27` ランナーが廃止されたり、Xcode 27.2 がなくなったりしたら、ランナーと Xcode の版を見直す。
- 公開リポジトリのホストランナーが有料になったら、CI を走らせる契機を減らすか、自前のランナーを比べ直す。
- Apple Developer Program に加入したら、署名と公証をリリースに足す（`DEC-SYS-004`）。
