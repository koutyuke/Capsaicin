---
schema: decision
id: DEC-SYS-005
title: XcodeGen でプロジェクトを生成し、ロジックはローカルの SwiftPM パッケージに置く
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-SYS-005"]
based_on: []
---

# DEC-SYS-005 XcodeGen でプロジェクトを生成し、ロジックはローカルの SwiftPM パッケージに置く

## 結論

XcodeGen の `project.yml` から `.xcodeproj` を生成し、`xcodebuild` でビルドする。生成した `.xcodeproj` はコミットしない。ロジックはローカルの SwiftPM パッケージ `Packages/CapsaicinKit` に置き、`swift test` で速くテストする。

## 背景

アプリは String Catalog、asset catalog、埋め込む実行ファイル（CLI とヘルパー）、署名を持つ `.app` である。複数のエージェントが並行して作業する。

## 選択肢

- 手で管理する `.xcodeproj`。`.pbxproj` が競合しやすく、並行作業に向かない（不採用）。
- Tuist。個人で作る v1 には重い（不採用）。
- SwiftPM だけと組み立てのスクリプト。String Catalog と asset catalog のコンパイル、埋め込み、署名を自前で管理することになり、壊れやすい（不採用）。
- XcodeGen とローカルの SwiftPM パッケージ（採用）。

## 理由

プロジェクトの定義をテキストで持てるので並行作業で競合しにくく、`.app` の組み立ては Xcode に任せられるため。ロジックを SwiftPM に置けば、アプリを組み立てずにテストできるため。

## 影響

- ビルドの前に `.xcodeproj` の生成が要る。手順は `AGENTS.md` にある。
- XcodeGen のバージョンは開発環境（`DEC-SYS-006`）で固定する。

## 覆す条件

- SwiftPM が `.app` の生成と String Catalog・asset catalog に正式に対応したら見直す。
- XcodeGen が Xcode の新しいプロジェクト形式に追従しなくなったら見直す。
