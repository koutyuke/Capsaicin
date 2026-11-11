---
schema: task
id: TASK-050
title: LED の書き込みの結果を、サービスの登録 ID ごとにログへ出す
status: done
requirements: ["REQ-LED-004"]
depends_on: []
assignee: Codex（Codex のハーネス、gpt-6.1-sol、推論 high）
---

# TASK-050 LED の書き込みの結果を、サービスの登録 ID ごとにログへ出す

## 目的

`HYP-LED-005` と `EVID-LED-005` を確かめるための材料を、アプリのログに残す。いまは、LED の書き込みが1台でも失敗すると `CapsLockLEDError.writeFailed(failedTargets:)` が返るだけで、どのサービスが一覧に入っていて、どれへの書き込みが失敗したかが分からない。WindowServer のログには成功した書き込みしか残らないので、「一覧に入っていなかった」と「書き込みが失敗した」を区別できない。

この作業ではログを足すだけにする。書き込む対象の選び方、失敗の数え方、クライアントの持ち方は変えない。それらは `HYP-LED-005`〜`HYP-LED-007` の結果を見てから決める。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/CapsLockLEDController.swift`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/LED/LEDTestFixture.swift`（`LEDService` の変更に合わせるためだけ）

触らない: 上記以外のすべて。`CapsaicinLEDShim`、`HIDKeyboardMonitor.swift`、アプリ側（`Sources/`）、文書。

## 作るもの

- `LEDService` に、サービスの登録 ID を持たせる。実機では公開ヘッダーの `IOHIDServiceClientGetRegistryID` から取る（戻り値は `CFNumber`）。取れなければ `nil` にする。
- `apply(mode:)` の最後に、1回の呼び出しにつき1行のログを出す。
  - 内容: 書いたモード、キーボードとして書き込んだサービスの登録 ID の一覧、書き込みに失敗したサービスの登録 ID の一覧。
  - 失敗がなければ `notice`、1台でも失敗したら `error` にする。`info` と `debug` はディスクに残らないので使わない。
  - モードと登録 ID は `privacy: .public` にする。製品名など、それ以外の値は出さない。
  - `Logger(subsystem: "io.github.koutyuke.capsaicin", category: "LED")` を使う。既存のファイルと同じく、その場で作るか `private let` で持つ。

## 守ること

- `HIDCapsLockLED` に書く値、書く対象、書く順番、失敗の判定、`throw` するエラーを変えない。既存のテストの期待値を変えない。
- 非公開の関数を増やさない。
- ログのためだけの型、プロトコル、設定を増やさない。変更は合わせて数十行に収まるはず。
- 本番コードに `REQ-*`・`SPEC-*`・`HYP-*` を書かない。
- `git commit` をしない。LED への書き込みを伴うアプリの起動や、`scripts/manual/` の実行をしない。

## 完了条件

- 上の「作るもの」を満たす。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- PM が差分を読み、書き込みの振る舞いが変わっていないことと、ログの内容とレベルを確かめる。
- PM が `just check` と `just build` を流す。
- 実機でのログの確認は、オーナーが `docs/manual/led-remapper-verification.md`（コミット `14fd1f7`） の B2 で行う。

## レビュー

- Codex が実装し、`just check` と `just build` を通した。書き込みの対象、順番、失敗の判定、`throw` するエラーは変わっていない。
- PM が直したこと: ログを `defer` で出していたため、クライアントの作成や一覧の取得に失敗したときにも `targets=[]` を通常のレベルで出し、キーボードがなかった成功と読めた。ログは一覧を回した後に出すようにし、作成と取得の失敗はこれまでどおり `throw` だけにした。失敗の数は `failedTargets.count` から取り、重複していたカウンターを消した。
- PM が `just check` と `just build` を流し直し、どちらも通った。
- 実機でのログの出方は未確認。`docs/manual/led-remapper-verification.md`（コミット `14fd1f7`） の `applog` で、B2 のときに確かめる。
