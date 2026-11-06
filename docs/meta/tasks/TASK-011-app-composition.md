---
schema: task
id: TASK-011
title: アプリの組み立てと起動・終了の流れを作る
status: done
requirements: []
depends_on: [TASK-003, TASK-004, TASK-005, TASK-006, TASK-007, TASK-008]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-011 アプリの組み立てと起動・終了の流れを作る

## 目的

Core の `BlockingController` に Platform の実装をつなぎ、アプリとして動く状態にする。画面（メニュー、設定、HUD、ホットキー）はこの後のチケットで作る。そのため、ここでは画面から使う小さなモデルと、起動・終了・定期処理・CLI の受け付けまでを作る。

## 範囲

書いてよい:

- `Sources/Capsaicin/App/`（新設）
- `Sources/Capsaicin/MenuBar/CapsaicinApp.swift`（入口だけ。メニューの中身は作らない）
- `Tests/CapsaicinTests/App/`
- `project.yml`（アプリのテストから `CapsaicinCoreTesting` と `CapsaicinPlatform` を使うための依存の追加だけ）

触らない: `Packages/`、CLI、ヘルパー、`docs/`。Core や Platform の変更が必要なら、変更せずに報告する。

## 作るもの

仕様は `docs/specs/lifecycle.md`、`blocking.md`、`cli.md`（`SPEC-CLI-004`、`SPEC-CLI-005`）、`led.md`（`SPEC-LED-002`、`SPEC-LED-005`）、`helper.md`（`SPEC-HLP-006` の終了時のダイアログ）に従う。方式は `DEC-LCY-001`、`DEC-LCY-002`、`DEC-LCY-004`、`DEC-CLI-002`、`DEC-SET-002` にある。

1. **組み立て。** 設定の保存（`UserDefaultsSettingsStore`）、機器の能力、ポートの各実装、`BlockingController` を1か所で作る。
2. **画面から使うモデル。** `@Observable` で `@MainActor` の `AppModel` を作り、次を持たせる。
   - コントローラーの状態（`BlockingStatus`）。
   - 開始・解除・ホットキーの切り替え・設定の変更の入口。
   - HUD とアラートを出すための出来事の通知。HUD を出すかは `SPEC-HUD-001` に従って画面の側で決めるので、ここでは `BlockingEvent` をそのまま流す。
   - Karabiner-Elements の状態。
   - クラッシュ時に再起動されるか（`SPEC-LCY-005`）。
3. **起動の流れ（`DEC-LCY-002`）。**
   - launchd から起動されていなければ、LaunchAgent に起動を求めて自分は終わる。
   - 起動を求めるのに失敗したら、そのまま動き、再起動されないことをモデルに示す。
   - launchd から起動されたら、`launch()`、LaunchAgent の `RunAtLoad` の更新、CLI の受け付けの開始の順に行う。
4. **定期処理と通知。**
   - 1 分ごとに `timePassed()` を呼ぶ。
   - 電源の変化で `powerStateChanged()` を呼ぶ。
   - スリープからの復帰で LED を設定し直す。
   - 蓋が閉じたら、抑止中で `effectiveSettings.turnsOffDisplayOnLidClose` が真のときだけ画面を消す。
5. **CLI の受け付け。**
   - `IPCServer` の処理を、コントローラーの開始・解除・状態に対応させる。
   - 「CLI からの操作を受け付ける」がオフなら拒む（`SPEC-CLI-005`）。
   - Debug と Release でソケットを分ける。
6. **終了。**
   - 終了のときは `TerminationReasonDetector` で、利用者の終了、セッションの終了、判定不能を区別し、それぞれのコントローラーの処理を呼ぶ。
   - 利用者の終了で合わせられていない制御が残ったら、エラーのダイアログを出してから終わる（`SPEC-LCY-002`、`SPEC-HLP-006`）。ダイアログの文言は仮でよい。

## 守ること

- `AGENTS.md` の「破ってはいけないもの」を守る。テストでアプリを起動しない。`launchctl` を実行しない。実際のアサーション、LED、ヘルパーに触らない。
- モデルのテストは、`CapsaicinCoreTesting` の偽物で行う。
- 短く素直に書く。起こりにくい競合への防御を重ねない（`TASK-010` を参照）。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。`git commit` をしない。

## 完了条件

- 上の 1〜6 がある。
- モデルの開始・解除・設定の変更・CLI の拒否・終了の種類の振り分けにテストがある。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`

## レビュー

PM が差分を読んでレビューした。実際のポートを作るのは `AppComposition` の1か所だけで、モデルは偽物で組み立ててテストしている。正確な解除のためのタイマーと 1 分ごとの処理、終了時の確認ダイアログ（モーダル）を確認した。アプリのテストのターゲットに HUD のソースが入っていなかったので、PM が `project.yml` に足して `just check` と `just build` を通した。HUD の組み込みでは、解除の直前の状態を渡す（指定時刻の表示のため）。実機での確認は、承認を得て行う。
