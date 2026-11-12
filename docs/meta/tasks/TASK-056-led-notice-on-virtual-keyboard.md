---
schema: task
id: TASK-056
title: キー配列を変更するアプリの案内を、仮想キーボードがあるときに出す
status: done
requirements: ["REQ-LED-007"]
depends_on: ["TASK-054", "TASK-055"]
assignee: Codex（Codex のハーネス、gpt-6.1-sol、推論 high）
---

# TASK-056 キー配列を変更するアプリの案内を、仮想キーボードがあるときに出す

## 目的

案内は、Karabiner-Elements の常駐プロセスがあれば出る。アプリを終了しても常駐プロセスは残るので、案内が出続ける（`EVID-LED-009`）。案内を Karabiner-Elements に限らず、仮想キーボードがあるときに出し、LED が点灯しない可能性だけを伝える形に直す（`DEC-LED-006`、`SPEC-LED-005`）。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/KarabinerElementsMonitor.swift`（名前を変えてよい）
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/KarabinerProcessSource.swift`（削除する）
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/CapsLockLEDController.swift`（`LEDClient` と `LEDService` をほかの型から使うのに必要な範囲だけ）
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/LED/`
- `Sources/Capsaicin/App/AppComposition.swift`、`Sources/Capsaicin/App/AppModel.swift`
- `Sources/Capsaicin/MenuBar/MenuBarController.swift`、`Sources/Capsaicin/MenuBar/MenuContent.swift`
- `Sources/Capsaicin/MenuBar/MenuBar.xcstrings`、`Sources/Capsaicin/Settings/SettingsLed.xcstrings`（案内のキーだけ）
- `Sources/Capsaicin/Settings/SettingsView.swift`
- `Tests/CapsaicinTests/MenuBar/MenuBarTests.swift`

触らない: 上記以外のすべて。LED への書き込みの振る舞い（対象、書く値、失敗の判定、ログ）は変えない。

## 作るもの

- **検出:** 5秒ごとに確かめて表示を切り替える仕組みは、いまの `KarabinerElementsMonitor` のまま使う。確かめる中身を、「Karabiner-Elements の既知の実行ファイルのプロセスがあるか」から「キーボード（usage page 1・usage 6）のサービスのうち、`Transport` を持たないものがあるか」に替える。
  - サービスの列挙と判定は、LED の書き込みと同じ `LEDClient` と `LEDService` の `isKeyboard`・`hasTransport` を使う。仮想キーボードの判定を2か所に書かない。
  - LED の制御に使う関数がない環境（`CapsaicinLEDClientSymbolAvailable()` が `false`）では、`LEDClient.native()` を呼ばずに「仮想キーボードなし」とする。弱いリンクの関数を、ないときに呼ぶとクラッシュするためである。この環境では LED の機能そのものが無効になる（`SPEC-LED-006`）。
  - `KarabinerProcessSource` と、そのテストは削除する。
- **名前:** Karabiner-Elements に限った名前を、キー配列を変更するアプリ（または仮想キーボード）を指す名前に直す。対象は、型、プロパティ（`isKarabinerRunning`）、引数（`karabiner:`）、メニューの ID（`separator.karabiner`）、String Catalog のキー（`karabiner.label`、`karabiner.help`、`menu.karabiner.title`、`menu.karabiner.subtitle`）、ログのカテゴリー、テスト名である。名前は任せるが、1つの概念に揃える。
- **文言:** String Catalog の日本語を次にする。String Catalog にほかの言語はない。
  - メニューの項目と設定の見出し: 「キー配列を変更するアプリが動作中」
  - メニューの副題: 「LEDが点灯しないことがあります」
  - 設定の説明: 「そのアプリがCaps LockのLEDを制御している場合、スリープ防止中もLEDが点灯しないことがあります。」
- **テスト:** 次を確かめる。
  - `Transport` を持たないキーボードがあれば「あり」、実機のキーボードだけなら「なし」、`Transport` を持たないサービスがあってもキーボードでなければ「なし」。
  - LED の制御に使う関数がないときは、クライアントを作らずに「なし」。
  - サービスを列挙できないときは、いまのプロセスの一覧の失敗と同じく、検出の失敗として扱う。
  - メニューと設定の案内のテストは、名前を直したうえで、いまと同じことを確かめる。

## 守ること

- 案内の見た目（アイコン、色、置く位置、出入りの仕方）は変えない。
- 入力監視の権限を求めない（`REQ-LED-008`）。非公開の関数を増やさない。
- 本番コードに `REQ-*`・`SPEC-*`・`HYP-*`・`DEC-*` を書かない。
- String Catalog は Xcode の書式（`"key" : value`、末尾の改行なし）を保ち、コードから動的に引くキーには `"extractionState" : "manual"` を付ける。
- `git commit` をしない。アプリの起動や、`scripts/manual/` の実行をしない。

## 完了条件

- 上の「作るもの」を満たす。
- `nix develop --command just check` と `nix develop --command just build` が通る。
- オーナーの実機の確認で、`SPEC-LED-005` の受け入れ例が満たされる。

## 検証

- PM が差分を読み、`just check` と `just build` を流す。
- 実機はオーナーが `docs/manual/led-fix-verification.md` の手順4と手順5で確かめる。Karabiner-Elements を起動するとメニューと設定に案内が出て、メニューバーから終了すると数秒のうちに消えること、Karabiner-Elements を使わない状態では出ないことを見る。

## レビュー

- Codex が実装し、`just check` と `just build` を通した。監視の型を `VirtualKeyboardMonitor`、状態を `hasVirtualKeyboard`、String Catalog のキーを `virtualKeyboard.*` と `menu.virtualKeyboard.*` に揃えた。検出は `LEDClient` を作り、`isKeyboard` かつ `hasTransport` でないサービスがあるかを見る。関数がないときは、クライアントを作らずに「なし」を返し、検出の失敗にも数えない。
- テストのフィクスチャの `makeClient` を、LED の書き込みと検出のテストで共有する形にした。メニューの案内のテストは、型の本体が長くなりすぎないよう、同じファイルの `extension` に移した。
- PM が差分を読み、`just check` と `just build` を流し直して、どちらも通った。
- オーナーが 2026-11-11 に `docs/manual/led-fix-verification.md` の手順1、手順4、手順5を行い、`SPEC-LED-005` の受け入れ例を満たした。記録は `~/capsaicin-led-check/20261111-221214/` にある。
  - Karabiner-Elements を止めた状態では、メニューにも設定にも案内が出なかった。
  - 設定の案内は、Karabiner-Elements の終了から約3.3秒で消え、起動から約4.8秒で戻った。メニューも10秒以内に切り替わった。見出し、副題、説明は指定どおりだった。
  - 検出の失敗のログはなかった。何も操作していない約10分間（22:31〜22:40）、RSS は 153 MB 前後で横ばいで、CPU は 0〜1.3% だった。
