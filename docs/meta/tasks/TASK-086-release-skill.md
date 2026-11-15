---
schema: task
id: TASK-086
title: リリースの準備を進めるスキル capsaicin-release を作る
status: done
requirements: []
depends_on: []
assignee: 実装者（Codex、OpenCode の openai/gpt-5.6-sol）
---

# TASK-086 リリースの準備を進めるスキル capsaicin-release を作る

## 目的

`DEC-SYS-014` の「リリースの流れ」の2と5を、エージェントが同じ手順で進められるようにする。

## 範囲

- `.agents/skills/capsaicin-release/SKILL.md`（新規）
- `.claude/skills/capsaicin-release`（新規。`../../.agents/skills/capsaicin-release` への相対パスの symlink）

`skills-lock.json` には載せない（自作のスキルなので、`AGENTS.md` の「エージェントのスキル」の規約どおり）。

## 作るもの

Front Matter に `name: capsaicin-release` と、いつ使うかが分かる `description` を書く（オーナーが「リリースして」「リリースの準備をして」「hotfix を出して」と頼んだときなど）。既存の自作のスキル `.agents/skills/agent-team/SKILL.md` の形を参考にする。

本文は次の手順にする。規則そのもの（版の決め方、ブランチ、ラベル）は `DEC-SYS-014` を参照させ、繰り返さない。

1. **準備**: 通常のリリースなら `develop` で `nix develop --command just prepare-release` を、緊急の修正なら `hotfix/*` で `nix develop --command just prepare-release patch` を実行する。止まったら、理由をオーナーに伝えて終える。止まった原因を自分で回避しない。
2. **材料を読む**: `.build/release/v{版}.json` を読む。
3. **互換性を確かめる**: 材料の各 PR の差分（`gh pr diff <番号>`）を読み、`I-Breaking` が付いていないのに、CLI の引数や出力、設定の保存形式を変えている PR を探す。CLI のコードと、設定を保存するコードがどこにあるかは、スキルに具体的なパスで書く（リポジトリを調べて書く）。疑わしい PR があれば、オーナーに報告して判断を仰ぐ。ラベルを直したら、`release/v{版}` を消して 1 からやり直す。
4. **リリースノートを書く**: 次の形で書く。`T-Refactor`、`T-Test`、`T-Chore`、`T-Documentation` の PR は載せない。各行は利用者が読む文にし、PR のタイトルを写さない。総括は下書きを書き、HTML コメントの代わりに本文として置く。

   ```md
   ## English

   {総括}

   - **Action required:** … (#20)
   - Added … (#12)
   - Fixed … (#15)

   ---

   ## 日本語

   {総括}

   - **要対応:** … (#20)
   - …を追加しました。 (#12)
   - …を修正しました。 (#15)

   ---

   **Full Changelog**: https://github.com/koutyuke/Capsaicin/compare/{前回のタグ}...v{版}
   ```

   並べる順番は、要対応（`I-Breaking`）、機能（`T-Feature`、`T-Enhancement`）、修正（`T-Bug`）。緊急の修正では、材料のコミットから書く。日本語の節は `~/.claude/skills/yomiyasu/SKILL.md` に従って推敲する。リポジトリの用語（`DEC-UI-011` などの判断にある画面の用語）に合わせる。
5. **オーナーに見せる**: 版、リリースノート、材料の一覧との対応（載せた PR と載せなかった PR）を見せ、push と PR の作成の承認を求める。
6. **push と PR**: 承認されたら、ブランチを push し、`gh pr create --base main` で PR を作る。通常のリリースはタイトル `Release v{版}`、ラベル `S-Release`。緊急の修正はタイトル `Release v{版}`、ラベル `S-Hotfix` と、オーナーに確かめた種類のラベル。本文はリリースノートにし、末尾に材料の一覧を HTML コメントで添える。PR の URL をオーナーに伝える。
7. **マージの後**: オーナーに頼まれたら、戻しマージを行う。`develop` に `origin/main` を merge commit で取り込み、承認を得てから push する。`release/*` が開いていれば、そこにも取り込む。`project.yml` の版の行が競合したら、取り込む側の版を採る。

## 守ること

- `main`、`develop` へのマージ、タグの作成と push、GitHub の設定の変更はしない。
- push と PR の作成、戻しマージの push は、その都度オーナーの承認を得てから行う。
- スキルの本文は、エージェントが迷わず従える長さにする（目安 150 行以内）。

## 完了条件

- `nix develop --command just check` が通る（`.agents/skills/` は整形と Markdown の lint の対象外）。
- `ls -l .claude/skills/capsaicin-release` で symlink の向きを確かめる。
- 報告に、3 で書いた CLI と設定のコードのパスを書く。

## 検証

上のコマンドの結果と、差分の確認。

## レビュー

- PM が、緊急の修正で機能や互換性を壊す変更が混ざっていないかを `git diff origin/main...HEAD` で確かめ、混ざっていれば止める手順を3に足した。
- それ以外は `DEC-SYS-014` どおりで指摘なし。
- 全体の検証: `nix develop --command just check` と actionlint が通った（2026-11-15）。
