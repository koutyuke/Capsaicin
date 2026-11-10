---
schema: task
id: TASK-047
title: LED の独自シンボルを組み込み、capslock を置き換える
status: in_review
requirements: ["REQ-MENU-004", "REQ-UI-001", "REQ-UI-004"]
depends_on: []
assignee: 実装者（Codex、OpenCode 経由の openai/gpt-6.1-sol）
---

# TASK-047 LED の独自シンボルを組み込み、capslock を置き換える

## 目的

オーナーが SF Symbols のテンプレートから作った独自シンボル `custom.capsaicin.led`（輪郭）と `custom.capsaicin.led.fill`（塗りつぶし）をアプリに入れ、SF Symbols の `capslock` と `capslock.fill` を使っているすべての場所を置き換える。判断は `DEC-MENU-001`、振る舞いは `SPEC-MENU-005`、`SPEC-HUD-001`、`SPEC-HUD-002`、`SPEC-UI-004`、`SPEC-SET-001`、`SPEC-SET-002` にある。先に読むこと。

## 範囲

書いてよい:

- `Sources/Capsaicin/Resources/Symbols.xcassets/`（新規）
- `treefmt.nix`
- `Sources/Capsaicin/MenuBar/MenuBarController.swift`
- `Sources/Capsaicin/HUD/HUDContent.swift`、`Sources/Capsaicin/HUD/HUDView.swift`
- `Sources/Capsaicin/Settings/SettingsContent.swift`、`Sources/Capsaicin/Settings/SettingsView.swift`、`Sources/Capsaicin/Settings/SettingsControls.swift`（シンボルの表示に関わる行だけ）
- `Tests/CapsaicinTests/HUD/HUDContentTests.swift`、`Tests/CapsaicinTests/HUD/HUDPresentationTests.swift`、`Tests/CapsaicinTests/` の既存のテストファイル（必要な場合だけ）
- `project.yml`（必要な場合だけ。ディレクトリ単位の指定で Asset Catalog が入るなら触らない）

触らない: `docs/`、ほかの `.xcstrings`。Settings と `docs/` には、この作業とは別の未コミットの変更がある。自分の変更に必要な行だけを編集し、ほかの差分を整形したり戻したりしない。

## 作るもの

1. Asset Catalog `Sources/Capsaicin/Resources/Symbols.xcassets/` を作り、シンボル画像のセット `custom.capsaicin.led.symbolset` と `custom.capsaicin.led.fill.symbolset` を置く。SVG はオーナーの素材をそのまま使う（中身を書き換えない）。
   - 輪郭: `/Users/koutyuke/.t3/userdata/attachments/094b4c5e-e629-4545-83df-207386f0af0c-a0f97707-0113-4746-914e-ae76060bec22-svg.svg` → `custom.capsaicin.led.svg`
   - 塗りつぶし: `/Users/koutyuke/.t3/userdata/attachments/094b4c5e-e629-4545-83df-207386f0af0c-c3ff6502-de1a-42c7-b020-5720141e1636-svg.svg` → `custom.capsaicin.led.fill.svg`
   - `Contents.json` は Xcode が書く形（`"key" : value`、2 スペース）にする。
2. `treefmt.nix` の除外に `**/*.xcassets/**` を足す。理由のコメントは既存の `*.icon` の行に合わせる（Xcode が書く形を正とする）。
3. メニューバー: `NSImage(systemSymbolName:)` を、アプリの Asset Catalog の独自シンボルを読む API に替える（`NSImage(symbolName:bundle:variableValue:)` など。SDK で確かめる）。表示は停止中も抑止中も `custom.capsaicin.led` のまま。
4. HUD: `HUDContent` のシンボル名を `custom.capsaicin.led` と `custom.capsaicin.led.fill` に替え、`HUDView` で独自シンボルとして描く。置き換えアニメーション（`.contentTransition(.symbolEffect(.replace))`）はそのまま残す。左の余白を 17 pt から 19 pt に変え、コメントを独自シンボルの空白（約 1 pt）に合わせて直す（`SPEC-HUD-002`）。プレビュー用の既定値（`HUDView.swift:14` 付近）も替える。
5. 設定: サイドバーの LED（`SettingsSection.symbol`）を `custom.capsaicin.led`、「Caps Lock の LED で知らせる」の行を `custom.capsaicin.led.fill` にする。サイドバーの `Label(_:systemImage:)` と `SettingsRow` の `Image(systemName:)` は SF Symbols 前提なので、独自シンボルも描けるようにする。
   - システムのシンボルと独自シンボルの見分けは、名前が `custom.` で始まるか（`DEC-MENU-001` の命名）で行い、その判定を1か所にまとめる。新しい型や抽象化は足さない。
   - 文字列と同じく、画像もコードを含むバンドル（`Bundle(for: SettingsResources.self)` など）から読む。テストのバンドルで描画しても空にならないようにする。
