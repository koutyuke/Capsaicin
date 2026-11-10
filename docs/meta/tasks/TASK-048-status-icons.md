---
schema: task
id: TASK-048
title: メニューバーのアイコンを抑止の状態に合わせ、HUD のエラーと注意にシンボルを付ける
status: in_review
requirements: ["REQ-MENU-004", "REQ-HUD-001", "REQ-UI-001"]
depends_on: ["TASK-047"]
assignee: 実装者（Codex、OpenCode 経由の openai/gpt-6.1-sol）
---

# TASK-048 メニューバーのアイコンを抑止の状態に合わせ、HUD のエラーと注意にシンボルを付ける

## 目的

次の2つを実装する。先に `DEC-MENU-002`、`SPEC-MENU-005`（`docs/specs/menu.md`）、`SPEC-HUD-002` と `SPEC-HUD-004`（`docs/specs/hud.md`）、`SPEC-UI-003` と `SPEC-UI-004`（`docs/specs/ui.md`）を読むこと。

1. メニューバーのアイコンを、停止中は `custom.capsaicin.led`、抑止中は `custom.capsaicin.led.fill` にする。
2. HUD のアイコンを、開始を拒否したときは `xmark.octagon.fill`（`systemRed`）、解除したが合わせられていない制御が残ったときは `exclamationmark.triangle.fill`（`systemOrange`）にする。そのほかの場面は今のまま（LED の独自シンボル、`labelColor`）。

## 範囲

書いてよい:

- `Sources/Capsaicin/MenuBar/MenuBarController.swift`
- `Sources/Capsaicin/HUD/HUDContent.swift`、`Sources/Capsaicin/HUD/HUDView.swift`
- `Sources/Capsaicin/Settings/SettingsContent.swift`、`SettingsControls.swift`、`SettingsView.swift`（下の「シンボルの読み分け」をまとめる場合の、該当の行だけ）
- `Tests/CapsaicinTests/HUD/`、`Tests/CapsaicinTests/MenuBar/`、`Tests/CapsaicinTests/Settings/SettingsRendering.swift`

触らない: `docs/`、`.xcstrings`、`Symbols.xcassets`、`project.yml`。作業ツリーには、ほかの作業の未コミットの変更（Settings、HUD、MenuBar を含む）がある。自分の変更に必要な行だけを編集し、ほかの差分を整形したり戻したりしない。

## 作るもの

1. **メニューバー**: `MenuBarController.refresh()` で、`model.status.isBlocking` に合わせてボタンの画像を替える。15 pt の Regular の指定（`start()` にある）とテンプレート画像の指定は、どちらの画像にも同じように効くようにする。画像を作り直すのは状態が変わったときだけでよいが、そのための仕組みを新たに足さない（毎回作っても軽いなら、そのままでよい）。
2. **HUD の内容**: `HUDContent.make` で、`.startRejected` は `xmark.octagon.fill`、`.released` で `status.misalignments` が空でないときは `exclamationmark.triangle.fill` にする。エラー・注意・通常のどれかを `HUDContent` が持ち、`HUDView` がそれを色に変える。持ち方は、既存の型に最小の追加で済む形にする（例: 小さな enum のプロパティ1つ）。
3. **HUD の描画**: 今の `Image(content.symbol, bundle:)` は Asset Catalog だけを探すので、システムのシンボルが描けない。設定にある `SettingsSection.symbolImage(_:)`（名前が `custom.` で始まるかで読み分ける）と同じ規則で描く。読み分けの規則が2か所に分かれないよう、1か所にまとめて両方から使う（置き場所は HUD と設定の両方から自然に使える場所を選ぶ）。色は、エラーが `systemRed`、注意が `systemOrange`、通常は今のまま。Monochrome と置き換えアニメーション（`.symbolEffect(.replace)`、動きを減らす設定では `.opacity`）は残す。
4. **テスト**:
   - `HUDContentTests`: 開始の拒否が `xmark.octagon.fill` とエラー、合わせられていない制御が残った解除が `exclamationmark.triangle.fill` と注意、ほかの解除と開始は今の独自シンボルと通常になることを確かめる。今の期待値（拒否で `custom.capsaicin.led` など）は、仕様が変わったので新しい値に直す。
   - メニューバー: 既存の `MenuBarTests` の作り方で、停止中と抑止中の画像の違いを確かめられるなら1つ足す。確かめるために本番コードへテスト用の口を足す必要があるなら、足さずに報告する。

## 守ること

- 差分の目安は、テストを除いて 40 行程度。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。
- 起こりにくい場面への防御、新しい抽象化、設定項目を足さない。
- `git commit` しない。アプリを起動しない。`sudo`、`launchctl`、`pmset` の設定変更をしない。`scripts/manual/` を実行しない。

