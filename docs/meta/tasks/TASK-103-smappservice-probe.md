---
schema: task
id: TASK-103
title: SMAppService の前提を実機で確かめるための試作アプリを作る
status: todo
requirements: []
depends_on: []
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-103 SMAppService の前提を実機で確かめるための試作アプリを作る

## 目的

`DEC-HLP-004` の構成に入る前に、オーナーが実機で `HYP-HLP-005`、`HYP-HLP-006`、`HYP-HLP-007`、`HYP-LCY-006`、`HYP-LCY-007` を確かめられるよう、使い捨ての試作アプリと、ビルドの手順を作る。試作は製品のコードに入れず、ブランチ `spike/smappservice-probe` だけに置き、`develop` にはマージしない。

## 範囲

変更してよいもの: worktree `capsaicin-smappservice-probe` の `Prototypes/SMAppServiceProbe/` だけ。

触らないもの: 製品のコード（`Sources/`、`Packages/`）、`project.yml`、`justfile`、`docs/`、CI。

## 作るもの

- `Prototypes/SMAppServiceProbe/project.yml`（XcodeGen）と、そこから作るアプリ `CapsaicinProbe.app`。bundle ID は `io.github.koutyuke.capsaicin.probe`、macOS 26 以上、arm64。
- バンドルの中身:
  - デーモン: C の実行ファイル。plist は `Contents/Library/LaunchDaemons/` に置き、`BundleProgram` で指す。`MachServices` を1つ持ち、`RunAtLoad=true`、KeepAlive なし。
  - agent: アプリ自身の実行ファイルを指す plist を `Contents/Library/LaunchAgents/` に置く。`RunAtLoad=false`、`KeepAlive={Crashed=true}`。
- デーモンの振る舞い:
  - 接続ごとに `xpc_connection_set_peer_team_identity_requirement` で、同じ Team ID とアプリの署名識別子を要求する。
  - 要求に、自分の版（ビルドで埋め込む）、euid、pid、`kern.bootsessionuuid`、起動した時刻、この起動で「起動時の後片付け」を行ったかを返す。
  - 「起動時の後片付け」は、`pmset` を実行せず、記録だけにする。`kern.bootsessionuuid` を `/Library/Application Support/CapsaicinProbe/` のファイルに書き、前回と同じ値なら行わない。
  - 接続がなくなって一定時間（30 秒程度）経ったら終了する。
- アプリの画面: 1つのウインドウに、次の操作のボタンと、結果を追記する記録の欄を置く。
  - daemon、agent、mainApp のそれぞれの register、unregister（完了ハンドラーの版）、status の表示
  - デーモンの登録し直し（unregister の完了を待ってから register。EPERM なら数秒待って試し直す）
  - デーモンへの問い合わせ（アプリの側でも、同じ方法でデーモンを確かめる）
  - `launchctl kickstart gui/<uid>/<agent のラベル>` の実行
  - クラッシュ（`SIGSEGV` で終了する）
  - システム設定の「ログイン項目と機能拡張」を開く
  - 自分の版、自分が launchd から起動されたか、自分のバンドルのパスの表示
- 外部の相手として、ad-hoc 署名の小さな CLI（デーモンに接続して結果を表示するだけ）を作る。`HYP-HLP-005` の主張3で、拒まれることを確かめるのに使う。
- ビルドの手順をまとめたスクリプト `Prototypes/SMAppServiceProbe/build.sh`。引数で、版の番号と署名の種類（`development`、`developer-id`、`adhoc`）を選ぶ。署名の名前は環境変数で受け取り、Team ID や証明書の名前をスクリプトに書かない。Hardened Runtime と secure timestamp を付ける。`developer-id` では、オーナーが用意した `notarytool` のキーチェーンのプロファイル名を環境変数で受け取り、公証と staple まで行えるようにする。出力は `Prototypes/SMAppServiceProbe/.build/` 以下に、版ごとに分けて置く。
- `Prototypes/SMAppServiceProbe/README.md`: 構成と、ビルドの手順だけを書く。実機での確認の手順書は PM が書く。

## 守ること

- 試作のデーモンは `pmset` を含め、システムの設定を変えない。書くのは上のファイル1つだけにする。
- 試作は確かめるための道具なので、エラー処理や画面の作り込みは、結果を読めるのに要る範囲にとどめる。目安は、Swift と C を合わせて 400 行以内。
- 本番の規約（String Catalog、ローカライズ）は適用しない。文言は英語だけでよい。
- アプリを起動しない。`sudo`、`launchctl`、`sfltool` を実行しない。デーモンや agent を登録しない。
- 証明書での署名は、キーチェーンの承認の画面が出る可能性があるので、エージェントは行わない。エージェントが確かめるのは、`adhoc` でのビルドと、`codesign -dv` と `plutil -lint` による中身の検査までにする。
- `git commit` と `git push` をしない。

## 完了条件

- `build.sh <版> adhoc` で、アプリと CLI がビルドでき、バンドルに2つの plist とデーモンが入っている。
- `plutil -lint` が plist に通り、`BundleProgram`、`MachServices`、`KeepAlive` の値が上のとおりである。
- 署名の種類ごとに、オーナーが実行するコマンドが README に書いてある。

## 検証

- `Prototypes/SMAppServiceProbe/build.sh 1 adhoc` と `build.sh 2 adhoc`
- `codesign -dv --verbose=2` とバンドルの中身の一覧
- 実機での確認は、オーナーが PM の手順書で行う。

## レビュー

未レビュー。
