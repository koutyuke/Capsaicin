---
schema: task
id: TASK-043
title: 設定画面をスリープ防止の統合、アイコン付きのカード、終了ボタンの移動、新しい文言に作り直す
status: in_review
requirements: ["REQ-SET-002", "REQ-SET-003", "REQ-SET-004", "REQ-SET-005", "REQ-MENU-005"]
depends_on: []
assignee: Codex（OpenCode の openai/gpt-6.1-sol）
---

# TASK-043 設定画面を作り直す

## 目的

`DEC-SET-004`、`DEC-UI-009`、`DEC-UI-010` のとおりに設定画面を作り直す。保存値、止める仕組み、有効・無効の規則（`SleepSettingsPresentation`）は変えない。見た目、並び、文言だけを変える。

## 範囲

書いてよい:

- `Sources/Capsaicin/Settings/`（Swift と String Catalog。`SettingsRelease.xcstrings` は削除する）
- `Sources/Capsaicin/CLI/CLI.xcstrings`（下の2つのキーだけ）
- `Tests/CapsaicinTests/`

触らない:

- `docs/`。別のエージェントが `TASK-042` で同時に仕様を直している。仕様の正は、3つの判断とこのチケットである。
- `Packages/`、`Sources/capsaicin-helper/`、`Sources/capsaicin-cli/`、`project.yml`。
- 作業ツリーにある別の作業の変更（`project.yml`、`TASK-033`、`TASK-036`、ステージ済みの `HelperScripts.swift`、`HelperScriptsTests.swift`、`helper.md`、`helper.toml`）。`git add`、`git restore`、`git stash` などで index や他の変更を動かさない。
- `git commit` はしない。

## 作るもの

### 1. セクション

- `SettingsSection` から `release` を取り除き、6つにする（`general`、`sleep`、`led`、`controls`、`helper`、`about`）。`sleep` の `rawValue` は変えない（前回のセクションの保存値をそのまま使う）。保存値が `release` のときは、今の処理どおり `general` に戻ってよい。変換の処理は足さない。
- 解除の条件の文言は `SettingsSleep.xcstrings` に移し、`SettingsRelease.xcstrings` を削除する。1セクション1テーブルの今の決まり（`SettingsSection.text`）を保つ。
- サイドバーは上の4つ（一般、スリープ防止、LED、操作）と下の2つ（ヘルパー、このアプリについて）。下の2つはサイドバーの下端に寄せる（今の `SettingsSidebarSpacer` の仕組みを 6 項目に合わせて直す）。サイドバーの下端の「終了」ボタン（`safeAreaInset`）は取り除く。サイドバーの下の余白はシステム既定のままにする。

### 2. カードとアイコン

- 各セクションを、下の表のカード（`Form` の `Section`）に分ける。見出しは、そのグループの最初のカードに `Section` のヘッダーとして付ける。
- `SettingsRow` に、項目名の左に置く SF Symbols のアイコン（省略可能）を足す。アイコンは `secondary` の色で、すべての行で同じ幅の列（たとえば幅 20 pt、中央ぞろえ）に置き、項目名の始まりをそろえる。
- 子の行はアイコンを持たず、今の 20 pt の字下げの代わりに、項目名の始まりを親の項目名にそろえる（アイコンの列の幅と間隔のぶんだけ空ける）。
- ヘルパーが要る行の注意の表示（`warning`）は、項目名の前に三角形を足すのではなく、その行のアイコンを `exclamationmark.triangle.fill`（`orange`）に置き換える。アクセシビリティのラベル（`helperNotReady.a11y`）は今のまま付ける。
- 読み取り専用の案内の行（一般の自動再起動の案内、LED の Karabiner-Elements の案内）は、アイコンを `exclamationmark.triangle.fill`（`orange`）にし、右側の三角形を取り除く。

| セクション | 見出し | カード | 行（アイコン） |
| --- | --- | --- | --- |
| 一般 | 起動 | 1 | `launchAtLogin`（`power`）、`resume`（`arrow.clockwise`）、`backgroundDisabled` か `restartUnavailable`（出るときだけ、三角形） |
| 一般 | 表示 | 2 | `hud`（`capsule.bottomhalf.filled`）、`menuBarIcon`（`menubar.rectangle`）、`dockIcon`（`dock.rectangle`） |
| スリープ防止 | 防止中の動作 | 1 | `display`（`display`） |
| スリープ防止 | なし | 2 | `manualAndLid`（`laptopcomputer`）か、蓋のない Mac では `manual`（`powersleep`）。子: `lidDisplay`（蓋のある Mac だけ） |
| スリープ防止 | 自動でオフにする条件 | 3 | `timer`（`timer`）。子: `timer.duration` |
| スリープ防止 | なし | 4 | `time`（`clock`）。子: `time.value` |
| スリープ防止 | なし | 5 | `battery`（`battery.50percent`）。子: `battery.threshold`、`battery.ignoreOnAdapter`（内蔵バッテリーのある Mac だけ） |
| LED | なし | 1 | `karabiner`（検出したときだけ、三角形） |
| LED | なし | 2 | `enabled`（`capslock.fill`） |
| 操作 | ホットキー | 1 | `hotkey`（`command`）、割り当ての失敗の表示（今のまま） |
| 操作 | コマンドライン | 2 | `cli`（`terminal`）、`cli.path`（`folder`） |
| ヘルパー | なし | 1 | `status`（`lock.shield`）、`manage`（`wrench.and.screwdriver`） |

