---
schema: task
id: TASK-111
title: 検証ごとの手順書を SMAppService のヘルパーと agent に合わせ、残る確認のファイルを作る
status: in_review
requirements: []
depends_on: ["TASK-110"]
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-111 検証ごとの手順書を SMAppService のヘルパーと agent に合わせ、残る確認のファイルを作る

## 目的

実機確認の手順書は、`develop` で検証ごとのファイル（`docs/manual/verification/`）に分けられた。分けた時点の手順は、sudoers のヘルパー（`/Library/PrivilegedHelperTools`、`/etc/sudoers.d`、`/Library/LaunchDaemons` の「ヘルパー3ファイル」）と、`~/Library/LaunchAgents` の plist を前提にしている。このブランチでは、ヘルパーはアプリに入れた SMAppService のデーモン、ログイン時の起動とクラッシュ時の再起動は SMAppService の agent と mainApp になった（`DEC-HLP-005`、`DEC-LCY-008`）。手順書をこれに合わせ、まだ確かめていないことのファイルを作る。

書き方の決まりは `docs/manual/verification/README.md` の「手順書を書くときの決まり」にある。必ず従う。特に次の3つ。

- 1つのファイルで完結させ、「上記の」「操作2と同じ」のように別の箇所のコマンドを参照させない。同じコマンドが何度出ても書く。参照してよいのは `prepare.md` と `cleanup.md` だけ。
- 画面の文言、ボタン、ファイルやキーの名前は、記憶や古い文書から写さず、実装（String Catalog の `ja` の値、ソース、`project.yml`、`justfile`）から引く。
- 確かめ終えた検証のファイルは作らない。

参考資料:

- SMAppService 向けに書いた前の一本の手順書（ファイルを分ける前の版）: `git show 702cb18:docs/manual/verification.md`。1節（準備）、2節（起動と agent）、4節（ヘルパー）、9節（片付け）のコマンドと期待を、今の実装と照らしてから使ってよい。写すだけにしない。
- オーナーの実機確認の結果: `docs/meta/evidence/EVID-HLP-006-smappservice-helper-on-device.md`。ここで確かめ終えたこと（ヘルパーの設置と承認、on と off、許可を外したときの表示、起動時の後片付け、削除、更新の後の登録し直し、Finder からの起動の引き渡し）はファイルを作らない。
- 振る舞いの正: `docs/specs/helper.md`、`docs/specs/lifecycle.md`、`docs/specs/settings.md`。

## 範囲

変更してよいもの: `docs/manual/verification/` の下だけ。

触らないもの: ほかの文書とコード。

## やること

