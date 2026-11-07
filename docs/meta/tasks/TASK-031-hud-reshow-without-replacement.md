---
schema: task
id: TASK-031
title: HUD が消えた後の表示を、前の内容からの置き換えにしない
status: done
requirements: ["REQ-HUD-001"]
depends_on: ["TASK-030"]
assignee: Claude（PM）
---

# TASK-031 HUD が消えた後の表示を、前の内容からの置き換えにしない

## 目的

オーナーが実機で、HUD が完全に消えた後にオンからオフへ切り替えると、オンの内容から始まってオフへ変わる動きになると指摘した。置き換えの動きは、前の表示が残っている間に切り替えたときだけにする。

原因は `HUDPresentation.replace` にあった。消えている間も 0.30 秒のバネを持つトランザクションで内容を変えていた。`disablesAnimations` が止めるのはビューに付けた暗黙のアニメーションだけなので、文字の補間と幅は前の内容から動いていた。

## 範囲

書いてよい:

- `Sources/Capsaicin/HUD/HUDView.swift`
- `docs/specs/hud.md`（`SPEC-HUD-006`）

## 完了条件

- 消えている間の置き換えでは、幅、アイコン、文字が前の内容から動かない。
- 表示中の置き換えの動き（`TASK-030`）は変えない。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 画面外で描いた途中のコマで、オンを出して消えた後にオフを出す流れを確かめる（一時的なテストで行い、リポジトリには残さない）。

## レビュー

PM が実装した。途中のコマ（出し直してから 40・100・160・400 ms）で確かめた結果は次のとおりである。

- 直す前: 40 ms で、オンの字と幅が残り、オフへ変わっていった。
- トランザクションのアニメーションを外しただけ: 文字と幅は直ったが、アイコンが 160 ms まで前のアイコンのままだった。
- アニメーションを外し、`disablesAnimations` も付けた: 40 ms からアイコン、文字、幅がすべてオフの内容になった。
