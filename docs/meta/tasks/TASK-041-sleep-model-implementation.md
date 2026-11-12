---
schema: task
id: TASK-041
title: 新しい防止するスリープの形をコードと設定画面に実装する
status: in_review
requirements: ["REQ-BLK-001", "REQ-BLK-002", "REQ-BLK-003", "REQ-BLK-004", "REQ-BLK-005", "REQ-SET-005", "REQ-SET-006"]
depends_on: []
assignee: Codex（OpenCode の openai/gpt-6-sol）
---

# TASK-041 新しい防止するスリープの形をコードと設定画面に実装する

## 目的

`DEC-BLK-006` のとおり、抑止は自動スリープを常に止め、「画面の自動消灯とスクリーンセーバー」と「手動スリープとディスプレイを閉じたときのスリープ」を追加で止める形にする。変種 A・B、含意による無効、蓋閉じスリープだけを止める制御（`lidSleepControl`）を取り除く。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/`（Core、CoreTesting、Platform）と `Packages/CapsaicinKit/Tests/`
- `Sources/Capsaicin/`（`Settings/`、`App/AppModel.swift`、`App/AppComposition.swift`、`CLI/CLI.xcstrings`、`Settings/SettingsSleep.xcstrings`）と `Sources/capsaicin-cli/`
- `Tests/CapsaicinTests/`

触らない:

- `docs/`。別のエージェントが `TASK-040` で同時に要件・仕様を直している。仕様の正は `docs/meta/decisions/DEC-BLK-006-always-block-idle-sleep.md` とこのチケットである。
- 作業ツリーにある別の作業の変更（`project.yml`、`TASK-033`、`TASK-036`、ヘルパー関連のステージ済みの変更: `HelperScripts.swift`、`HelperScriptsTests.swift`）。
- ヘルパー（`Sources/capsaicin-helper/`）。

## 作るもの

1. `Settings`
   - `blocksIdleSleep`、`blocksLidSleep`、`turnsOffDisplayOnLidClose` を削除する。
   - `blocksDisplaySleep` の既定値を `true` にする。保存のキーは変えない。
   - `blocksManualSleep` は「手動スリープと蓋閉じスリープ」を表す。保存のキーは変えない。コメントを直す。
   - 閉じたときの画面を `lidCloseDisplay: LidCloseDisplay`（`keepOn`、`turnOff` の2つ。既定値 `turnOff`）として足す。保存のキーは新しく `lidCloseDisplay` にする。古いキーから変換する処理は作らない（`DEC-BLK-006`）。この作業では「明るさを 0 にする」は足さない（追加の判断は `DEC-BLK-007`）。
2. `EffectiveSettings` と仕組み
   - 自動スリープのアサーション（`idleSleepAssertion`）は常に適用する。
   - `displaySleepAssertion` は `blocksDisplaySleep` のとき、`systemSleepDisabled` は `blocksManualSleep` のとき適用する。
   - 蓋を閉じたら画面を消すのは、蓋のある Mac で、`blocksManualSleep` がオンで、`lidCloseDisplay == .turnOff` のときだけにする（`AppModel.shouldSleepDisplayOnLidClose` が使う）。
   - `Mechanism.lidSleepControl`、`LidSleepControlling`、`LidSleepControl`（Platform）、`FakeSystem` の対応、`BlockingController.Ports.lidSleep`、CLI の `mechanism.lidSleepControl` の文言と対応を取り除く。この仕組みは本番では一度も適用されていない（`PowerSnapshot` の `canBlockLidSleepAlone` が常に `false`）ので、古い記録との互換の処理は足さない。
   - `MachineCapabilities.canBlockLidSleepAlone` と `usesLidSleepControl` を取り除く。
3. `SleepSettingsPresentation`（設定画面の行の表示）
   - 行は3つ: 画面の自動消灯とスクリーンセーバー、手動スリープ（蓋のある Mac では「手動スリープとディスプレイを閉じたときのスリープ」）、閉じたときの画面（蓋のある Mac だけ）。
   - 画面の行: 常に操作できる。
   - 手動の行: 保存値がオンでヘルパーが正しく設置されていなければ注意の表示（今の `onWithoutHelper`）、それ以外は操作できる。
   - 閉じたときの画面: 蓋のない Mac では表示しない。手動の行の保存値がオンでヘルパーが正しく設置されているときだけ操作でき、それ以外は前提による無効（値は保存値を表示する）。
   - `ImplicationCause` と含意による無効（`.implied`）を取り除く。
4. 設定画面（`Sources/Capsaicin/Settings/`）
   - 自動スリープの行と、ディスプレイを閉じたときのスリープだけの行を削除する。
   - 閉じたときの画面は、親の行の下に字下げした子の行として、ポップアップ（`Picker` の `.menu` スタイルなど、既存の設定画面にあるポップアップの作りに合わせる）で「つけたまま」「消灯」を選ぶ。前提による無効のときは、既存の前提による無効と同じ見た目（無効、項目名を薄く）にする。
   - `SettingsSleep.xcstrings` の文言を次のとおりにする。不要になったキー（`idle.*`、`lid.*`、`implied.*`、`lidDisplayOff.*`）は削除する。String Catalog は Xcode が書く形（`"key" : value`、末尾の改行なし）を保つ。`stale` のキーを残さない。

| キー（例） | 文言 |
| --- | --- |
| `display.label` | 画面の自動消灯とスクリーンセーバー |
| `display.help` | 一定時間操作がないときの画面の消灯とスクリーンセーバーを防ぎます。オフにすると、システム設定どおりに画面が消えます。 |
| `manualAndLid.label` | 手動スリープとディスプレイを閉じたときのスリープ（今の文言のまま） |
| `manualAndLid.help` | アップルメニューなどの手動スリープと、ディスプレイを閉じたときのスリープを防ぎます。macOSの仕様上、2つは個別に防止できません。利用には管理者のパスワードによるヘルパーのインストールが必要です。 |
| `manual.label` | 手動スリープ（蓋のない Mac。今の文言のまま） |
| `manual.help` | アップルメニューなどの手動スリープを防ぎます。利用には管理者のパスワードによるヘルパーのインストールが必要です。 |
| `lidDisplay.label` | 閉じたときの画面 |
| `lidDisplay.help` | 手動スリープとディスプレイを閉じたときのスリープを防止しているときだけ使えます。「消灯」にすると、Macを動かしたまま画面を消して消費電力を抑えます。 |
| `lidDisplay.keepOn` | つけたまま |
| `lidDisplay.turnOff` | 消灯 |

5. テスト
   - 既存のテストを新しい形に直す。含意と変種のテストは、新しい振る舞いのテストに置き換える（消すだけにしない）。
   - 少なくとも次を確かめる: すべての設定で `idleSleepAssertion` が含まれる。画面・手動の設定と仕組みの対応。閉じたときの画面が画面を消す条件（蓋なし、手動オフ、`keepOn` では消さない）。行の表示（蓋の有無、ヘルパーの有無、前提による無効）。保存の形（`lidCloseDisplay` の読み書き、欠けたときの既定値、古いキーを無視する）。
   - テスト名の仕様 ID は、今のテストが使っている ID（`SPEC-BLK-001`、`SPEC-BLK-002`、`SPEC-BLK-012`、`SPEC-SET-002`、`SPEC-SET-005`、`SPEC-SET-006`）をそのまま使う。新しい ID は作らない。

## 守ること

- `AGENTS.md` の「破ってはいけないもの」を守る。`sudo`、`pmset` の設定変更、`launchctl` は実行しない。本番コードに `REQ-*` と `SPEC-*` を書かない。
- 作り込みすぎない。起こりにくい競合への防御、将来のための抽象、使われない引数を足さない。削除で済むところは削除する。既存の構造と命名に合わせる。
- `~/.claude/skills/write-swift/SKILL.md` があれば読んでから書く。
- `git commit` をしない。
- 判断に迷ったら推測で埋めず、報告に書く。

## 完了条件

- `nix develop --command just check` と `nix develop --command just build` が通る。
- `git grep -n "lidSleepControl\|LidSleepControl\|canBlockLidSleepAlone\|blocksIdleSleep\|blocksLidSleep\|ImplicationCause\|turnsOffDisplayOnLidClose" -- Sources Packages Tests` が何も返さない。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 設定画面の見た目と、実際に止まるかは、オーナーが実機で確かめる（PM が手順を渡す）。

## レビュー

Codex の成果物を PM が読み、次を直して受け入れた。

- `SettingsTests` が古い保存キーを `"blocks" + "IdleSleep"` のように分割して書き、完了条件の `git grep` を避けていた。古いキーを読み飛ばすことを確かめるテストは古い名前を書く必要があるので、文字列のまま書き、エンコード結果に古いキーがないことの確認（`CodingKeys` から自明）を除いた。
- 消灯の条件と節の名前を指すコメント（`EffectiveSettings`、`Settings`、`SleepSettingsPresentation`）を新しい形に直した。
- `CLI.xcstrings` は、ほかの String Catalog と違って Xcode が書く形になっていなかったので、キーの削除と合わせて Xcode の形に揃えた（差分が大きいのはこのため）。

`nix develop --command just check` と `nix develop --command just build` が通ることを確かめた。設定画面の見た目、画面の自動消灯とスクリーンセーバーの抑止（`HYP-BLK-009`）、閉じたときの画面の2つの選択肢は、オーナーが実機で確かめる。
