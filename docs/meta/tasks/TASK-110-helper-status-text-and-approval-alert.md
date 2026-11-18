---
schema: task
id: TASK-110
title: ヘルパーを使えない行に状態の文を出し、承認待ちのときの選び直しで許可を案内するアラートを出す
status: in_review
requirements: ["REQ-HLP-001", "REQ-SET-003", "REQ-SET-005"]
depends_on: []
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-110 ヘルパーを使えない行に状態の文を出し、承認待ちのときの選び直しで許可を案内するアラートを出す

## 目的

オーナーの実機の確認（`EVID-HLP-006`）を受けて、`DEC-SET-007` で次の2つを決めた。

1. ヘルパーが要る行がヘルパーを使えないための注意の記号を出している間は、項目名の下に短い状態の文（「ヘルパーが有効になっていません」程度）を出す。理由と直し方は今の (i) のまま。
2. ヘルパーが承認待ちのときに、設定でヘルパーが要る値を選んだら、システム設定を直接開かずに、許可を案内するアラートを出す。利用者が「システム設定を開く」を選んだら開き、選んだ値を保留する。「キャンセル」なら選んだ値を捨てる。

振る舞いの正は次の仕様である。

- `docs/specs/settings.md`: `SPEC-SET-003`（状態の文の例外）、`SPEC-SET-005`（状態の文を出す場面と見た目。「明るさを0」の注意だけのときは出さない）
- `docs/specs/helper.md`: `SPEC-HLP-001`（承認待ちの行の扱い、受け入れ例「承認待ちのときに設定で選び直す」）、`SPEC-HLP-006`（「許可の案内」の行）

## 範囲

変更してよいもの: `Sources/Capsaicin/Settings/` の下（`SettingsModel.swift`、`SettingsContent.swift`、`SettingsView.swift`、`SettingsControls.swift`、`SettingsSleep.xcstrings`、`SettingsHelper.xcstrings` など必要なもの）、`Tests/CapsaicinTests/Settings/` の下。

触らないもの: `docs/`（このチケットを除く）、`Packages/`、`Sources/capsaicin-helper/`、「ヘルパー」セクションの「システム設定を開く」ボタンの振る舞い（確認なしで開くまま）。

## やること

1. 状態の文: 注意の記号の理由がヘルパーを使えないこと（保留中の選択、またはヘルパーが要る保存値とヘルパーが「有効」でない状態）のときだけ、その行の項目名の下に1行の文を出す。MacBook の「ディスプレイを閉じたとき」と、MacBook 以外の Mac の「メニューから選んでもスリープさせない」の両方が対象。「明るさを0」を使えない注意だけのときは出さない。見た目は `secondaryLabelColor` の小さめの文字。`SettingsRow` に足すなら、既存の呼び出しの見た目を変えない形にする。VoiceOver でも読めるようにする。
2. 許可の案内: `SettingsModel.manage(_:fromSetting:lidClose:)` の承認待ちの分岐で、設定から始めたときは `SPEC-HLP-006` の「許可の案内」のアラートを、他のダイアログと同じ仕組み（シート）で出す。既定のボタンは「システム設定を開く」、もう一方は「キャンセル」。開くを選んだら、シートを閉じてからシステム設定を開き、選んだ値を保留する（今の保留と同じ扱い）。キャンセルなら保留を捨て、保存値に対応する表示に戻す。「ヘルパー」セクションから始めたとき（`fromSetting == false`）は今のまま確認なしで開く。
3. 文言: 英語と日本語を足す。日本語は既存の文言の語調に合わせ、英語は macOS の標準の言い回し（「Login Items & Extensions」）に合わせる。
4. テスト: 状態の文を出す場面と出さない場面（保留中、保存値とヘルパーが使えない、「明るさを0」の注意だけ、ヘルパーが有効）、許可の案内で開く・取り消すときの保留と保存値、「ヘルパー」セクションからは案内を出さないこと、を Swift Testing で確かめる。

## 守ること

- `AGENTS.md` を読んでから始める。アプリを起動しない。`sudo`、`launchctl`、`sfltool` を実行しない。
- String Catalog は機能フォルダーごとのテーブルを使い、すべてのキーに英語と日本語を持たせる。Xcode の書式（`"key" : value`、末尾の改行なし）に合わせる。`stale` のキーを残さない。
- 日本語の文言は `~/.claude/skills/yomiyasu/SKILL.md` に従って推敲する。「蓋」という語は使わない。
- 本番のコードに `REQ-*` と `SPEC-*` を書かない。
- `git commit` と `git push` をしない。

## 完了条件

- 1〜4 を満たす。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just check`
- 実機（オーナー）: PR の Debug ビルドで、承認待ちの間の状態の文と、承認待ちのときの選び直しのアラートを確かめる。

## レビュー

PM がレビューした。状態の文は行の状態が「ヘルパーなしで要る値」のときだけ、既存の `SettingsRow` の副題で出す。許可の案内は既存の確認のシートを使い、シートを閉じてからシステム設定を開く。「ヘルパー」セクションからは今のまま直接開く。既存のテスト `AppRuntimeTests` の1行は、案内で開くを選ぶ応答を足すもので、PM が許可した。指摘なし。`just check` は通る（アプリ 175）。