## 完了条件

- `nix develop --command just check` と `nix develop --command just build` が通る。範囲外の未コミット変更だけで落ちる場合は、その出力を報告する。
- `Image(` でシンボルを描く箇所のうち、`custom.` の読み分けが必要なものが1か所の規則を使っている（`grep` で確かめる）。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- メニューバーの実機での見た目（明暗、抑止の開始と解除での切り替え）と、HUD のエラーと注意の見え方はオーナーが確かめる。

## 報告してほしいこと

- 変えたファイルと、その要点
- 検証の結果（失敗があればその出力）
- 判断に迷ったことと、どう決めたか

## 追加: メニューバーのアイコンの置き換えの動き

オーナーの依頼で、メニューバーのアイコンが切り替わるときに、HUD と同じ SF Symbols の置き換えの動きを付ける。仕様は `SPEC-MENU-005` と `SPEC-UI-006` にある（PM が更新済み）。

- `NSStatusBarButton`（`NSButton`）には置き換えの動きを付ける API がない。`NSImageView.setSymbolImage(_:contentTransition:)`（macOS 14 以上、Swift では `setSymbolImage(_:contentTransition:)` と `NSSymbolReplaceContentTransition`）を使う。SDK のヘッダーで確かめること。
- 状態が変わったときだけ動かす。起動直後の最初の画像と、状態が変わらない `refresh()` では動かさない。「視差効果を減らす」（`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`）がオンなら、動かさずに替える。
- これまでの見た目を変えない: テンプレート画像としてメニューバーの明暗に従う色、15 pt の大きさ、ボタンの幅と位置、メニューを開いたときの強調、VoiceOver のラベル（ボタンに付ける）。`button.image` をやめて画像ビューを足す場合は、ボタンの幅が潰れないようにする。
- 実機で確かめられないので、色や強調の描かれ方が `button.image` のときと変わるおそれがある点は、どの実装にしたかとあわせて報告する。
- `MenuBarTests.statusIcon()` は、新しい描き方に合わせて、停止中と抑止中で画像が替わることを確かめる形に直す。
- 書いてよいファイルは `Sources/Capsaicin/MenuBar/MenuBarController.swift` と `Tests/CapsaicinTests/MenuBar/MenuBarTests.swift` だけ。差分の目安はテストを除いて 25 行程度。

## レビュー

PM が差分を読み、次を確かめた。

- メニューバーは `refresh()` で抑止の状態から画像を選び、15 pt の Regular とテンプレート画像の指定が両方の画像に効く。`start()` は `refresh()` を呼ぶので、起動直後も正しい画像になる。
- HUD は `HUDContent.Tone`（通常・エラー・注意）を持ち、`HUDView` が `labelColor`、`systemRed`、`systemOrange` に変える。Monochrome と置き換えアニメーションは残っている。
- `custom.` の読み分けは `Image(symbol:bundle:)` の1か所にまとまり、HUD、サイドバー、設定の行から使う。置き場所は設定のファイル（`SettingsControls.swift`）で、範囲の制約による。
- テストは、変更前に `HUDContentTests.rejectionReasons()`、`unalignedRelease()`、`MenuBarTests.statusIcon()` が失敗し、変更後に通る（実装者の報告）。
- 仕様の受け入れ例（`SPEC-MENU-005`）に「アイコンの見た目は変わらない」が残っていたので、PM が直した。
- `just check`（アプリ 85、パッケージ 145 などのテスト）と `just build` は成功した。

追加の置き換えの動きについて、PM が差分を読み、次を確かめた。

- `NSStatusBarButton` には置き換えの API がないため、ボタンに `NSImageView` を重ね、`setSymbolImage(_:contentTransition: .replace)` で替える。ボタンの幅は起動時に標準の画像付きボタンで測って固定する。
- 動くのは表示中のシンボルが変わったときだけで、起動直後、同じ状態の `refresh()`、「視差効果を減らす」がオンのときは動かさない。
- 実装者は、ステータス項目を作る既存のテスト（`visibility(initiallyVisible:)`）を禁止事項と取り違えて除外していた。既存のテストは禁止の対象ではないので、PM が `just check` をすべて流し、成功した。`just build` も成功した。

残っていること:

- 画像ビューは `button.image` の描画経路を通らないため、メニューバーの明暗での色、メニューを開いたときの強調が、ほかの項目と変わるおそれがある。崩れていたら、動きをやめて `button.image` に戻す。

- メニューバーの明暗での塗りつぶしの版の見え方（LED の穴が「消えている」と読まれないか、`DEC-MENU-002` の覆す条件）と、HUD のエラーと注意の見え方は、オーナーが実機で確かめる。