スリープ防止の行の表示（有効・無効、注意の表示、子の行が使える条件）は今の `SettingsSleepRow.rows` と同じにする。解除の条件の行は、今の `release` の中身をそのまま移す。アイコンの対応は `SettingsSleepRow` に持たせるなど、行の定義と同じ場所に置く。

### 3. このアプリについて

今の中央の縦の並び（アイコン、名前、バージョン）の下に、「Capsaicinを終了」ボタンを置く。文言はメニューと同じキー（`MenuContent.text("menu.quit", bundle:)`）を使う。標準の `Button`、`.buttonStyle(.bordered)`、色なし、標準の大きさ。押すと `SettingsView.quit` を呼ぶ。バージョンとの間は、並びの間隔より少し広く空ける（たとえば 12〜16 pt）。

### 4. 文言

String Catalog は Xcode が書く形（`"key" : value`、末尾の改行なし）を保つ。コードから引くキーには `"extractionState" : "manual"` を付ける。`stale` のキーを残さない。下にないキーは今のまま移す（解除の条件のキーは文言を変えずに `SettingsSleep.xcstrings` へ移す）。

`SettingsSleep.xcstrings`:

| キー | 文言 |
| --- | --- |
| `title` | スリープ防止 |
| `behavior.group.title`（新規） | 防止中の動作 |
| `release.group.title`（新規） | 自動でオフにする条件 |
| `display.label` | ディスプレイを自動でオフにしない |
| `display.help` | スリープ防止中は、一定時間操作がなくてもディスプレイがオフにならず、スクリーンセーバも始まりません。macOSの仕様上、2つは個別に設定できません。オフにすると、システム設定の時間どおりにスクリーンセーバが始まり、ディスプレイがオフになります。Mac本体はスリープしません。 |
| `manualAndLid.label` | ディスプレイを閉じてもスリープしない |
| `manualAndLid.help` | スリープ防止中は、ディスプレイを閉じてもMacがスリープしません。アップルメニューの「スリープ」などを選んでもスリープしなくなります。macOSの仕様上、2つは個別に設定できません。利用には管理者のパスワードによるヘルパーのインストールが必要です。 |
| `manual.label` | メニューから選んでもスリープしない |
| `manual.help` | スリープ防止中は、アップルメニューの「スリープ」などを選んでもMacがスリープしません。利用には管理者のパスワードによるヘルパーのインストールが必要です。 |
| `lidDisplay.label` | 閉じたときのディスプレイ |
| `lidDisplay.turnOff` | オフにする |
| `lidDisplay.keepOn` | オンのままにする |
| `lidDisplay.help` | 「ディスプレイを閉じてもスリープしない」がオンで、ヘルパーがインストールされているときに使えます。ディスプレイを閉じたときに、Macを動かしたままディスプレイをオフにするか、オンのままにするかを選びます。「オフにする」にすると消費電力を抑えられます。 |
| `time.value.label` | 時刻 |
| `battery.ignoreOnAdapter.label` | 電源アダプタ接続中は残量を無視 |

削除するキー: `group.title`、`time.group.title`、`battery.group.title`。

`SettingsGeneral.xcstrings`:

| キー | 文言 |
| --- | --- |
| `startup.group.title`（新規） | 起動 |
| `appearance.group.title`（新規） | 表示 |
| `menuBarIcon.help` | オフにしてもCapsaicinは動き続けます。設定を開くにはFinderやSpotlightからCapsaicinをもう一度開き、終了するには設定の「このアプリについて」にある「Capsaicinを終了」を押します。 |

`SettingsControls.xcstrings`:

| キー | 文言 |
| --- | --- |
| `hotkey.help` | ホットキーでスリープ防止をオンにしたときは、「スリープ防止」の「自動でオフにする条件」が適用されます。 |

`SettingsHelper.xcstrings`:

| キー | 文言 |
| --- | --- |
| `helperInstall.manualAndLid.title` | 「ディスプレイを閉じてもスリープしない」を使うにはヘルパーのインストールが必要です |
| `helperInstall.setting.title` | 「メニューから選んでもスリープしない」を使うにはヘルパーのインストールが必要です |
| `helperRemove.message` | 削除すると、ヘルパーを必要とするスリープ防止の設定がオフになります。スリープ防止中の場合は、ディスプレイを閉じたときやメニューから選んだときに、Macがスリープするようになります。削除には管理者のパスワードが必要です。 |
| `status.help` | メニューやディスプレイを閉じたときのスリープを防ぐ小さなプログラム、パスワードなしでの実行を許可する設定、Mac起動時にスリープ設定を安全に戻す項目の3つをシステムにインストールします。 |

