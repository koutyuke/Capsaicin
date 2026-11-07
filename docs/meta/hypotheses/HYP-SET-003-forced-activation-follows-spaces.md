---
schema: hypothesis
id: HYP-SET-003
title: 強制の有効化で設定画面が前面に出て、画面のある Space へ移る
status: open
affects: ["SPEC-SET-001", "DEC-SET-003"]
evidence: []
---

# HYP-SET-003 強制の有効化で設定画面が前面に出て、画面のある Space へ移る

## 主張

macOS 27 で、Dock の表示がオンでもオフでも、`NSApp.activate(ignoringOtherApps: true)` の後に設定画面を `makeKeyAndOrderFront` すると、次のようになる。

1. ほかのアプリが前面にあっても、設定画面が前面のキーウインドウになる。
2. 設定画面が別の Space に表示されていれば、システム設定の「アプリケーションの切り替えで、アプリケーションのウインドウが開いているスペースに移動」がオンのとき、その Space へ移る。
3. 設定画面を閉じていれば、いま見ている Space に開く。`collectionBehavior` に `.fullScreenAuxiliary` があれば、フルスクリーンのアプリの Space でもその上に開く。

## 外れたときに起きること

1 が外れたら、`DEC-SET-003` の有効化の方法を見直す（`EVID-SET-001` の、開いている間だけ `.regular` にする方法か、`NSWorkspace` 経由の有効化）。2 か 3 が外れたら、`SPEC-SET-001` の Space の振る舞いを、実際に作れるものへ直すか、`collectionBehavior` を開く場面ごとに切り替える。

## 確かめ方

`docs/manual/verification.md` の 8.4 で、オーナーが実機で確かめる。Dock の表示のオンとオフのそれぞれで、ステータスアイコンのメニュー、⌘,（Dock の表示がオンのとき）、Finder からの開き直しから開く。前面のアプリ、Space、フルスクリーンの組み合わせを変える。永続的なシステム変更は伴わない。

## 結果

未確認。
