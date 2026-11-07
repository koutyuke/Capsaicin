---
schema: task
id: TASK-026
title: HUD の文字を、古い文字が消えてから新しい文字が現れる順に切り替える
status: done
requirements: ["REQ-HUD-001"]
depends_on: ["TASK-021"]
assignee: Claude（PM）
---

# TASK-026 HUD の文字を、古い文字が消えてから新しい文字が現れる順に切り替える

## 目的

オーナーが実機で、同じ幅のオンとオフを切り替えると、ぼかしが目に見えずチラつくことを指摘した。PM の見立ては次のとおりである。

- 文字の切り替えは 0.20 秒の ease-out で、変化の大半が最初の約 50 ms で終わっていた。
- 新旧の文字を同時に入れ替えていたため、共通の「スリープ防止」が一瞬薄くなってすぐ戻り、チラつきに見えた。

オーナーと相談し、古い文字を消してから新しい文字を現す案を選んだ。

## 範囲

書いてよい:

- `Sources/Capsaicin/HUD/HUDView.swift`
- `docs/specs/hud.md`（`SPEC-HUD-006`）
- `docs/meta/decisions/DEC-UI-007-hud-glass-and-replacement-motion.md`（選択肢の補足）

## 完了条件

- 表示中の置き換えで、古い文字が 0.15 秒で消え、続く 0.15 秒で新しい文字が現れる。ぼかしの半径は最大 8 pt である。
- 消えている状態から出すときは、文字は遅れずに HUD と一緒に現れる。
- 幅とアイコンの動き（0.20 秒）は変えない。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 画面外で描いた途中のコマで、文字の濃さの移り変わりを確かめる（一時的なテストで行い、リポジトリには残さない）。
- 見た目は、オーナーが実機で確かめる。

## レビュー

PM が実装した。

- 文字のトランジションを `AsymmetricTransition` にした。消えるときは `easeInOut(0.15)`、現れるときは `easeInOut(0.15).delay(0.15)` である。
- トランジションに付けた時間は、`withAnimation(nil)` でも効いた。このため、消えている状態から出すときに、文字が約 0.2 秒遅れて現れた。そこで `HUDPresentation.replace` を `withTransaction` にし、消えている間は `disablesAnimations` で止める形にした。
- 途中のコマで確かめた結果（2x の画素で、文字の最も濃い画素の明るさ。39 が不透明、255 が背景）は次のとおりである。
  - 表示中の置き換え: 0 ms で 39、50 ms で 52、100 ms で 147、140〜200 ms で 226〜254（空白）、250 ms で 144、400 ms で 39。古い文字が消えてから、新しい文字が現れている。
  - 消えている状態から出すとき: 文字は HUD のフェードインと一緒に現れ、200 ms で 39 になった。
- ぼかしは `cacheDisplay` に写らない。見た目はオーナーが確かめる。

`just check` と `just build` が通った。
