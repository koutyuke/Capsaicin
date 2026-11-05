---
schema: hypothesis
id: HYP-UI-002
title: macOS 26 以降だけを対象にするなら、Icon Composer のファイルだけでアプリアイコンがそろう
status: open
affects: ["REQ-UI-004", "SPEC-UI-009"]
evidence: []
---

# HYP-UI-002 macOS 26 以降だけを対象にするなら、Icon Composer のファイルだけでアプリアイコンがそろう

## 主張

最小対応 OS を macOS 26 にしたアプリでは、Icon Composer のファイル（拡張子 `.icon`）をプロジェクトに入れるだけで、Finder、Dock、設定画面などで使うすべての大きさのアプリアイコンが表示され、従来の `.icns` の大きさの一式を別に用意する必要がない。

Apple の「Creating your app icon using Icon Composer」は、Xcode が Icon Composer のファイルを既存の AppIcon の asset catalog の代わりに使い、以前のリリース向けの画像をビルド時に生成するとしている（https://developer.apple.com/tutorials/data/documentation/xcode/creating-your-app-icon-using-icon-composer.json 、2026-11-06 に確認）。ファイルの拡張子は、この文書には書かれていない。

## 外れたときに起きること

アイコンの書き出しの手順に、従来の大きさの一式が加わる。`SPEC-UI-009` の形式と組み込みの条件が変わる。

## 確かめ方

1. 環境: 対応環境の Mac と、最小対応 OS を macOS 26 にした試作のプロジェクト。
2. Icon Composer のファイルだけを入れてビルドし、ファイルの拡張子と、`.app` の中のアイコンの資源を確かめる。Finder、Dock、Spotlight、設定画面の「このアプリについて」でアイコンを見る。
3. 成功: 拡張子が `.icon` で、どの場所でもアイコンが表示される。失敗: どれかが欠ける、または拡張子が違う。

永続的なシステム変更は伴わない。

## 結果

未確認。