`CLI.xcstrings`:

| キー | 文言 |
| --- | --- |
| `mechanism.systemSleepDisabled` | メニューやディスプレイを閉じたときのスリープを防ぐ設定 |
| `mechanism.displaySleepAssertion` | ディスプレイを自動でオフにしない設定 |

### 5. テスト

- `Tests/CapsaicinTests/Settings/SettingsTests.swift` を新しい構成に合わせる。サイドバーの行数、↑↓ の移動、下の2つが下端に寄ること、全セクションの描画（`.build/settings/*.png`）を保つ。
- サイドバーの「終了」ボタンを押す確認は、「このアプリについて」の「終了」ボタンを押すと `quit` が呼ばれる確認に置き換える。
- 「解除の条件」がスクロールせずに収まる確認は、スリープ防止がスクロールを許すので取り除く。代わりに「一般」が収まることを確かめる。
- 見出しのあるセクションを最上部の余白の確認から除く条件を、新しい構成（一般、スリープ防止、操作には見出しがある）に合わせる。見出しの位置の確認方法は今のテストのやり方に合わせる。
- 文言の存在の確認（`title` のキーなど）が、削除した `SettingsRelease` を参照しないようにする。
- CLI の文言を引くテストがあれば、新しい文言に合わせる。

## 守ること

- 起こりにくい場面への防御、汎用の仕組み、新しい抽象を足さない。今のコード（`SettingsRow`、`toggle`、`SettingsSleepRow`）を少し広げて作る。
- `SettingsView.swift` が長くなりすぎるなら、セクションごとに extension やファイルを分けてよい。ただし分けることを目的にしない。
- 本番コードに `REQ-*`、`SPEC-*` を書かない。
- 画面の振る舞いや、保存値の読み書きは変えない。

## 完了条件

- 上の「作るもの」がすべて実装されている。
- `nix develop --command just check` と `nix develop --command just build` が成功する。
- `.build/settings/` に描画した各セクション（ライト、ダーク）の PNG で、カード、見出し、アイコン、子の行のそろい方、このアプリについての終了ボタンが見える。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 報告には、変更したファイル、テストの結果、`.build/settings/` の PNG のパス、判断に迷ったことを書く。

## レビュー

PM がコードと `.build/settings/` の描画を確かめた。カード、見出し、アイコン、子の行のそろい方、このアプリについての終了ボタンはチケットどおりである。

- 作業中にオーナーが用語を改めた（`DEC-UI-009`）。PM が文言を次のとおり差し替えた。表の文言はこの差し替えで置き換わっている。
  - `display.label`「自動でディスプレイスリープしない」、`manualAndLid.label`「ディスプレイを閉じてもシステムスリープしない」、`manual.label`「メニューから選んでもシステムスリープしない」、`lidDisplay.turnOff`「ディスプレイスリープ」、`lidDisplay.keepOn`「オンのまま」。各 `help` は「システムスリープ（Mac全体のスリープ）」と一度言い換える。
  - ヘルパーの確認ダイアログと削除の説明、`status.help`、CLI の `mechanism.*` の3つを同じ用語にした。`mechanism.idleSleepAssertion` も「自動でシステムスリープしない設定」にそろえた。
  - `SettingsTests` の CLI の文言の期待値を合わせた。
- `just check`（アプリのテスト 75 件）と `just build` は成功した。
- オーナーの確認で、サイドバーにスクロールバーが出ることが分かった。サイドバーの表は行のほかに既定の余白（実測で下に 10 pt）を持ち、終了ボタンを外したあとの空き行の計算がそれを引いていなかったため、内容が見える高さを 10 pt はみ出していた。テストは最後の行が見える領域の下端に届くことしか見ておらず、はみ出しを見逃していた。PM が空き行の計算で表の余白を引くように直し、余白は表がはみ出しているときに測って覚えるようにした（内容が短いと表は見える高さまで伸び、余白を測れないため）。テストは、内容が見える高さちょうどでスクロールしないことを確かめる形に改めた。
- その後オーナーが、用語を macOS のシステム設定に合わせる方針に改めた（Mac 全体は「スリープ」、ディスプレイは「オフにする」、画面の文言に「防止」を増やさない）。PM が文言を次のとおり差し替えた。`DEC-UI-009` と仕様の改訂、機能名「スリープ防止」と `release.group.title` の扱いは未決である。
  - `title`「スリープ」、`behavior.group.title`「スリープとディスプレイ」、`display.label`「ディスプレイを自動でオフにしない」、`manualAndLid.label`「ディスプレイを閉じてもスリープさせない」、`manual.label`「メニューから選んでもスリープさせない」、`lidDisplay.turnOff`「オフにする」。各 `help` から「システムスリープ」「ディスプレイスリープ」を除いた。
  - ヘルパーの確認ダイアログと削除の説明、`status.help`、`hotkey.help`、CLI の `mechanism.*` の3つを同じ用語にし、`SettingsTests` の期待値を合わせた。`just check` と `just build` は成功した。
- 実機での見た目と操作はオーナーが確かめる。
