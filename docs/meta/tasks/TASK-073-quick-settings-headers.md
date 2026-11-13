---
schema: task
id: TASK-073
title: クイック設定の見出しを閉じたときの項目名にだけ使い、選択肢を字下げする
status: done
requirements: ["REQ-MENU-007"]
depends_on: ["TASK-071", "TASK-072"]
assignee: PM（Claude）
---

# TASK-073 クイック設定の見出しを閉じたときの項目名にだけ使い、選択肢を字下げする

## 目的

`DEC-MENU-007` を、仕様・手順書・実装・テストに反映する。変更がクイック設定の中の並べ方と1つの文言だけと小さいため、PM が直接行う。

## 範囲

- `docs/specs/menu.md`（`SPEC-MENU-008`、判断の参照）、`docs/specs/settings.md`（`SPEC-SET-006`、判断の参照）、`docs/meta/requirements/menu.toml`（判断の参照）、`docs/manual/verification.md`（クイック設定の確認）
- `Sources/Capsaicin/MenuBar/`、`Tests/CapsaicinTests/MenuBar/`

## 作るもの

- クイック設定から「スリープとディスプレイ」「バッテリー」の見出しをなくし、区切りで分ける。
- 「ディスプレイを閉じたとき」の見出しの前に区切りを置き、選択肢を `indentationLevel` で1段字下げする。
- バッテリー残量の項目名にバッテリー残量であることを含める。
- テストの期待を合わせ、見出しが閉じたときだけであることと、字下げが選択肢だけであることを確かめる。

## 完了条件

- `nix develop --command just lint`、`just test`、`just build` が通る。`just fmt-check` は、オーナーの未追跡の `buildServer.json` の整形差分だけで落ちる。

## 検証

上のコマンドの結果。字下げの見た目は、手順書の 8.6 でオーナーが確かめる。
