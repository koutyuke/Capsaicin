---
schema: decision
id: DEC-SET-003
title: 設定画面は強制の有効化で前面に出し、Space は macOS の標準の動きに任せる
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-SET-002", "REQ-MENU-005"]
based_on: ["EVID-SET-001", "HYP-SET-003"]
---

# DEC-SET-003 設定画面は強制の有効化で前面に出し、Space は macOS の標準の動きに任せる

## 結論

- 設定画面を前面に出すときは、`NSApp.activate()` ではなく `NSApp.activate(ignoringOtherApps: true)` を呼んでから `makeKeyAndOrderFront` する。
- 設定画面の `collectionBehavior` は標準のまま（`.managed`）にして、`.fullScreenAuxiliary` だけを足す。`.moveToActiveSpace` と `.canJoinAllSpaces` は付けない。

## 背景

ステータスアイコンのメニューから設定画面を開いても、前面に出なかったり、画面のある Space へ移らなかったりした。`NSApp.activate()` は協調的な有効化で、前面のアプリが譲っていなければ要求が通るとは限らない（`EVID-SET-001`）。通らないと、設定画面は前面のアプリの裏に並び、Space も切り替わらない。

オーナーは、一般的で、かつ安全なやり方を求めた。ここでの安全とは、ハック（遅延、Dock を経由した有効化、非公開 API）に頼らないこと、利用者の設定（Dock の表示、Space の切り替え）を勝手に変えないこと、外部から呼べる入口を増やさないことを指す。

## 選択肢

| 案 | 起きること |
| --- | --- |
| `activate()` のまま | Apple が勧める書き方だが、常駐アプリでは前面に出ないことがある |
| `activate(ignoringOtherApps: true)` | 公開されている常駐アプリでいちばん多い書き方で、前面に出ると報告されている。将来廃止予定の API を使う |
| 開いている間だけ `.regular` にする | 開いている間 Dock にアイコンが出て、「Dockにアイコンを表示」の設定（`SPEC-MENU-007`）とぶつかる。効かないという報告もある |
| URL スキームを `NSWorkspace` で開く | 譲り渡しを `NSWorkspace` が扱う。ほかのアプリや Web から呼べる入口が増える |
| `.moveToActiveSpace` を付ける | 別の Space に表示中の画面も、いまの Space へ引っ越す。画面のある Space へ移れなくなる |

## 理由

- `activate(ignoringOtherApps: true)` は公開 API の呼び出し1つで済み、Rectangle などの常駐アプリが使っている一般的な書き方である。MacOSX27.2.sdk では廃止の版が決まっておらず、ビルドで警告も出ない。
- Apple が心配しているのは、利用者の作業中にフォーカスを奪うことである。Capsaicin がこれを呼ぶのは、メニューの「設定…」、⌘,、アプリの開き直しといった、利用者が設定画面を求めた直後と、設定画面で Dock の表示を切り替えた直後だけである。
- Space の扱いを標準のままにすると、前面に出られれば、画面のある Space へ移るかどうかは利用者のシステム設定に従う。Mac の標準の動きなので、利用者の期待とずれにくい。閉じた画面を開き直すと、いま見ている Space に出る。
- `.fullScreenAuxiliary` は、フルスクリーンのアプリを見ているときにも、その上に設定画面を出すために足す。公開されている常駐アプリは設定画面に付けていないが、Capsaicin では、フルスクリーンで作業しているときにも設定画面がその場に開くことを優先した。

## 影響

- `SPEC-SET-001` に、前面に出すことと Space の振る舞いを書く。
- 実装は `SettingsWindowController` の前面に出す処理と `collectionBehavior` に限られる。
- 将来の macOS で `activate(ignoringOtherApps:)` が廃止または無効になる代償を引き受ける。呼び出しを `SettingsWindowController` の1か所にまとめ、差し替えやすくする。

## 覆す条件

- `activate(ignoringOtherApps:)` が廃止されてビルドで警告が出る、または呼んでも前面に出なくなった。
- `HYP-SET-003` が外れた。
- Apple が常駐アプリ向けに、利用者の操作に応じて前面に出す公開 API を用意した。