6. テストの期待値を新しい名前に替える。

## 守ること

- 差分の目安は、Asset Catalog とテストを除いて 30 行程度。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。
- `git commit` しない。アプリを起動しない。`sudo`、`launchctl`、`pmset` の設定変更をしない。

## 完了条件

- ビルドしたアプリの `Assets.car` に2つのシンボルが入っている（`xcrun assetutil --info` などで確かめる）。
- コードに `"capslock"` と `"capslock.fill"` が残っていない（`grep` で確かめる）。
- `nix develop --command just check` と `nix develop --command just build` が通る。範囲外の未コミット変更だけで落ちる場合は、その出力を報告する。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- `.build/settings/` の描画結果で、サイドバーの LED と「Caps Lock の LED で知らせる」の行に新しいシンボルが出ていることを見る。
- メニューバーと HUD の実機での見た目（明暗のメニューバー、Wi-Fi などとの太さと高さ、HUD の左右の余白と置き換えの動き）はオーナーが確かめる。

## 報告してほしいこと

- 変えたファイルと、その要点
- 検証の結果（失敗があればその出力）
- 判断に迷ったことと、どう決めたか

## レビュー

PM が差分を読み、次を確かめた。

- Asset Catalog の SVG はオーナーの素材とバイト単位で一致し、`Contents.json` は Xcode の形になっている。`treefmt.nix` の除外は `*.icon` と同じ書き方である。
- メニューバーは `NSImage(symbolName:bundle:variableValue:)`、HUD は `Image(_:bundle:)` で独自シンボルを読み、置き換えアニメーションを残している。HUD の左の余白は 19 pt で、コメントも直っている。のちに素材の余白線が広がった（`.title3` で約 1.9 pt）ため、PM が 18 pt に直した。
- 設定は `SettingsSection.symbolImage(_:)` の1か所で `custom.` の接頭辞を見て、システムのシンボルと独自シンボルを描き分ける。画像は文字列と同じバンドルから読む。
- テストのバンドルには bundle ID がなく、Asset Catalog から独自シンボルを読めなかった。PM の承認で、テストターゲットに `PRODUCT_BUNDLE_IDENTIFIER` を1行足した。
- `just check` と `just build` は成功した。`.build/settings/led-*.png` で、LED の行に塗りつぶしの版が出ている。

残っていること:

- 設定のサイドバーの LED のアイコンが出なかった（テストの実行中に `No image named 'custom.capsaicin.led' found in asset catalog` が出た）。サイドバーの既定は scale L なので、オーナーが輪郭の版に Regular-L を足した。差し替え後は警告が出ず、`Assets.car` に S、M、L が入っている。
- 外形を 116 に広げると設定画面で `capslock` より大きく見え、108 だとメニューバーで小さく見えた。シンボルは 108（`capslock` と同じ大きさ）に戻し、メニューバーだけ 15 pt で描く（`SPEC-MENU-005`）。オーナーの最終素材は、輪郭と塗りつぶしの外形、LED の位置、余白線が一致し、S、M、L がそろっている。
- 名前に `capslock` が残ると SF Symbols の `capslock` と見分けにくいため、オーナーの判断で `custom.capslock.led` から `custom.capsaicin.led` に改めた（`DEC-MENU-001`）。
- 消灯の意匠は5案（LED を塗る・内側を半透明にするなど）を比べ、2系統のアドバイザーとも現在の輪郭の案を推した。半透明の案は階層表示の指定が1か所でも抜けると点灯と見分けにくくなるため採らない。
- オーナーの2回目の素材では、塗りつぶしの版の S のグループ名が `Regular-M_2` になっていたので、PM が Asset Catalog の写しで `Regular-S` に直した。素材の余白線も広がったため、HUD の左の余白を合わせて直した。
- メニューバーと HUD の実機での見た目（明暗のメニューバー、ほかの項目との太さと高さ、HUD の左右の余白と置き換えの動き）は、オーナーが確かめる。
