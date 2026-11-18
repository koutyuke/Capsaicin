---
schema: task
id: TASK-106
title: ヘルパーを SMAppService のデーモンと XPC に作り直し、登録と状態を扱う部品を作る
status: in_review
requirements: ["REQ-HLP-001", "REQ-HLP-002", "REQ-HLP-004", "REQ-HLP-005", "REQ-HLP-006"]
depends_on: []
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-106 ヘルパーを SMAppService のデーモンと XPC に作り直し、登録と状態を扱う部品を作る

## 目的

`DEC-HLP-005` のとおり、sudoers と `/Library/PrivilegedHelperTools` のヘルパーをやめ、アプリのバンドルに入れた `SMAppService.daemon` のデーモンと XPC に作り直す。このチケットでは、デーモン、アプリの側の XPC の呼び出し、登録と状態を扱う部品までを作る。設定画面の作り直しと、起動時の登録し直しの組み込みは 後続のチケットで行う。

振る舞いの正は `docs/specs/helper.md`（`SPEC-HLP-002`、`SPEC-HLP-003`、`SPEC-HLP-005`、`SPEC-HLP-007`、「状態」の節）である。根拠は `EVID-HLP-004` と `EVID-HLP-005` にある。

参考にする試作（製品のコードではない。写さずに、確かめた仕組みだけを使う）:

- `/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-smappservice-probe/Prototypes/SMAppServiceProbe/Daemon/main.c`
- `/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-smappservice-probe/Prototypes/SMAppServiceProbe/Shared/Client.c`
- `/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-smappservice-probe/Prototypes/SMAppServiceProbe/App/ProbeApp.swift`

## 範囲

変更してよいもの:

