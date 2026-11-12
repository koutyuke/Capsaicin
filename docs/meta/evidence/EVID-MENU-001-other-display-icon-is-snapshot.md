---
schema: evidence
id: EVID-MENU-001
title: ほかのディスプレイのメニューバーのアイコンは AppKit が描いた画像の複製で、NSImageView の置き換えの動きでは前の状態の画像のまま残る
observed_on: 2026-11-12
environment: macOS 27.2.1（26B131）、Mac16,8、Xcode 27.2 の MacOSX27.2.sdk、ディスプレイ1枚（実験）。不具合はオーナーが2枚のディスプレイで観測した
sources: ["/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSImageView.h", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSStatusItem.h"]
---

# EVID-MENU-001 ほかのディスプレイのメニューバーのアイコンは AppKit が描いた画像の複製で、NSImageView の置き換えの動きでは前の状態の画像のまま残る

## 確かめた事実

### オーナーの観測

ディスプレイを2枚つなぎ、メニューバーのアイコンのメニューで抑止を切り替えると、フォーカスのあるディスプレイのアイコンは切り替わるが、もう一方のディスプレイのアイコンは前の状態のまま残った。このときの実装は、ボタンに重ねた `NSImageView` に `setSymbolImage(_:contentTransition: .replace)` で画像を渡していた（`TASK-048`）。

### AppKit の仕組み

- `NSStatusItem` は、複製用の非公開のメソッド（`_updateReplicants`、`_redrawReplicantSnapshot:sourceView:`、`_moveToScreenContainingActiveMenuBar` など）と、`_replicants` を持つ。本物のボタンはアクティブなメニューバーのあるディスプレイにだけ置かれる。ほかのメニューバーには `NSStatusItemReplicantView` が置かれ、AppKit が本物のボタンを描いた画像を `setSnapshotImage:needsInactiveTemplateStyling:appearance:needsShadow:supportsVibrancy:` で受け取る。
- 複製用の画像は、`NSView` の `displayRectIgnoringOpacity(_:in:)` から `CALayer` の `render(in:)` を通して描かれる。
- 公開 API には、ディスプレイごとのアイコンを扱うものがない（`NSStatusItem.h`）。`NSImageView` の置き換えの動きには、終わりを知らせる API がない（`NSImageView.h`）。

### 複製に渡る画像

同じ構成のステータス項目で切り替え、複製に渡った画像の不透明な画素を数えた。シンボルは `lightbulb` と `lightbulb.fill`（15 pt、Regular、テンプレート画像）で、輪郭の版は約195、塗りつぶしの版は439である。

| 切り替え方 | 複製に渡った画像 |
| --- | --- |
| `NSImageView.setSymbolImage(_:contentTransition: .replace)` | 切り替えの直後に1回だけ渡り、前の状態の画像（194）だった。その後1.5秒待っても渡らなかった |
| 上の後、0.1〜0.3秒で `button.needsDisplay = true` | 動きの途中の画像（364、61、90） |
| 上の後、0.5秒以上で `button.needsDisplay = true` | 新しい画像 |
| `NSImageView.image` への代入 | 新しい画像 |
| `NSStatusBarButton.image` への代入 | 新しい画像（196、439） |

置き換えを `CATransaction` で囲んでも、完了の処理は0.002秒で呼ばれ、動きの終わりを知る手段にならなかった。

## 確かめ方

1. Objective-C ランタイムで `NSStatusItem`、`NSStatusBarWindow`、`NSStatusItemReplicantView` のメソッドと変数を列挙した。
2. 使い捨てのプロセスでステータス項目を作り、`TASK-048` と同じ手順でボタンに `NSImageView` を重ねた。`NSStatusItemReplicantView` の `setSnapshotImage:…` を差し替えて、渡る画像を受け取った。
3. 表の切り替え方ごとに1〜1.5秒待ち、受け取った画像の不透明な画素を数えた。
4. `NSImageView` の `draw(_:)` で呼び出し履歴を出し、複製用の画像を描く経路を確かめた。

## 適用範囲

`NSStatusItem` のボタンの画像を替えるときに、ほかのディスプレイのメニューバーにどの画像が出るかの判断に使う。複製の仕組みは非公開で、macOS のバージョンで変わりうる。

## 未確認のこと

- 実験はディスプレイ1枚で行った。ディスプレイが1枚でも複製は8つあり、表の結果はそれらに渡った画像である。2枚のディスプレイで `button.image` に入れたときに、もう一方のメニューバーの見た目が切り替わることは、実機では見ていない。
- 複製がいつ作られ、どのメニューバーに対応するかは調べていない。
