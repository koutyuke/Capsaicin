---
schema: task
id: TASK-022
title: HUD の最小幅をなくし、アイコン側の余白を見た目で揃える
status: done
requirements: ["REQ-HUD-001"]
depends_on: ["TASK-021"]
assignee: Claude（PM）
---

# TASK-022 HUD の最小幅をなくし、アイコン側の余白を見た目で揃える

## 目的

オーナーが実機で、オンとオフで左右の余白の大きさが違うこと、アイコン側の余白が広く見えることを指摘した。PM がスクショを画素で測った結果は次のとおりである。

- 「スリープ防止 オフ」だけのとき、内容が最小幅 200 pt より狭く、行ごと中央に置かれていた。余白は左右とも約 31 pt で、条件を伴う表示（20 pt）より広かった。
- 「スリープ防止 オン · 1時間14分」のとき、見える形どうしの余白は左 22.5 pt、右 19.5 pt だった。SF Symbols が形の外側に持つ空白の分、左が広い。

日本語の文言でいちばん短い表示（状態だけ）は、約 180 pt である。最小幅を 160 pt にしても効かないため、最小幅はなくす。

## 範囲

書いてよい:

- `Sources/Capsaicin/HUD/HUDView.swift`
- `Tests/CapsaicinTests/HUD/HUDPresentationTests.swift`
- `docs/specs/hud.md`（`SPEC-HUD-004`）
- `docs/manual/verification.md`（HUD の幅の期待値の1行だけ）

## 完了条件

- 幅は内容に合わせ、最大 420 pt に収める。最小幅はない。
- 左の余白は 17 pt、右は 20 pt。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 見た目は、オーナーが実機で確かめる。

## レビュー

PM が実装した。幅のテストは、180 pt の内容が 180 pt になることを確かめる。変更前は 200 pt になるため失敗する。