- `Sources/capsaicin-helper/`（デーモンに作り直す）
- `project.yml`（ヘルパーのターゲットの設定、launchd の定義をバンドルに入れる仕組み）
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Helper/` と、対応するテスト
- `Packages/CapsaicinKit/Sources/CapsaicinCore/Controller/Ports.swift` の `HelperSleepControlling` と、その呼び出し元と偽物（`CapsaicinCoreTesting`）。名前を「使えるか」に合わせて変えるなら、呼び出し元をすべて直す
- `Sources/Capsaicin/App/AppComposition.swift` と、後続のチケットまで動く状態を保つための最小限の `Sources/Capsaicin/Settings/` の変更
- `Tests/CapsaicinTests/CapsaicinTests.swift` のバンドルの検査
- `.github/workflows/sign-and-notarize.yml`（バンドルの中身が変わって署名の手順を直す必要があるときだけ）

触らないもの: `docs/`（このチケットを除く）、`AGENTS.md`、`justfile`、LaunchAgent とライフサイクル（後続のチケット）、設定画面の見た目と文言の作り直し（後続のチケット）。

## 作るもの

### デーモン（C）

- launchd の Mach サービスのリスナーとして要求を受ける。ラベルと Mach サービス名は `<アプリの bundle ID>.helper` にする（Debug は `io.github.koutyuke.capsaicin.debug.helper`、Release は `io.github.koutyuke.capsaicin.helper`）。
- 接続ごとに `xpc_connection_set_peer_team_identity_requirement` で、同じ Team ID とアプリの署名識別子（アプリの bundle ID）を求める。関数の引数の意味は SDK のヘッダー（`xpc/connection.h`）で確かめる。期待するアプリの bundle ID とサービス名は、構成ごとにビルドで決め（例: ヘルパーのターゲットの `GCC_PREPROCESSOR_DEFINITIONS` を Debug と Release で分ける）、引数、環境変数、ファイルからは受け取らない。
- 要求は `SPEC-HLP-002` のとおり、`command` が `on` か `off` の辞書だけを受け付ける。ほかのキーや型の違いは失敗を返す。`pmset` は `posix_spawn` などで、空の環境、固定の引数で実行し、終了を待って、終了コードが 0 かどうかだけを返す。シェルと PATH の探索を使わない。
- 要求は届いた順に1つずつ処理する（1本の直列のキュー）。
- 使われていなければ、一定時間（30 秒程度）で終了する。
- 起動時の後片付けは `SPEC-HLP-003` の表のとおり（記録がなければ書くだけ、違えば `off` してから書く、同じなら何もしない）。記録は `/Library/Application Support/<アプリの bundle ID>/` の下に、root だけが書ける権限で、置き換えで書く。
- 非公開の API は使わない。

### launchd の定義

- `Contents/Library/LaunchDaemons/<ラベル>.plist` をバンドルに入れる。キーは `Label`、`BundleProgram`（`Contents/Helpers/capsaicin-helper`）、`MachServices`（自分のサービス名だけ）、`RunAtLoad=true`。KeepAlive と `UserName` は持たない。
- 構成によってラベルが変わるので、ビルドの中で bundle ID から作る（XcodeGen のビルドフェーズのスクリプトなど）。アプリの署名の前に置かれ、署名に含まれるようにする。作ったものを `plutil -lint` で確かめる。

### アプリの側（`CapsaicinPlatform`）

- `HelperSleepController` の `turnOn` と `turnOff` を、sudo の実行から XPC の要求に置き換える。接続ではデーモンの Team ID と署名識別子（`io.github.koutyuke.capsaicin.helper`）を求める。5 秒で応答がなければ失敗を返し、接続を取り消す（`SPEC-HLP-005`）。XPC の部分は差し替えられるようにして、時間切れと失敗の扱いをテストする。`readSleepDisabled` は今のまま。
- 登録と状態を扱う型を作る（名前は任せる）。持つもの:
  - 状態: `SPEC-HLP-004` の4つ（未インストール、承認待ち、使える、このビルドでは使えない）。「このビルドでは使えない」は、自分の署名に Team ID がないことで決める（Security フレームワークの公開 API で自分の署名の情報を読む）。
  - 登録、登録を外す、システム設定の「ログイン項目と機能拡張」を開く。
  - App Translocation された場所かの判定（`SPEC-HLP-001`）。
  - 更新の後の登録し直し（`SPEC-HLP-007`）: 前回登録した版の記録との比較、unregister の完了を待ってから register、`EPERM` なら 3 秒待って最大 3 回、成功したら版を記録。待ち時間は差し替えてテストする。
  - `SMAppService` の呼び出しは差し替えられるようにし、上の分岐をテストで確かめる。
- `HelperInstaller`、`HelperScripts`、`HelperPaths` のうち要らなくなるもの、それらのテストを削除する。

### 動く状態を保つための最小限の変更

- 設定画面の「ヘルパー」の管理は、後続のチケットで作り直すまで、新しい部品に最小限でつなぐ（インストール → 登録、削除 → `SPEC-HLP-004` の順の削除、修復はなくす）。文言と見た目は変えなくてよい。
- `just check` が通る状態にする。

## 守ること

- `AGENTS.md` を読んでから始める。アプリを起動しない。`sudo`、`launchctl`、`sfltool` を実行しない。デーモンを登録しない（登録はオーナーが PR の Debug ビルドで確かめる）。
- root で行う処理は `pmset -a disablesleep 1|0` と、後片付けの記録の読み書きだけにする。デーモンにシェル、任意のパス、任意の環境変数を通さない。
- 本番のコードに `REQ-*` と `SPEC-*` を書かない。テスト名で仕様と対応させる。
- コメントは日本語で、理由だけを書く。
- `git commit` と `git push` をしない。

## 完了条件

- デーモン、launchd の定義、アプリの側の XPC と登録の部品があり、sudoers と管理者認証の経路が残っていない。
- デーモンの要求の検証（受け付ける辞書と拒む辞書）を、root も登録もなしに確かめるテストがある。方法は任せるが、本番のデーモンと同じコードを検査すること。
- 登録し直し、状態の決め方、XPC の時間切れのテストがある。
- バンドルの検査（`Tests/CapsaicinTests/CapsaicinTests.swift`）で、plist の場所とキー、デーモンの署名識別子を確かめる。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build` の後、`plutil -p` で plist を、`codesign -dv` でデーモンの識別子を見る。
- 実機（オーナー、設定画面の作り直しの後）: PR の Debug ビルドで、設置、`on` と `off`、削除、再起動の後の後片付けを確かめる。

## レビュー

PM がレビューした。デーモンは両方向の署名の条件、`command` の厳密な検証、直列の処理、30 秒の待機での終了を満たし、要求の検証と起動時の後片付けを本番の C のコードでテストしている。PM が次の2点を直した。

- 起動時の後片付けに失敗するとデーモンが終了し、`on` と `off` を受け付けなくなっていた。ログに残して続けるようにした。読めない記録（壊れた中身、権限の不整合、symlink）は、「初回」と同じく扱うと後片付けが二度と行われないので、別の起動の記録として `off` してから置き換えるようにした。
- 初めての `register()` は承認待ちにしたうえで `EPERM` を返す（`EVID-HLP-004`）のに、失敗として扱っていた。承認待ちになっていれば、版を記録して設定を開くようにした。登録し直しでも、承認待ちのままの `EPERM` は試し直さずに版を記録する。Team ID は一度だけ読む。

`just check` は通る（パッケージ 322、アプリ 158）。署名した XPC の接続、登録と承認、再起動の後の後片付けは、設定画面の作り直しの後に実機で確かめる。
