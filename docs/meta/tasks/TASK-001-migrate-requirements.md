---
schema: task
id: TASK-001
title: 要件定義書を文書の層へ移す
status: in_progress
requirements: []
depends_on: []
assignee: Claude Opus 5.5
---

# TASK-001 要件定義書を文書の層へ移す

## 目的

`docs/requirements.md` の内容を、`docs/documentation-management.md` が定める層（製品、要件、仕様、判断、論点、仮説、根拠、計画）へ、意味を変えずに移す。

## 範囲

- 書いてよい: `docs/product/`、`docs/specs/`、`docs/meta/requirements/`、`docs/meta/decisions/`、`docs/meta/questions/`、`docs/meta/hypotheses/`、`docs/meta/evidence/`、`docs/meta/plans/`
- 触らない: `docs/requirements.md`（移行元。削除は PM がレビュー後に行う）、`docs/documentation-management.md`、`DEC-SYS-001`、テンプレート、`docs/meta/tasks/`、`docs/` の外
- ID はこの作業に限り担当エージェントが振る。`DEC-SYS-001` は使用済み。

## 完了条件

- 移行元のすべての記述が、いずれかの層に1回だけ現れる。どこにも移さなかった記述があれば、理由を報告する。
- 試作で確かめる項目（移行元 §6）が仮説になり、確かめ方と外れたときの影響を持つ。
- 将来の機能（移行元 §7）が計画になる。
- 却下した方式（移行元 §9）が、対応する判断の「選択肢」に入る。
- 要件の `specs` と仕様の `関連要件` が双方向で一致する。
- 根拠は、出典があるか自分で一次情報を確かめた事実だけにする。確かめられないものは仮説にする。

## 検証

文書の検査はまだないので、`documentation-management.md` の「検査」の項目を手で確かめる。

## レビュー

未実施。
