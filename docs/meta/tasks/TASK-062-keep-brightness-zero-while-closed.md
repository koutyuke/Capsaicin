---
schema: task
id: TASK-062
title: 「明るさを0」で閉じている間は1分ごとに輝度を 0 に戻し、開けたら閉じる前の輝度に戻す
status: in_review
requirements: ["REQ-BLK-014"]
depends_on: ["TASK-061"]
assignee: Codex（OpenCode、openai/gpt-6.1-sol、variant high）
---

# TASK-062 「明るさを0」で閉じている間は1分ごとに輝度を 0 に戻し、開けたら閉じる前の輝度に戻す

## 目的

`DEC-BLK-008` のとおり、`TASK-061` の実装を2点変える。閉じて暗くしている間に輝度が上がったら、1分ごとの処理で 0 に戻す。戻す場面では、いまの輝度によらず記録した閉じる前の輝度を書く。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinCore/Controller/`（主に `BlockingController+Brightness.swift` と `BlockingController.swift`）
- `Packages/CapsaicinKit/Tests/CapsaicinCoreTests/ControllerBrightnessTests.swift`、必要なら `Tests/CapsaicinTests/App/AppModelTests.swift`
- `docs/manual/verification.md`（4.7 の操作3と期待だけ）

触らないもの: 上記以外のすべて。特に `docs/specs/`、`docs/meta/`（このチケットを除く）、Platform、設定画面、文言。仕様と食い違う、または仕様が足りないと分かったら、変えずに報告する。`git add`、`git stash`、`git commit` をしない。

読むもの:

- `AGENTS.md`
- `DEC-BLK-008`（`DEC-BLK-007` を引き継ぐ）、`SPEC-BLK-013`（`docs/specs/blocking.md`）
- `Packages/CapsaicinKit/Sources/CapsaicinCore/Controller/BlockingController+Brightness.swift`、`BlockingController.swift`（`timePassed`）
- `Sources/Capsaicin/App/AppComposition.swift`（1分ごとのタイマーと、蓋の開閉の通知のつなぎ方）

## 作るもの

1. コントローラーが、いま蓋が閉じているかを覚える。`lidClosed()` で閉じた、`lidOpened()` で開いたにする。抑止中かどうかや設定によらず、通知を受けたら更新する。起動直後は「閉じていない」とする（閉じた通知を受けるまで暗くし直さない）。
2. `timePassed()` で、解除の条件が成り立って解除した場合を除き、次がすべて成り立つときだけ輝度を読み、0 より大きければ 0 を書く。抑止中、`shouldZeroBrightnessOnLidClose` が真、輝度の記録がある、1 で蓋が閉じている。記録は書き換えない。読めない・書けないときはログに残すだけにする。
3. `restoreBrightness()` から、いまの輝度を読んで 0 と比べる処理をなくす。記録した値を書き、書けたら記録を消し、書けなければ（内蔵ディスプレイがないときを含む）ログに残して記録を残す。ポートの `readBrightness` は、暗くするときと 2 で使うので残す。
4. 新しいタイマーを作らない。アプリの1分ごとのタイマーがすでに `timePassed()` を呼んでいる。

### テスト

5. `ControllerBrightnessTests.swift` を `DEC-BLK-008` に合わせて直し、足す。テスト名で `SPEC-BLK-013` と対応させる。
   - 閉じて暗くした後に輝度が上がると、`timePassed()` で 0 に戻る。記録は閉じる前の値のまま。
   - 開いた通知の後、抑止していないとき、「明るさを0」でないとき、記録がないとき、閉じた通知を受けていないとき（起動時にすでに閉じていた）は、`timePassed()` で書かない。
   - 戻す場面では、いまの輝度が 0 でなくても記録した値を書いて記録を消す（いまの `openRestoresOnlyZero` を置き換える）。書けなければ記録を残す。
   - 解除の条件で解除した `timePassed()` では、0 を書かずに戻す。

### 手順書

6. `docs/manual/verification.md` の 4.7 の操作3と期待を `SPEC-BLK-013` の受け入れ例に合わせる。閉じている間に外付けキーボードで明るくし、隙間の光が1分以内に消えることを見る。1分以上待ってから開け、閉じる前の明るさに戻ることを見る。

## 守ること

- `AGENTS.md` の「破ってはいけないもの」を守る。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。
- 起こりにくい競合への防御を重ねない。
- アプリを起動しない。`scripts/manual/` を実行しない。輝度を変えるコードを手元で動かさない。
- サブエージェントを起動しない。迷ったら推測で埋めずに報告する。

## 完了条件

- `nix develop --command just check` と `nix develop --command just build` が通る。
- 5 のテストがあり、通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- PM が差分を読む。オーナーが 4.7 の操作3で実機を確かめる。

## レビュー

PM が差分を読んだ。変更は `DEC-BLK-008` のとおりで、コントローラーが蓋の状態を覚え、解除しなかった `timePassed()` で、抑止中・「明るさを0」・記録あり・蓋が閉じているときだけ 0 に戻す。戻す処理は、いまの輝度を読まずに記録した値を書く。新しいタイマーはない。テストは、暗くし直す条件、開いた後や起動直後に暗くし直さないこと、失敗後の再試行、解除を優先することを確かめている。

PM が直したこと: 手順書 4.7 の目的に、置き換え前の「利用者が変えた輝度は上書きしない」が残っていたので、`DEC-BLK-008` に合わせた（担当が範囲外として報告した）。

PM が worktree で `nix develop --command just check`（SwiftPM 304件、アプリ88件）と `nix develop --command just build` を実行し、通ることを確かめた。

未確認: 実機で、閉じたまま明るくした輝度が1分以内に 0 に戻ること。オーナーが 4.7 の操作3で確かめる。
