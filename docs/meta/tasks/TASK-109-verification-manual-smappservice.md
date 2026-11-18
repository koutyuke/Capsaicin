---
schema: task
id: TASK-109
title: 実機確認の手順書を SMAppService のヘルパーと agent に合わせて書き直す
status: in_review
requirements: []
depends_on: ["TASK-106", "TASK-107", "TASK-108"]
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-109 実機確認の手順書を SMAppService のヘルパーと agent に合わせて書き直す

## 目的

`docs/manual/verification.md` は、sudoers と `/Library/PrivilegedHelperTools` のヘルパー、`/Library/LaunchDaemons` の起動時の後片付け、`~/Library/LaunchAgents` の plist を前提に書かれている。`DEC-HLP-005` と `DEC-LCY-008` で、ヘルパーはアプリに入れた SMAppService のデーモン、ログイン時の起動とクラッシュ時の再起動は SMAppService の agent と mainApp になった。手順書をこれに合わせて書き直す。

振る舞いの正は `docs/specs/helper.md`、`docs/specs/lifecycle.md`、`docs/specs/settings.md` の該当の節である。実装は同じ worktree の作業ツリーにある（`Sources/capsaicin-helper/`、`Packages/CapsaicinKit/Sources/CapsaicinPlatform/Helper/`、`Packages/CapsaicinKit/Sources/CapsaicinPlatform/Lifecycle/LaunchAgent.swift`、`project.yml`、`justfile` の `app` グループ）。実機での仕組みの根拠は `EVID-HLP-004`、`EVID-HLP-005`、`EVID-LCY-003` にある。

## 範囲

変更してよいもの: `docs/manual/verification.md` だけ。

触らないもの: ほかの文書とコード。

## やること

1. 1節（準備と退避）: 退避と事前の確認の対象を、sudoers、`/Library/PrivilegedHelperTools`、`/Library/LaunchDaemons`、`~/Library/LaunchAgents` の plist から、SMAppService の登録の状態（設定画面の「ヘルパー」の状態、システム設定の「ログイン項目と機能拡張」、`sfltool dumpbtm` の Capsaicin の項目の読み取り）に置き換える。v0.1.0 の方式のファイルが残っている Mac は、検証の前に片付けるか別の Mac を選ぶよう書く（片付けの手順は Git の外の手順書で扱うので、ここでは中止の条件として書く）。
2. 2節（起動と agent）: Finder からの起動、ログイン時の起動のオンとオフ、クラッシュ後の再起動、バックグラウンドの項目をオフにしたときの表示を、agent と mainApp の確かめ方に置き換える。`launchctl print gui/$(id -u)/<ラベル>` で見る項目、システム設定で見るもの、ログアウトのときに「再ログイン時にウインドウを再度開く」を外すことを書く。
3. 4節（ヘルパー）: 設置（確認の取り消し、システム設定での許可の前後、承認待ちの間の表示と保留）、`on` と `off`、正規でない相手の拒否（任意。ad-hoc 署名の小さなプログラムは用意しないなら、確かめ方を「デーモンのログで `code signing requirement` を見る」にする）、起動時の後片付け（`log show --last boot`）、削除（外部の `disablesleep` を戻さないこと、戻せないときは削除しないこと）、システム設定で項目をオフにしたときの状態、版を上げたビルドに入れ替えた後の登録し直しに置き換える。「修復」と「部分欠落」の節はなくす。
4. 9節（片付け）: 削除の手順を、設定画面の「ヘルパー」の削除と、ログイン時の起動のオフ、アプリの削除とゴミ箱を空にすることに置き換える（`EVID-LCY-003` のとおり、ゴミ箱に古い版が残るとシステム設定の項目が消えない）。`sfltool resetbtm` は、ほかのアプリの登録も消すので使わないと書く。
5. 署名: ヘルパーは ad-hoc 署名のビルドでは使えない。ヘルパーとログイン時の起動の確認は、PR の Debug ビルド（`S-Preview` のラベル、`DEC-SYS-023`）を `/Applications` に置いて行うと書く。`just build` の手元のビルドで確かめられる範囲（ヘルパーの状態が「このビルドでは使用不可」になること）も書く。
6. zsh の組み込みの `log` とぶつからないよう、`log` は `/usr/bin/log` と書く。`grep` は `/usr/bin/grep` と書く。

## 守ること

- 既存の手順書の書き方（節の構成、「前提」「手順」「期待」「記録」「中止」「復元」の見出し、コマンドの書き方）に合わせる。
- 日本語は `~/.claude/skills/yomiyasu/SKILL.md` に従って推敲する。「蓋」という語は使わない。
- コマンドを実行しない（読み取りのコマンドも含め、手順書を書くだけにする）。
- `git commit` と `git push` をしない。

## 完了条件

- `docs/manual/verification.md` に、sudoers、`PrivilegedHelperTools`、`/Library/LaunchDaemons`、`~/Library/LaunchAgents`、管理者パスワード、修復を前提とした記述が残っていない（v0.1.0 の残りを検出する中止の条件を除く）。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just check`
- `/usr/bin/grep -n 'sudoers\|PrivilegedHelperTools\|LaunchDaemons\|LaunchAgents\|修復\|管理者' docs/manual/verification.md` の結果を、残す理由とともに報告する。

## レビュー

PM がレビューした。1、2、4、9節を SMAppService の確かめ方に書き換え、v0.1.0 の残りは中止の条件にし、`sfltool resetbtm` を使わない理由も書いている。残る `sudoers` などの語は、v0.1.0 の残りの検出とバンドルの中の定義の読み取りだけである。PM が1点を直した。4.8（更新の後の登録し直し）は版番号の違う PR Debug ビルドを2つ要るのに、PR Debug ビルドはどれも同じ版番号だったので、`just dist-debug` でビルドした UTC の時刻を `CFBundleVersion` に付け、手順書にそれを書いた。
