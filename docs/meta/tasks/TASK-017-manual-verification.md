---
schema: task
id: TASK-017
title: 実機での確認の手順書を作る
status: in_progress
requirements: []
depends_on: [TASK-015]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-017 実機での確認の手順書を作る

## 目的

エージェントが実行できない確認を、オーナーが実機で行うための手順書を作る。エージェントが実行できない確認は、次の2種類である。

- システムの設定を変える確認。ヘルパーの設置、LaunchAgent の登録、`pmset` の設定の変更、再起動などを伴う。
- 目と手で確かめる確認。LED の点灯、画面、動き、VoiceOver など。

結果は、各 `HYP-*` の「結果」と、新しい `EVID-*` の材料にする。

## 範囲

書いてよい: `docs/manual/verification.md`（新設）。

触らない: ほかのすべてのファイル。手順書の中で `HYP-*` や `SPEC-*` を参照するのはよい。

## 作るもの

手順書は、次の順にまとめる。各手順には、目的（どの `HYP-*`・`SPEC-*` を確かめるか）、前提、操作、期待する結果、途中で止める条件、元に戻す方法を書く。

1. 準備。
   - Debug のビルドの作り方と、アプリの置き場所。
   - 開始前の状態の記録。`pmset -g` の `SleepDisabled`、`pmset -g assertions`、`launchctl print gui/$(id -u)/io.github.koutyuke.capsaicin.debug` を記録する。
   - Release と Debug を同時に動かさないこと。
2. 起動と LaunchAgent。`HYP-LCY-002`、`HYP-LCY-003`、`SPEC-LCY-001`、`SPEC-LCY-003`、`SPEC-LCY-005`。
   - Finder からの起動で、LaunchAgent への引き渡しが起きること。
   - クラッシュ（`kill -SEGV`）後の再起動。
   - 「ログイン時に起動する」の切り替え。
   - バックグラウンド項目を無効にしたときの表示。
3. 抑止の基本。`SPEC-BLK-001`、`SPEC-BLK-002`、`HYP-BLK-001`、`HYP-BLK-002`、`HYP-BLK-008`、`HYP-SET-001`、`HYP-SET-002`。
   - 種類ごとの抑止と、アサーションの確認。
   - 蓋閉じスリープの抑止。
   - 蓋を閉じたら画面を消す動き。
   - 蓋と内蔵バッテリーの検出。
4. ヘルパー。`SPEC-HLP-001`〜`SPEC-HLP-005`、`HYP-BLK-006`、`HYP-BLK-007`。
   - 設置。管理者認証の取り消しも試す。
   - `on`・`off`。
   - 修復。
   - 起動時の後片付け（再起動を伴う）。
   - 削除。外部の `disablesleep` を残す場合も試す。
5. LED。`HYP-LED-001`〜`HYP-LED-004`、`HYP-LCY-001`、`SPEC-LED-001`〜`SPEC-LED-006`。
   - 内蔵と外付けのキーボード、接続と切断、スリープからの復帰。
   - Karabiner-Elements があるときの案内。
   - Caps Lock の入力状態が変わらないこと。
6. 終了と再開。`HYP-LCY-004`、`HYP-LCY-005`、`SPEC-LCY-002`、`SPEC-LCY-004`、`SPEC-LCY-006`、`SPEC-LCY-007`。
   - 利用者の終了。
   - ログアウト・再起動の後の再開。
   - 連続クラッシュ。
7. CLI。`SPEC-CLI-001`〜`SPEC-CLI-007`。
   - アプリを終了した状態からの `capsaicin on`。
   - 受け付けない設定のときの終了コード。
8. 画面。`SPEC-MENU-*`、`SPEC-SET-*`、`SPEC-HUD-*`、`SPEC-UI-*`。
   - メニュー、入力パネル、設定ウインドウ、HUD の見た目と動き（ライトとダーク）。
   - 視差効果を減らす、透明度を下げる、コントラストを上げる。
   - VoiceOver。
   - 複数のディスプレイ。
   - ホットキー。
9. 後片付け。開始前の状態に戻す手順。
   - ヘルパーの削除。
   - LaunchAgent の `bootout` と plist の削除（`trash` を使う）。
   - 設定（`defaults delete`）と再開用の記録の削除。
   - `SleepDisabled` を戻す。

各節の終わりに、結果を書き込む欄（成功・失敗・判定不能と、気づいたこと）を置く。

## 守ること

- 手順書を書くだけで、手順は実行しない。`sudo`、`launchctl`、`pmset` の設定の変更、ヘルパーの設置、アプリの起動をしない（`AGENTS.md`）。
- コマンドは実際のラベル・パス・bundle ID に合わせる。ソースの `LaunchAgent.swift`、`HelperSleepController.swift`、`IPCEndpoint.swift`、`project.yml` で確かめる。
- 文体は `docs/documentation-management.md` の常体に従う。`git` の状態を変える操作をしない。

## 完了条件

- 上の 1〜9 がある。各手順のコマンドが、ソースの実際の値と一致している。
- `nix develop --command just lint-docs` が通る。

## レビュー

未実施。
