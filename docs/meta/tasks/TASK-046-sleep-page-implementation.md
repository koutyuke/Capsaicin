---
schema: task
id: TASK-046
title: スリープのページで閉じたときの動作を1つのポップアップにまとめ、(i) と文言を整理する
status: in_review
requirements: ["REQ-SET-002", "REQ-SET-003", "REQ-SET-005", "REQ-SET-006"]
depends_on: []
assignee: Codex（OpenCode の openai/gpt-6.1-sol）
---

# TASK-046 スリープのページで閉じたときの動作を1つのポップアップにまとめ、(i) と文言を整理する

## 目的

`DEC-SET-005` と `DEC-UI-011` のとおりに、設定画面の「スリープ」を直す。保存値の形（`blocksManualSleep`、`lidCloseDisplay`）、止める仕組み、抑止の判定は変えない。

## 範囲

書いてよい:

- `Sources/Capsaicin/Settings/`（Swift と、`SettingsSleep.xcstrings`、`SettingsHelper.xcstrings`）
- `Packages/CapsaicinKit/Sources/CapsaicinCore/Blocking/SleepSettingsPresentation.swift` と `Packages/CapsaicinKit/Tests/CapsaicinCoreTests/SleepSettingsPresentationTests.swift`
- `Tests/CapsaicinTests/`

触らない:

- `docs/`。別のエージェントが `TASK-045` で同時に仕様を直している。仕様の正は、2つの判断とこのチケットである。
- そのほかの `Packages/`、`Sources/capsaicin-helper/`、`Sources/capsaicin-cli/`、`Sources/Capsaicin/CLI/`、`project.yml`。
- 作業ツリーにある別の作業の変更。`git add`、`git restore`、`git stash`、`git commit` をしない。

## 作るもの

1. 蓋のある Mac では、「ディスプレイを閉じてもスリープさせない」のスイッチと子の「閉じたときのディスプレイ」の2行を、1行のポップアップ「ディスプレイを閉じたとき」（アイコン `laptopcomputer`、カード2）にする。選択肢は上から「スリープ（標準）」「ディスプレイをオフ」「オンのまま」。
   - 表示: `blocksManualSleep` がオフなら「スリープ」。オンなら `lidCloseDisplay` が `turnOff` のとき「ディスプレイをオフ」、`keepOn` のとき「オンのまま」。
   - 「スリープ」を選ぶと `blocksManualSleep` をオフにする（`lidCloseDisplay` は変えない）。
   - 「ディスプレイをオフ」「オンのまま」を選ぶと、ヘルパーが設置済みなら `blocksManualSleep` をオン、`lidCloseDisplay` を選んだ値にして1回の変更で保存する。設置されていなければ、今のスイッチと同じ確認と設置（一部だけ残っていれば修復）の流れを通し、成功したときだけ保存する。断った、または失敗したら「スリープ」のままにする。設置中はポップアップを操作できなくし、選んだ値を表示しておく（今の `pendingManual` に当たるもの）。
   - ヘルパーが要る設定が保存されているのにヘルパーが正しく設置されていないときは、今のスイッチと同じく、アイコンを注意の記号（`systemOrange`）に替え、保存した選択肢を表示し、(i) の先頭に `helperNotReady` を出す。ポップアップは操作でき、「スリープ」を選べば `blocksManualSleep` をオフにできる。
2. 蓋のない Mac は今のスイッチ「メニューから選んでもスリープさせない」（`manual.*`、アイコン `powersleep`）のままにする。
3. `SleepSettingsPresentation` から独立した `lidCloseDisplay` の行をなくす。前提による無効（`prerequisiteUnmet`）を使う箇所がなくなれば、その case と `dimsLabel` など関連する分岐も削る。`SleepSettingsPresentationTests` を新しい形に合わせる。
4. (i) を、次の行だけに置く: 「ディスプレイを自動でオフにしない」、「ディスプレイを閉じたとき」、「メニューから選んでもスリープさせない」、「指定時刻」。そのほかの行（継続時間、時刻、バッテリー残量、しきい値、電源アダプタの行）の (i) と、親がオフのときだけ出す (i) をなくす。
5. 文言を下の表のとおりにする。表にないキーは変えない。消すキーは String Catalog から削除する。新しいキーには、ほかのキーと同じく `"extractionState" : "manual"` を付ける。String Catalog は Xcode が書く形（`"key" : value`、末尾の改行なし）を保つ。
6. ヘルパーの確認ダイアログのタイトルの選び分け（`SettingsWindowController`）を新しいキーに合わせる。

