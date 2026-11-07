---
schema: task
id: TASK-032
title: HUD の動きを Xcode の Canvas で再生できるようにする
status: done
requirements: []
depends_on: []
assignee: Claude（PM）
---

# TASK-032 HUD の動きを Xcode の Canvas で再生できるようにする

## 目的

オーナーが、Web の Storybook のように HUD のアニメーションを手軽に確かめたいと求めた。これまでは、HUD の動きを見るのにアプリを起動してスリープ防止を切り替える必要があった。

Debug ビルドにだけ `#Preview` を置き、パネルを出さずに、出現・表示中の置き換え・退場・消えた後の出し直しを Canvas で再生できるようにする。

## 範囲

書いてよい:

- `Sources/Capsaicin/HUD/HUDPreview.swift`（新規）
- `Sources/Capsaicin/App/AppDelegate.swift`（Preview で起動されたときに起動処理を始めない）

仕様と String Catalog は変えない。

## 完了条件

- `#if DEBUG` の中だけに置き、Release ビルドには含まれない。
- Preview を表示しても、アプリの起動処理（LaunchAgent の plist の書き込み、`launchctl` の実行、メニューバー項目の作成）が動かない。
- `MenuHUDRouting.shouldPresent` が HUD を出すイベントについて、`HUDContent.make` の分岐をすべてボタンとして並べる（開始3、開始できない4、解除7）。
- ボタンを押すと、`HUDPresenter.show` と同じ順と時間で `phase` が進む。
- 内容は `HUDContent.make` で作り、String Catalog に新しいキーを増やさない。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- Xcode で `HUDPreview.swift` を開き、Canvas の Live で各ボタンを押して動きを確かめる（オーナー）。

## レビュー

PM が実装した。

最初の版では、Preview が落ちるとオーナーから報告があった。Xcode の Preview はアプリ本体を起動するため、`AppDelegate` の起動処理がそのまま動いていた。この処理は LaunchAgent への引き渡しで自分を終了するので、Preview はそれを異常終了と表示していた。その途中で、`~/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist` の起動先が DerivedData の実行ファイルに書き換わり、`launchctl bootstrap` と `kickstart` も実行されていた。

そこで `AppDelegate` は、`XCODE_RUNNING_FOR_PREVIEWS` か `XCODE_RUNNING_FOR_PLAYGROUNDS` が `1` なら何も始めないようにした。報告にあった Preview の起動環境（JIT の実行）には後者だけが付いていた。書き換わった plist は、オーナーが `.build/xcode` のアプリを起動し直すと、起動処理が自分の実行ファイルで書き直す。

パネルの位置や window level、画面の選び方は `HUDPresenter` の役割なので、Preview では再現しない。表示時間は `HUDPresenter.show` と二重に持つため、あちらを変えたときはこちらも合わせる。
