---
schema: task
id: TASK-053
title: LED の書き込み先を、書き込みのたびに調べ直す
status: in_review
requirements: ["REQ-LED-002", "REQ-LED-004"]
depends_on: ["TASK-050"]
assignee: Codex（Codex のハーネス、gpt-6.1-sol、推論 high）
---

# TASK-053 LED の書き込み先を、書き込みのたびに調べ直す

## 目的

Capsaicin は、最初の書き込みで作った LED のクライアントを持ち続けている。このクライアントの一覧は、作成後に増えたキーボードを含まず、なくなったキーボードを残す（`EVID-LED-008`）。その結果、抑止中に接続したキーボードが点かず、スリープからの復帰後は解除時に「一部を戻せません」が出る。

書き込みのたびに、その時点のキーボードを対象にする（`SPEC-LED-002`）。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/CapsLockLEDController.swift`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/LED/`

触らない: 上記以外のすべて。書き込みの対象の選び方（キーボードかどうかの判定）は `TASK-054` で変えるので、ここでは変えない。

## 作るもの

- 書き込みのたびにクライアントを作り直し、作ったクライアントは持ち続けない。まずこの形を試す。
- テストは、2回目以降の書き込みが新しい一覧を使うことを確かめる。`LEDControllerTests` の「接続・切断・復帰時に、その時点のサービスを再列挙する」は、同じクライアントが新しい一覧を返す前提なので、クライアントを作り直す前提に直す。

同じプロセスでクライアントを作り直せば新しいサービスが見えるかは、まだ確かめていない（`EVID-LED-008` の未確認のこと）。見えなければ、サービスの追加と削除の通知を受ける形を別のチケットで検討する。この作業では、通知の仕組みを先回りして足さない。

## 守ること

- `HIDCapsLockLED` に書く値、失敗の判定、`throw` するエラー、ログの内容を変えない。
- 非公開の関数を増やさない。
- 本番コードに `REQ-*`・`SPEC-*`・`HYP-*` を書かない。
- `git commit` をしない。LED への書き込みを伴うアプリの起動や、`scripts/manual/` の実行をしない。

## 完了条件

- 上の「作るもの」を満たす。
- `nix develop --command just check` と `nix develop --command just build` が通る。
- オーナーの実機の確認で、`SPEC-LED-002` の「抑止中に接続したキーボードも点灯する」と「スリープから復帰した後も解除で戻せる」が満たされる。

## 検証

- PM が差分を読み、`just check` と `just build` を流す。
- 実機はオーナーが `docs/manual/led-fix-verification.md` の手順2で確かめる。アプリのログの `targets` に新しい登録 ID が入り、`failedTargets` が空であることを見る。

## レビュー

- Codex が実装し、`just check` と `just build` を通した。クライアントを持ち続けるのをやめ、書き込みのたびに作り直す。書く値、失敗の判定、`throw` するエラー、ログの書式は変わっていない。
- PM が差分を読み、`just check` と `just build` を流し直して、どちらも通った。
- 同じプロセスで作り直したクライアントに新しいサービスが見えるかは、実機で未確認。オーナーが `docs/manual/led-fix-verification.md` の手順2で確かめるまで、`in_review` のままにする。