### SettingsSleep.xcstrings

| キー | 文言 |
| --- | --- |
| `release.group.title` | 自動でオフにする |
| `display.help` | Capsaicinがオンの間は、操作しない時間が続いてもディスプレイをオフにせず、スクリーンセーバも始めません。macOSの仕組み上、この2つは個別に設定できません。この設定をオフにしても、Macは自動でスリープしません。 |
| `lidClose.label`（新規） | ディスプレイを閉じたとき |
| `lidClose.sleep`（新規） | スリープ（標準） |
| `lidClose.turnOff`（新規） | ディスプレイをオフ |
| `lidClose.keepOn`（新規） | オンのまま |
| `lidClose.help`（新規） | 「スリープ」以外を選ぶと、Capsaicinがオンの間は、ディスプレイを閉じても、アップルメニューの「スリープ」などを選んでも、Macはスリープしません。macOSの仕組み上、この2つは個別に設定できません。使うには、管理者パスワードでヘルパーをインストールする必要があります。 |
| `manual.help` | Capsaicinがオンの間は、アップルメニューの「スリープ」などを選んでもMacはスリープしません。使うには、管理者パスワードでヘルパーをインストールする必要があります。 |
| `helperNotReady` | ヘルパーが正しくインストールされていないため、この設定を適用できません。設定の「ヘルパー」で修復してください。 |
| `time.help` | この時刻になると自動でオフにします。オンにした時点でこの時刻を過ぎている場合は、翌日のこの時刻にオフにします。 |
| `battery.ignoreOnAdapter.label` | 電源アダプタ接続中は残量でオフにしない |

削除: `manualAndLid.label`、`manualAndLid.help`、`lidDisplay.label`、`lidDisplay.help`、`lidDisplay.turnOff`、`lidDisplay.keepOn`、`timer.duration.help`、`time.value.help`、`battery.help`、`battery.threshold.help`、`battery.ignoreOnAdapter.help`。

### SettingsHelper.xcstrings

| キー | 文言 |
| --- | --- |
| `helperInstall.lidClose.title`（`helperInstall.manualAndLid.title` を置き換える） | ディスプレイを閉じてもスリープさせないには、ヘルパーのインストールが必要です |
| `error.helperInstall.message` | ヘルパーをインストールできませんでした。設定から操作した場合は、設定を変更前の状態に戻しています。 |
| `error.settingRollback.message` | Capsaicinの動作に反映できなかったため、設定を変更前の状態に戻しました。 |
| `helperRemove.message` | 削除すると、Capsaicinがオンの間でも、ディスプレイを閉じたときやメニューから選んだときにMacがスリープするようになります。削除には管理者のパスワードが必要です。 |
| `status.help` | メニューから選んだときやディスプレイを閉じたときのスリープを止める小さなプログラム、パスワードなしでの実行を許可する設定、Mac起動時にスリープ設定を安全に戻す項目の3つをシステムにインストールします。 |

## 完了条件

- 上の「作るもの」がすべて実装されている。
- テストが次を確かめる（テスト名には `SPEC-SET-005` など対応する仕様 ID を付ける）: ポップアップの表示が保存値の3通りに対応すること。「スリープ」以外を選ぶとヘルパー設置済みなら2つの保存値が変わり、未設置なら設置の流れを通り、断る・失敗すると保存値が変わらないこと。ヘルパーが壊れているときに注意の表示と `helperNotReady` が出ること。蓋のない Mac ではスイッチの行になること。(i) を持つ行が上の4つだけであること。
- `nix develop --command just check` と `nix develop --command just build` が成功する。`docs/` の検査（`lint-docs`）だけが `TASK-045` の作業中の理由で落ちる場合は、その旨を報告する。
- `.build/settings/` に、テストで描画したスリープのページ（ライト、ダーク、下端までスクロールしたもの）の PNG が新しい形で出ている。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 報告には、変更したファイル、テストの結果、`.build/settings/` の PNG のパス、判断に迷ったことを書く。

## レビュー
