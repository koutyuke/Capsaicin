---
schema: task
id: TASK-012
title: 切り替えたときの画面表示（HUD）を作る
status: done
requirements: []
depends_on: [TASK-003]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-012 切り替えたときの画面表示（HUD）を作る

## 目的

抑止の開始・解除・拒否を伝える HUD を、単独で動く部品として作る。どの場面で出すかの判断と、アプリへの組み込みは、`TASK-011` のモデルができてから行う。

## 範囲

書いてよい: `Sources/Capsaicin/HUD/`（新設。String Catalog の `HUD.xcstrings` を含む）、`Tests/CapsaicinTests/HUD/`。

触らない: `Sources/Capsaicin/App/`、`Sources/Capsaicin/MenuBar/`、`Packages/`、`docs/`、`project.yml`。

## 作るもの

仕様は `docs/specs/hud.md` の `SPEC-HUD-002`〜`SPEC-HUD-008` と、`docs/specs/ui.md`（`SPEC-UI-001`〜`SPEC-UI-007`）に従う。方式は `DEC-HUD-001`、`DEC-UI-004`、`DEC-UI-005` にある。

1. 表示する内容の型。
   - アイコン、状態、解除の条件または理由を持つ。
   - Core の `BlockingEvent` と `BlockingStatus` から、`SPEC-HUD-002` の表のとおりに作る関数を用意する。
2. パネル。
   - `NSPanel` の性質（`SPEC-HUD-003`）、寸法と素材（`SPEC-HUD-004`）、出入りの動き（`SPEC-HUD-005`）、続けて切り替えたときの置き換え（`SPEC-HUD-006`）、複数のディスプレイ（`SPEC-HUD-007`）、アクセシビリティの設定と VoiceOver の読み上げ（`SPEC-HUD-008`）を満たす。
   - 中身は SwiftUI で描く。
3. 表示の入口。`show(_ content:)` の1つだけにする。

文言は `HUD.xcstrings` に仮の日本語で入れる。`.t3-code/drafts/copy/copy-deck.md` に HUD の文言があれば、それを使う。

## 守ること

- テストで、パネルを画面に出さない。内容を作る関数と、置き換えの状態の判定を中心にテストする。
- ビューの見た目は、`DEC-SYS-008` のとおり、アプリを起動せずにビューを画像に描画して確かめてよい。描画した画像は `.build/` に置く。
- 短く素直に書く（`TASK-010` を参照）。本番コードに `REQ-*` と `SPEC-*` を書かない。`git commit` をしない。
- 同じ作業ツリーで、`TASK-011` の担当が `Sources/Capsaicin/App/` と `project.yml` を並行して変更する。そちらには触らない。

## 完了条件

- 上の 1〜3 がある。
- 内容を作る関数に、`SPEC-HUD-002` の表の各行のテストがある。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`

## レビュー

PM がレビューした。描画した画像（ライト・ダーク）で、カプセルの形と `SPEC-HUD-002` の並びを確かめた。指定時刻での解除の表示に要る解除前のセッションは、組み込みのときにモデルから渡す。実機での動き、フォーカス、クリックの透過、複数の画面、VoiceOver の読み上げは未確認である。
