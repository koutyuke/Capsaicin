---
schema: decision
id: DEC-SYS-006
title: 開発ツールは Nix flake の devShell で供給する
status: accepted
supersedes: []
superseded_by: []
requirements: []
based_on: []
---

# DEC-SYS-006 開発ツールは Nix flake の devShell で供給する

## 結論

- 開発ツールは Nix flake の devShell（`mkShellNoCC`）で供給する。Xcode は外部の前提とし、Xcode を壊す環境変数を持ち込まない。
- 整形と検査のツールは次のとおりにする。入口は treefmt にする。

| 対象 | ツール |
| --- | --- |
| Swift | SwiftFormat（整形）、SwiftLint（lint） |
| C | clang-format |
| Markdown、YAML | Prettier、markdownlint-cli2 |
| TOML | Taplo |
| シェル | shfmt、ShellCheck |
| Nix | nixfmt、statix、deadnix |

- タスクは just、Git フックは lefthook（検査だけ）で動かす。文書の検査は Python で書く。

## 背景

複数のエージェントと人が同じ手順で整形と検査を行い、同じ結果を得る必要がある。

## 選択肢

- Xcode 付属の swift-format。ツールを Nix で管理する方針に合わない（不採用）。
- dprint。プラグインを実行時に取得するので、Nix の再現性と合わない（不採用）。
- make（不採用）。
- Nix flake の devShell と上のツール（採用）。

## 理由

ツールの版を flake で固定し、誰がどこで実行しても同じ結果にするため。

## 影響

- 実際に採用したツールと版は TASK-002 の結果に合わせる。正確な版は `flake.lock` にあり、この判断には書かない。
- Nix が使えない環境では、開発ツールをそろえられない。

## 覆す条件

- Nix の devShell では Xcode のビルドと両立できないと分かったら見直す。
- 採用したツールが保守されなくなったら、そのツールを見直す。
