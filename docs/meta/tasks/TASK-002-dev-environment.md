---
schema: task
id: TASK-002
title: 開発環境とプロジェクトの骨組みを作る
status: done
requirements: []
depends_on: []
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-002 開発環境とプロジェクトの骨組みを作る

## 目的

すべてのエージェントが、Xcode の GUI を使わず、永続的なシステム変更もせずに、コマンドラインから整形・lint・ビルド・テストを実行できる状態にする。アプリの機能はまだ作らない。

## 決まっていること

技術構成はアドバイザー2名の独立した意見から PM が決めた。判断記録（`DEC-*`）は要件の移行（TASK-001）が終わった後に PM が書く。

- ビルド: XcodeGen の `project.yml` から `.xcodeproj` を生成し、`xcodebuild` で `.app` を作る。生成した `.xcodeproj` はコミットしない。DerivedData と SwiftPM の作業領域はリポジトリ内（`.build/`）に置き、worktree ごとに分かれるようにする。SDK は `-sdk macosx` で明示する。
- ロジック: ローカル SwiftPM パッケージ `Packages/CapsaicinKit` に置き、`swift test` で単体テストする。
- 対象: macOS 26 以上、arm64 のみ。開発言語は日本語（`ja`）。署名は ad-hoc を既定にする。
- 識別子: bundle ID は `io.github.koutyuke.capsaicin`。Debug ビルドは `io.github.koutyuke.capsaicin.debug` にし、本番の設定やソケット、launchd のラベルと衝突させない。
- 開発ツールは Nix の flake で供給する。Xcode は外部の前提とし、`/usr/bin/xcrun` と `/usr/bin/xcodebuild` を使う。devShell は `mkShellNoCC` にし、`DEVELOPER_DIR`、`SDKROOT` など Xcode を壊す環境変数を持ち込まない。
- 整形と lint:
  - Swift: SwiftFormat（nicklockwood）で整形、SwiftLint で lint。SwiftLint は整形と重なる規則を無効にする。
  - C: clang-format。
  - Markdown と YAML: Prettier（Markdown は `proseWrap: preserve`）、Markdown の lint は markdownlint-cli2。
  - TOML: Taplo。シェル: shfmt と ShellCheck。Nix: nixfmt、statix、deadnix。
  - 整形の入口は treefmt（treefmt-nix）にまとめ、`nix fmt` でも動くようにする。
- タスクランナーは just、Git フックは lefthook。pre-commit は検査だけにして、自動整形や自動ステージはしない。テストはフックに入れない。
- 文書の検査は Python 3 の標準ライブラリと PyYAML で書く（`docs/documentation-management.md` の「検査」）。

## 範囲

作るもの:

- `flake.nix`、`flake.lock`、`.envrc`（`use flake`）
- `justfile`。少なくとも `gen`、`build`、`test`、`fmt`、`lint`、`check`（`fmt` の検査、`lint`、`test` をまとめたもの）のレシピを置く
- `lefthook.yml`
- 各ツールの設定ファイル（`.swiftformat`、`.swiftlint.yml`、`.clang-format`、Prettier、markdownlint-cli2、Taplo、treefmt）
- `project.yml` と、次のターゲットの最小の雛形:
  - `Capsaicin`（アプリ。`LSUIElement`。起動しても何もしないメニューバーアイコンだけ）
  - `capsaicin`（CLI。`Contents/Helpers/capsaicin` に埋め込む。`Contents/MacOS/Capsaicin` と大文字小文字だけ違う名前になり、大文字小文字を区別しない APFS で衝突するため）
  - `capsaicin-helper`（C の実行ファイル。中身は `TASK` で別途実装するので、引数を拒否して終了するだけの雛形）
  - アプリのテストターゲット
- `Packages/CapsaicinKit` と、次のモジュールの空の雛形と、パイプラインが動くことを示すテスト各1件:
  - `CapsaicinCore`（副作用のない規則）
  - `CapsaicinIPC`（CLI とアプリの間の通信）
  - `CapsaicinPlatform`（macOS の API を呼ぶ部分）
- `scripts/check_docs.py` とそのテスト
- `.gitignore` の追記（`.build/`、生成した `.xcodeproj`、`.direnv/` など）
- ルートの `AGENTS.md`（`CLAUDE.md` はその symlink）。PM が書く節を除き、開発環境と検証の節を書く

触らないもの: `docs/` の配下（文書の検査が今の文書で落ちても、文書は直さず報告する）、`.t3-code/`

## 完了条件

- `nix develop --command just check` が、クリーンな clone で成功する。
- `nix develop --command just build` が `.build/` の下に `Capsaicin.app` を作り、その中に `Contents/Helpers/capsaicin` と helper が入っている。
- `nix fmt` と `just fmt` が同じ整形をする。
- どのコマンドも `sudo`、`pmset` の設定変更、`launchctl` を呼ばず、LaunchAgent・LaunchDaemon・sudoers・`/Library/PrivilegedHelperTools` に書き込まない。Xcode が行うビルドしたアプリの LaunchServices への登録と、各ツールの通常のキャッシュは許容する。
- 追加したすべての依存（Nix のパッケージ）の用途を `AGENTS.md` か設定ファイルのコメントで説明している。

## 検証

- `nix develop --command just check`
- `nix develop --command just build` の後、`find .build -name Capsaicin.app` と bundle の中身を確認する
- 文書の検査のテスト

## レビュー

1回目（Claude Opus 5.5）: 修正すれば承認。
- blocker: `fmt-check` が Swift を検査していなかった（一時コピーが `.build/` にあり、`.swiftformat` の除外で全件が飛ばされた）。SwiftFormat が `~/Library/Caches` にキャッシュを書いていた。
- major: `sandbox-exec` で LaunchServices への登録を防ぐ前提が成り立っておらず、そのために SwiftPM の manifest とマクロの sandbox を外していた。PM の判断で、Xcode の通常の登録とツールのキャッシュは許容し、自作の sandbox を撤去して SwiftPM の sandbox を戻す。完了条件をこれに合わせて改めた。
- minor 以下: フックが devShell の外で素通りする、hardened runtime の設定が効いていない、文書の検査が置き場所と領域の対応を見ていない、除外の設定が分散している、`__pycache__` が `.build/` の外にできる、justfile の重複、Python と justfile に整形と lint がない。
- 対応: 実装したエージェントに差し戻した。

2回目（PM）: 指摘をすべて反映したことを確かめた。`just fmt-check`、`just lint-code`、`just test`（スクリプト33件、パッケージ3件、アプリ3件）、`just build` が成功。承認。
