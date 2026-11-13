---
schema: task
id: TASK-074
title: クイック設定の選択肢の字下げをやめて区切りで囲み、クイック設定の行の副題をなくす
status: done
requirements: ["REQ-MENU-007"]
depends_on: ["TASK-073"]
assignee: PM（Claude）
---

# TASK-074 クイック設定の選択肢の字下げをやめて区切りで囲み、クイック設定の行の副題をなくす

## 目的

`DEC-MENU-008` を、仕様・手順書・実装・テストに反映する。オーナーが作業ツリーで字下げと区切りを外した変更を出発点にし、変更が小さいため PM が直接行う。

## 範囲

- `docs/specs/menu.md`（`SPEC-MENU-008`、判断の参照）、`docs/specs/settings.md`（`SPEC-SET-006`、判断の参照）、`docs/meta/requirements/menu.toml`（判断の参照）、`docs/manual/verification.md`（クイック設定の確認）
- `Sources/Capsaicin/MenuBar/`、`Tests/CapsaicinTests/MenuBar/`

## 作るもの

- 「ディスプレイを閉じたとき」の見出しの前の区切りを戻し、選択肢を字下げしない。使わなくなった字下げの仕組み（`MenuEntry.indentationLevel` と、それを `NSMenuItem` に渡す処理）と古いコメントを消す。
- 「クイック設定」の行の副題と、その文言のキーを消す。
- テストの期待を合わせる。

## 完了条件

- `nix develop --command just lint`、`just test`、`just build` が通る。`just fmt-check` は、オーナーの未追跡の `buildServer.json` の整形差分だけで落ちる。

## 検証

上のコマンドの結果。見た目は、手順書の 8.6 でオーナーが確かめる。