1. `README.md`: 用語の「ジョブ」「引き渡し」「ヘルパー3ファイル」、`just status` の説明、「つまずいたときの切り分け」の表、名前を引く場所の表（LaunchAgent の plist のキーの行、ヘルパーのパスの行）、記録の例、ヘルパーと LaunchAgent の手順を置いていないことを書いた段落を、SMAppService の形に直す。agent とデーモンの定義はバンドルの `Contents/Library/LaunchAgents` と `Contents/Library/LaunchDaemons` にあり、`project.yml` のビルドフェーズが作る。登録の状態は、設定画面の「ヘルパー」、システム設定の「一般 > ログイン項目と機能拡張」、`sfltool dumpbtm` の読み取り、`launchctl print` で見る。一覧の表に、下の 5 で作るファイルを足す。
2. `prepare.md`: 開始前の状態の保存と中止の条件を、SMAppService の登録の状態の読み取りに置き換える。v0.1.0 の方式のファイル（ヘルパー3ファイルと `~/Library/LaunchAgents` の plist。Release と Debug の両方の名前）が残っているときは、中止の条件にする（片付けはリポジトリの外の手順書で扱う）。ヘルパーは ad-hoc 署名の `just build` では使えないので、ヘルパーや agent を確かめるときは PR の Debug ビルド（`S-Preview`）を `/Applications` に置くことを書く。
3. `cleanup.md`: 片付けを、設定画面の「ヘルパー」の削除、「ログイン時に起動」のオフ、アプリをゴミ箱に入れてゴミ箱を空にすること（空にしないとシステム設定の項目が消えない。`EVID-LCY-003`）、Debug の設定と再開用の記録の削除に置き換える。`sfltool resetbtm` はほかのアプリの登録も消すので使わないと書く。起動の記録のディレクトリ（`/Library/Application Support/<bundle ID>/`）は残ることを書く。
4. ほかのファイルの古い前提を直す。少なくとも `disablesleep-persistence.md`（Capsaicin のデーモンが登録されていないことの確かめ方）、`menu-sleep-settings.md`、`lid-close-setting.md`、`settings-and-appearance.md`（「修復」、管理者の認証、注意の (i) の文言。今の文言は String Catalog から引く。`TASK-110` で足した行の下の状態の文も期待に入れる）、`manual-and-lid-sleep.md`（ヘルパーの設置の仕方）。`grep` で `sudoers`、`PrivilegedHelperTools`、`LaunchDaemons`、`LaunchAgents`、`修復`、`管理者`、`bootstrap`、`plist` を探し、残すものは理由を報告する。
5. 新しいファイルを作る。
   - `login-and-crash-restart.md`: 「ログイン時に起動」のオンとオフ（mainApp の登録と、ログアウト・ログインの後に起動するか）、クラッシュの後の再起動（`SIGSEGV` を送り、agent が起動し直すか）。ログアウトのときに「再ログイン時にウインドウを再度開く」を外すことを書く。
   - `helper-approval-guidance.md`: `TASK-110` の確認。承認待ちの間に設定でヘルパーが要る値を選んだときのアラート（「キャンセル」と「システム設定を開く」）、承認待ちの行の下の状態の文、許可した後に状態の文が消えること。承認待ちの状態の作り方（システム設定で Capsaicin の項目をオフにする）も書く。
   - `debug-agent-worktree-switch.md`: 複数の worktree の Debug ビルドが1つの agent（同じラベル）を共有するとき、`just start` でジョブがそのチェックアウトの実行ファイルを動かすように切り替わるか。`just status` で確かめる。
6. オーナーが前の手順書で見つけた不備を、残るファイルに当てはまる範囲で直す。
   - plist を Python で読むときは、パイプから `plistlib.load(sys.stdin.buffer)` で読まず、`plistlib.loads(sys.stdin.buffer.read())` で読む（パイプは seek できない）。
   - 抑止中の Apple メニューの確認は、「スリープ」を選べないことを見る手順にする。
   - `pmset -a disablesleep` は成功しても何も出力しないので、直後の `pmset -g` で値を確かめると書く。
   - zsh の組み込みの `log` とぶつからないよう、`/usr/bin/log` と書く。

## 守ること

- `AGENTS.md` を読んでから始める。コマンドを実行しない（読み取りのコマンドも含め、手順書を書くだけにする。`just check` だけは実行する）。
- 日本語は `~/.claude/skills/yomiyasu/SKILL.md` に従って推敲する。「蓋」という語は使わない。
- 本番のコードに触れない。`git commit` と `git push` をしない。

## 完了条件

- 1〜6 を満たす。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just check`
- `/usr/bin/grep -n 'sudoers\|PrivilegedHelperTools\|LaunchDaemons\|LaunchAgents\|修復\|管理者\|bootstrap' docs/manual/verification/*.md` の結果を、残す理由とともに報告する。

## レビュー

Codex が書いた途中で接続が切れたので、PM が引き取って確かめた。README、prepare、cleanup と古い前提のファイルを SMAppService に合わせ、新しく `login-and-crash-restart.md`、`helper-approval-guidance.md`、`debug-agent-worktree-switch.md` を作っている。ラベル、定義の場所、`just` の出力、アラートと状態の文の文言は、`project.yml`、`justfile`、String Catalog と一致する。残る `sudoers` などの語は、v0.1.0 の残りの検出とほかのアプリの root ヘルパーの確認だけである。`just check` は通る。
