---
schema: task
id: TASK-108
title: ログイン時の起動とクラッシュ時の再起動を SMAppService の agent と mainApp に移す
status: in_review
requirements: ["REQ-LCY-001", "REQ-LCY-003"]
depends_on: []
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-108 ログイン時の起動とクラッシュ時の再起動を SMAppService の agent と mainApp に移す

## 目的

`DEC-LCY-008` のとおり、`~/Library/LaunchAgents` に plist を書いて `launchctl bootstrap` する方式をやめ、アプリのバンドルに入れた定義を `SMAppService.agent` で登録する。「ログイン時に起動する」は `SMAppService.mainApp` の登録で切り替える。振る舞い（launchd の管理下で動く、クラッシュで起動し直す、直接起動したアプリは agent に引き渡して終わる）は変えない。

振る舞いの正は `docs/specs/lifecycle.md` の `SPEC-LCY-001`、`SPEC-LCY-003`、launchd の管理下で動く仕様、`SPEC-LCY-006` と、登録し直しの規則 `docs/specs/helper.md` の `SPEC-HLP-007` である。根拠は `EVID-LCY-003` にある。試作の `/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-smappservice-probe/Prototypes/SMAppServiceProbe/App/ProbeApp.swift` と `Plists/` も参考にしてよい（写さない）。

## 範囲

変更してよいもの: `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Lifecycle/LaunchAgent.swift` と、そのテスト、`Sources/Capsaicin/App/`、`project.yml`（バンドルに agent の定義を入れる部分）、`justfile` の `app` グループのレシピ、`Tests/CapsaicinTests/CapsaicinTests.swift` のバンドルの検査、必要なら `HelperRegistration.swift`（登録し直しの規則を agent と共有するときだけ）。

触らないもの: `docs/`（このチケットを除く）、`Sources/capsaicin-helper/`、設定画面の見た目と文言（「一般」の再起動の表示は今の文言のまま使う）。

## やること

1. agent の定義 `Contents/Library/LaunchAgents/<アプリの bundle ID>.plist` を、デーモンの定義を作るビルドフェーズと同じ仕組みで作る。キーは `Label`（アプリの bundle ID。今のラベルと同じ）、`BundleProgram`（`Contents/MacOS/Capsaicin`）、`RunAtLoad=false`、`KeepAlive={Crashed=true}`、`ProcessType=Interactive`、`LimitLoadToSessionType=Aqua`。
2. `LaunchAgent` を `SMAppService.agent` の登録に置き換える。直接起動したときは、登録してから `launchctl kickstart gui/<uid>/<ラベル>` で引き渡す。引き渡せたかは `kickstart` の成否で決める（`EVID-LCY-002`）。launchd から起動されたかの判定（`XPC_SERVICE_NAME`）は今のまま。クラッシュ時の再起動の状態は agent の `status` で決める（`requiresApproval` なら無効）。
3. 「ログイン時に起動する」を `SMAppService.mainApp` の register と unregister にする。`~/Library/LaunchAgents` に書かない。設定の保存値と mainApp の登録がずれていたら、起動時に保存値に合わせる。
4. agent の登録し直しを、`SPEC-HLP-007` と同じ規則（前回登録した版と違うときだけ、unregister の完了を待ってから register、`EPERM` なら 3 秒待って最大 3 回）で行う。ヘルパーの実装と共有できるなら共有し、版の記録は agent とデーモンで分ける。
5. `justfile` の `app` グループの `status` と `start` を、`~/Library/LaunchAgents` の plist を前提にしない形に直す。`status` はジョブが動かす実行ファイルを `launchctl print` から読み、このチェックアウトのものかを示す。`start` は今と同じく、ジョブを外してからこのチェックアウトのアプリを開き、ジョブがこのチェックアウトの実行ファイルを動かしたかを確かめる。SMAppService の登録をレシピから直接触らない。レシピの出力は英語で書く。

## 守ること

- `AGENTS.md` を読んでから始める。アプリを起動しない。`sudo`、`launchctl`、`sfltool` を実行しない（レシピを書き換えるだけで、実行しない）。
- `~/Library/LaunchAgents` を読み書きするコードを残さない。v0.1.0 の利用者の古い plist は、アプリで片付けない（Git の外の手順書で扱う）。
- 本番のコードに `REQ-*` と `SPEC-*` を書かない。
- `git commit` と `git push` をしない。

## 完了条件

- 1〜5 を満たし、登録と引き渡し、mainApp の切り替え、登録し直しの分岐をテストで確かめている。
- バンドルの検査で、agent の定義の場所とキーを確かめる。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build` の後、`plutil -p` で agent の定義を見る。
- 実機（オーナー）: PR の Debug ビルドで、Finder からの起動、`SIGSEGV` での再起動、「ログイン時に起動する」のオンとオフ、システム設定でバックグラウンドの項目をオフにしたときの表示を確かめる。

## レビュー

PM がレビューした。直接起動したアプリは agent を登録してから `kickstart` で引き渡し、版が変わったときだけ登録し直す（agent の unregister は agent から起動したアプリも終了させるので、直接起動した個体だけが行う。Sparkle の再起動は直接起動なので、更新の後はここで登録し直される）。「ログイン時に起動する」は起動時に mainApp の登録を保存値に合わせる。承認待ちならアプリをそのまま動かす。`justfile` の `status` と `start` は `~/Library/LaunchAgents` を読まない。指摘なし。`just check` は通る（パッケージ 331、アプリ 172）。

実機で確かめること: 複数の worktree の Debug ビルドが1つの agent を共有するとき、`just start`（ジョブを外してから開く）で、登録がそのチェックアウトのバンドルに切り替わるか。
