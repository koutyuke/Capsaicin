---
schema: task
id: TASK-061
title: 蓋を閉じたときの「明るさを0」を実装する
status: in_review
requirements: ["REQ-BLK-014", "REQ-SET-005", "REQ-LCY-002", "REQ-LCY-003"]
depends_on: ["TASK-059"]
assignee: Codex（OpenCode、openai/gpt-6.1-sol、variant high）
---

# TASK-061 蓋を閉じたときの「明るさを0」を実装する

## 目的

`DEC-BLK-007` と `SPEC-BLK-013` のとおり、「ディスプレイを閉じたとき」に「明るさを0」を加える。抑止中に蓋が閉じたら内蔵ディスプレイの輝度を記録してから 0 にし、蓋が開いたとき・解除・終了・起動時に戻す。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinCore/`（設定、有効な設定、ポート、再開用の記録、コントローラー）
- `Packages/CapsaicinKit/Sources/CapsaicinCoreTesting/FakeSystem.swift`
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Power/`（輝度の実装を新しいファイルで足す。`LidStateMonitor.swift`）
- `Sources/Capsaicin/App/`、`Sources/Capsaicin/Settings/`（`SettingsSleep.xcstrings` を含む）
- `Packages/CapsaicinKit/Tests/`、`Tests/CapsaicinTests/`
- `docs/manual/verification.md`（オーナーが実機で確かめる節を1つ足す）

触らないもの: 上記以外のすべて。特に `docs/specs/`、`docs/meta/`（このチケットを除く）、ヘルパー（`Sources/capsaicin-helper/`）、`project.yml`。仕様と食い違う、または仕様が足りないと分かったら、変えずに報告する。`git add`、`git stash`、`git commit` をしない。

読むもの:

