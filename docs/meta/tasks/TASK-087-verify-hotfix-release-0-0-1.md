---
schema: task
id: TASK-087
title: 0.0.1 のテスト版で緊急の修正の経路を確かめる
status: done
requirements: []
depends_on: ["TASK-082", "TASK-083", "TASK-084", "TASK-086"]
assignee: PM（Claude）
---

# TASK-087 0.0.1 のテスト版で緊急の修正の経路を確かめる

## 目的

`DEC-SYS-014` と `DEC-SYS-015` の流れが GitHub 上で動くことを、緊急の修正の経路で確かめる。通常のリリースは MINOR を上げるので、`0.0.x` で試せるのはこの経路だけである。

## 範囲

- `hotfix/verify-release-flow` ブランチ（このチケットと `TASK-080` の状態の更新だけを入れる）
- `just prepare-release patch` とスキル `capsaicin-release` による `0.0.1` の PR
- マージ後の `develop` への戻しマージ

push、PR の作成、マージ、戻しマージの push は、それぞれオーナーの承認を得てから行う。

## 完了条件

- PR で PR policy と CI が通り、確認用のビルドのコメントが付く。
- マージで GitHub Release `v0.0.1` がプレリリースとして公開され、PR の本文がリリースノートになり、zip が `gh attestation verify` を通る。
- 戻しマージの後、`v0.0.1` が `develop` から辿れる。

## 検証

上の完了条件を、ワークフローの結果と GitHub Release の内容で確かめる。

## レビュー

- `just prepare-release patch` が `0.0.1`（`CURRENT_PROJECT_VERSION` 2）のコミットと材料を作った。スキル `capsaicin-release` の手順で、承認を得てから push し、PR #1 を作った。
- PR #1 で PR policy、CI（All checks passed）、確認用のビルドが通り、ダウンロード先のコメントが付いた。確認用の zip は `SHA256SUMS.txt` と一致し、アプリの版は 0.0.1、ビルド番号は 2 だった。
- マージで Release ワークフローの Package release と Publish が成功した。`v0.0.1` はマージのコミット `ee93a02` を指し、プレリリースかつ immutable で、PR の本文がリリースノートになった。zip は `gh attestation verify` を通った。
- 戻しマージの後、`v0.0.1` が `develop` から辿れる（2026-11-15）。