- `AGENTS.md`
- `DEC-BLK-007`、`SPEC-BLK-013`、`SPEC-BLK-007`、`SPEC-BLK-012`、`SPEC-SET-002`、`SPEC-SET-005`、`SPEC-LCY-002`、`SPEC-LCY-006`、`SPEC-HLP-005`
- `EVID-BLK-007`、`EVID-BLK-010`、`EVID-BLK-012`（DisplayServices の関数と、実機で分かったこと）
- `Packages/CapsaicinKit/Sources/CapsaicinCore/Controller/`、`Lifecycle/ResumeRecord.swift`、`Blocking/EffectiveSettings.swift`、`Settings/LidCloseDisplay.swift`
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Power/LidStateMonitor.swift`、`DisplaySleepCommand.swift`
- `Sources/Capsaicin/App/AppComposition.swift`、`Sources/Capsaicin/Settings/SettingsContent.swift`、`SettingsModel.swift`、`SettingsPreview.swift`

## 作るもの

### Core

1. `LidCloseDisplay` に `zeroBrightness` を加える。保存の文字列も `zeroBrightness` にする。
2. `EffectiveSettings` に、蓋を閉じたら暗くするかを加える。蓋があり、手動スリープの保存値がオンで、`lidCloseDisplay` が `zeroBrightness` のときだけ真にする（`shouldSleepDisplayOnLidClose` と同じ形）。
3. 内蔵ディスプレイの輝度のポートを `Ports.swift` に加える。操作は次の3つで足りる。
   - 輝度を読む。オンラインの内蔵ディスプレイがなければ nil、読めなければ throw。
   - 輝度を書く。書けなければ throw。
   - 輝度を変えられないと分かっているか（関数が見つからない、または内蔵ディスプレイについて変えられないと返した）。内蔵ディスプレイがなく判定できないときは偽にする。
4. 暗くする前の輝度を `ResumeRecord` に持たせる（任意の値。欠けた記録は nil として読む）。既存の原子的な保存と、起動時の読み込みをそのまま使う。
5. `BlockingController` に、蓋が閉じたときと開いたときの入口を加え、`SPEC-BLK-013` の手順を実装する。
   - 閉じたとき: 抑止中で、2 が真のときだけ暗くする。記録がなければ、読む → 記録に入れて保存 → 0 を書く。保存できなければ 0 を書かない。記録があれば、記録を変えずに 0 を書く。
   - 戻す手順は1つの関数にまとめ、開いたとき、`restoreStopped`（解除と利用者の終了と理由不明の終了が通る）、`endSession`、`launch` の最初（記録を読んだ直後、再開の判断より前）から呼ぶ。どれも記録があるときだけ動き、設定の値によらない。解除と終了では、`disablesleep` を下ろすより前に呼ぶ。
   - 戻すとき: いまの輝度を読み、0 なら記録の値を書いて記録を消す。0 でなければ書かずに記録を消す。読めない（nil を含む）・書けないときは記録を残す。
   - 輝度は抑止の仕組み（`Mechanism`）にしない。開始の全部か無しか、合わせられていない制御、警告に含めない。失敗はログに残すだけにする（既存のログの方法に合わせる）。

### Platform

6. DisplayServices の実装を `Power/` に新しいファイルで足す。`/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices` を `dlopen` し、`DisplayServicesGetBrightness`、`DisplayServicesSetBrightness`、`DisplayServicesCanChangeBrightness` を `dlsym` で引く。対象は `CGGetOnlineDisplayList` と `CGDisplayIsBuiltin` で見つけた内蔵ディスプレイだけにする。状態が 0 以外なら throw する。読み込みは1回だけにする。
7. `LidStateMonitor` が、閉じた通知に加えて、閉じていると分かっている状態から開いたときにも通知するようにする。いまの閉じた通知の振る舞いは変えない。

### App

8. `AppComposition` で、閉じた通知でいまの「ディスプレイをオフ」に加えてコントローラーの閉じたときの入口を呼び、開いた通知で開いたときの入口を呼ぶ。蓋の監視は抑止中かどうかによらず動いているので、そのまま使う。
9. 設定画面:
   - ポップアップの選択肢を「スリープ（標準）」「ディスプレイをオフ」「明るさを0」「オンのまま」の順にする（`SettingsLidCloseChoice`、`SettingsModel` の対応）。
   - 「明るさを0」が選ばれていて、3 の「変えられないと分かっている」が真なら、その行のアイコンを、ヘルパーの注意と同じ `exclamationmark.triangle.fill`（`systemOrange`）にし、(i) の先頭に下の `brightnessUnavailable` を置く。ヘルパーの注意もあるときは、`helperNotReady`、`brightnessUnavailable` の順に置く。
   - プレビュー（`SettingsPreview.swift`）が新しいポートを要るなら、偽物を渡す。
10. 文言（`SettingsSleep.xcstrings`、開発言語 `ja`）。String Catalog の形は `AGENTS.md` に従う。

| キー | 値 |
| --- | --- |
| `lidClose.zeroBrightness` | 明るさを0 |
| `lidClose.help`（置き換え） | 「スリープ」以外を選ぶと、Capsaicinがオンの間は、ディスプレイを閉じても、アップルメニューの「スリープ」などを選んでも、Macはスリープしません。使うには、管理者パスワードでヘルパーをインストールする必要があります。「明るさを0」では、閉じている間は画面を暗くするだけでロックしないため、ディスプレイを開くとすぐに操作できます。「ディスプレイを自動でオフにしない」をオフにしていると、時間が経ってディスプレイがオフになり、ロックされることがあります。 |
| `brightnessUnavailable` | このMacでは画面の明るさを変更できないため、ディスプレイを閉じても画面はオンのままになります。 |
| `brightnessUnavailable.a11y` | 警告、画面の明るさを変更できません |

### テスト

11. Swift Testing で、既存のテストの形に合わせて足す。テスト名で仕様（`SPEC-BLK-013` など）と対応させる。
    - 閉じたとき: 抑止中かつ「明るさを0」のときだけ暗くする。記録を保存してから 0 を書く。保存できなければ書かない。記録があれば記録を変えない。
    - 戻すとき: 0 なら書き戻して記録を消す。0 でなければ書かずに消す。読めない・書けないときは記録を残す。
    - 解除と利用者の終了で、輝度を書き戻してから `helperOff` が呼ばれる（`ControllerTransactionTests` のような順序の検査）。`endSession` と理由不明の終了でも戻す。
    - 起動時に記録があれば戻す。再開する場合も、開始より前に戻す。
    - `zeroBrightness` の保存と読み込み。`ResumeRecord` に輝度がない古い記録を読める。
    - `LidStateMonitor` の開いた通知。
    - 設定画面の注意の表示（「明るさを0」のときだけ、ヘルパーの注意と両方のとき）。
12. DisplayServices の実装そのものは単体テストにしない。

### 手順書

13. `docs/manual/verification.md` の4章に、「明るさを0」を実機で確かめる節を1つ足す。既存の節の書き方（目的、前提、操作、期待、中止、元に戻す、記録）に合わせる。内容は `SPEC-BLK-013` の受け入れ例のうち、閉じて開ける、閉じたまま解除する（タイマーか CLI）、閉じている間に明るさのキーで明るくしてから開ける、の3つと、閉じたまま画面収録が続き、開けてもロックされないこと。輝度は `ioreg` ではなく目で見る（`EVID-BLK-008`）。クラッシュ後の復元は、6.1 にクラッシュの手順があるならそこに1行足す。

## 守ること

- `AGENTS.md` の「破ってはいけないもの」を守る。輝度の変更に root もヘルパーも使わない。ヘルパーのサブコマンドを増やさない。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。
- 起こりにくい競合への防御を重ねない。新しい抽象は、ポートとその実装の2つで足りる。
- アプリを起動しない。`scripts/manual/` を実行しない。輝度を変えるコードを手元で動かさない（実機の確認はオーナーが行う）。
- サブエージェントを起動しない。迷ったら推測で埋めずに報告する。

## 完了条件

- `nix develop --command just check` と `nix develop --command just build` が通る。
- 11 のテストがあり、通る。
- 手順書に 13 の節がある。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- PM が差分を読む。オーナーが手順書の節で実機を確かめる。

## レビュー

PM が差分を読んだ。設計はチケットのとおりで、輝度は抑止の仕組みに入れず、戻す手順は1つの関数にまとまっている。解除・利用者の終了・理由不明の終了は `restoreStopped` の先頭、セッションの終了は `endSession` の先頭で戻し、どれも `disablesleep` を下ろすより前になる。DisplayServices の実装は関数の読み込みと内蔵ディスプレイへの読み書きだけで、余計な仕組みはない。

PM が直したこと:

- 起動時の復元が、記録を整える前（前回の起動の所有のまま）に記録を保存していた。整えた記録を保存した後、再開と後片付けの前に移した。
- `LidStateMonitor.start` の `onOpen` と、設定の行の `brightnessUnavailable` に、テストのためだけの既定値があった。開いた通知のつなぎ忘れに気づけなくなるので、既定値をなくし、テストで明示した。
- `SettingsRow` の `warning` と `warningLabel` が同じことを表していたので、`warningLabel` だけにした。
- ポートの説明から、既存の失敗の扱いの1文が消えていたので戻し、輝度だけが例外だと書いた。ロガーを呼ぶたびに作っていたので、ファイルの定数にした。
- 手順書の中止条件にあった「記録保存失敗の警告」は画面に出ないので消した。

PM が worktree で `nix develop --command just check`（SwiftPM 297件、アプリ88件）と `nix develop --command just build` を実行し、通ることを確かめた。

未確認: 実機での暗転と復元。オーナーが `docs/manual/verification.md` の 4.7 と 6.1 で確かめる。
