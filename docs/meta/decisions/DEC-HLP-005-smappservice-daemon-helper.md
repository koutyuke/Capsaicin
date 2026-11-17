---
schema: decision
id: DEC-HLP-005
title: root ヘルパーを、アプリに入れた SMAppService のデーモンと XPC で作り直す
status: accepted
supersedes: ["DEC-HLP-001", "DEC-HLP-003", "DEC-HLP-004"]
superseded_by: []
requirements: ["REQ-SYS-005", "REQ-SYS-006", "REQ-HLP-001", "REQ-HLP-002", "REQ-HLP-003", "REQ-HLP-004", "REQ-HLP-005", "REQ-HLP-006"]
based_on: ["DEC-HLP-004", "DEC-SYS-021", "EVID-HLP-004", "EVID-HLP-005", "EVID-LCY-003", "EVID-BLK-014", "HYP-HLP-005", "HYP-HLP-006", "HYP-HLP-007", "HYP-BLK-007"]
---

# DEC-HLP-005 root ヘルパーを、アプリに入れた SMAppService のデーモンと XPC で作り直す

## 結論

`DEC-HLP-004` の (c) を、試作で確かめた結果に合わせて確定する。

- **デーモン**: ヘルパーは、アプリのバンドルに入れた C の実行ファイルにし、`Contents/Library/LaunchDaemons/` の plist の `BundleProgram` で指す。`SMAppService.daemon` で登録し、libxpc の Mach サービスとして要求を受ける。受け付ける要求は `on` と `off` だけで、処理はこれまでどおり空の環境で `/usr/bin/pmset -a disablesleep 1|0` を `execve` する。非公開の IOKit API は使わない。
- **相手の制限**: デーモンは接続ごとに、同じ Team ID とアプリの署名識別子を求める。アプリも、同じ Team ID とデーモンの署名識別子を求める（`xpc_connection_set_peer_team_identity_requirement`）。承認さえあれば ad-hoc 署名のデーモンも起動するので（`EVID-HLP-004`）、root の処理を呼べる相手を絞るのはこの条件である。必ず両方向で付ける。
- **起動と終了**: デーモンはオンデマンドで起動し、使われなくなったら終了する。正規でない相手の接続でも launchd はデーモンを起動するので、接続や起動のたびに副作用のある処理をしない。
- **起動時の後片付け**: 残す。`RunAtLoad` で起動したとき、`kern.bootsessionuuid` を root だけが書ける `/Library/Application Support/` の下のファイルと比べ、Mac の起動ごとに1回だけ `off` を実行する。登録し直しや問い合わせで起動されても繰り返さない。`HYP-BLK-007` はまだ確かめられていない（`EVID-BLK-014`）。また、この仕組みは試作で確かめた（`EVID-HLP-004`）。
- **設置**: 管理者パスワードの入力をやめ、アプリが `register()` を呼び、利用者がシステム設定で許可する形にする。アプリは `SMAppService` の状態を読み、承認待ちならシステム設定を開く導線を示す。アプリは `/Applications` に置く前提とし、App Translocation された場所からは登録しない。
- **更新**: アプリの入れ替えだけで、次に起動したデーモンは新しい版になり、承認も保たれる（`EVID-HLP-005`）。それでもアプリは起動時に、前回登録したときの版と今の版を比べ、違えば unregister の完了を待ってから register し直す。plist の変更を確実に反映するためである。直後の register が EPERM で失敗したら、数秒待って数回まで試し直す。Sparkle による更新と手での入れ替えを、同じ経路で扱う。
- **失敗の扱い**: デーモンへの要求には時間の上限を付け、応答がなければ接続を取り消す。デーモンが起動を拒まれている間、保留中の接続があると launchd は起動を試し続けるためである。起動を拒まれた後は承認が外れることがあるので、失敗したら状態を読み直して示す。
- **削除**: 設定の「ヘルパー」の削除は、Capsaicin が立てた `disablesleep` を戻してから unregister する。unregister の後も、システム設定にはアプリの項目が「許可済み」のまま残る（`EVID-LCY-003`）。設定画面の説明で補う。
- **署名**: Release は Developer ID で署名して公証する（`DEC-SYS-021`）。手元の Debug ビルドは Apple Development の証明書で署名し、タイムスタンプは付けない。CI のテストは ad-hoc 署名のままにし、デーモンを使わない。ad-hoc 署名のビルドでは、XPC の条件で接続が落ちるので、ヘルパーを使えない。設定画面はそれを「使えない」と示す。
- **なくすもの**: sudoers のルール、`/Library/PrivilegedHelperTools` への複写、`/Library/LaunchDaemons` の plist、`osascript` による設置と削除のスクリプト、`visudo` による検証。
- **要件**: 実装する変更で、`REQ-SYS-005` と `REQ-SYS-006` を取り下げる。`REQ-HLP-001` は「システム設定の許可で設置できる」に書き換え、`REQ-HLP-003`（設置で sudo を壊さない）は sudoers を扱わなくなるので取り下げる。`REQ-HLP-002`、`REQ-HLP-004`、`REQ-HLP-005`、`REQ-HLP-006` は保ち、根拠をこの判断に移す。`disablesleep` の所有の規則（`SPEC-HLP-005`）は変えない。
- **規則**: `AGENTS.md` の「root で動くコードを増やさない」を、実装する変更で「root で行う処理を増やさない」に改める。root で動く C のコードは、接続の受け付け、相手の照合、起動ごとの記録の分だけ増える。root で行う処理は `on` と `off` のまま変えない。
- **移行**: v0.1.0 で設置した sudoers、ヘルパー、LaunchDaemon、LaunchAgent は、アプリで片付けない。Git に入れない手順書をオーナーが利用者に渡す。

## 背景

`DEC-HLP-004` は、SMAppService に移る方向を採り、前提をオーナーの実機の試作で確かめてから設計を確定するとした。試作の結果は次のとおりだった。

- 登録、承認、XPC、使われないときの終了、起動ごとに1回の後片付けは、公証していない Apple Development 署名の試作で成り立った（`EVID-HLP-004`）。
- 同じ Team ID の版への入れ替えでは、承認は保たれた。書き換えや別の署名への差し替えでは、デーモンは起動されなかった（`EVID-HLP-005`）。
- ad-hoc 署名でも、登録、承認、デーモンの起動まで進んだ。止めたのは XPC の署名の条件だけだった（`EVID-HLP-004`）。
- 再起動の後に `disablesleep` は 0 だったが、ほかの電源管理アプリが書いた可能性を除けなかった（`EVID-BLK-014`）。

`DEC-HLP-004` の覆す条件（更新のたびの再承認、agent の不成立、書き換えたデーモンの起動）は、どれも起きなかった。

## 選択肢

起動時の後片付けについて、次の2つを比べた。

- 外す: root で動くコードと、root が書くファイルが減る。ただし、`disablesleep` が再起動で残る環境では、抑止中のクラッシュや電源断の後に、アプリを起動するまで Mac が眠れなくなる。`SPEC-HLP-005` は、再起動の後に立っている `disablesleep` を外部のものとして扱うので、アプリを起動しても戻らない（不採用）。
- 残す: root で動くコードは、ファイル1つの読み書きの分だけ増える。仕組みは試作で確かめてある（採用）。

## 理由

- 試作で、(c) の前提はすべて成り立った。版のずれ、呼び出し元の制限、システム設定の表示という3つの問題を、(b) より根本から解決できる。
- 起動時の後片付けを外すと、外れたときの害（Mac が眠れなくなる）が大きい。残す費用は小さく、確かめた仕組みで済む。
- 登録し直しは、試作では実行ファイルの入れ替えには要らなかった。それでも、plist を変える版で古い定義が残る危険を、起動時の比較1つで避けられる。

## 影響

- `specs/helper.md` と `specs/settings.md` のヘルパーの節を、承認と状態の表示、登録し直し、削除の流れに合わせて書き直す。`specs/lifecycle.md` の起動時の処理も直す。
- `scripts/` の設置と削除のスクリプト、sudoers と LaunchDaemon の雛形、それらのテストを取り除く。
- 手元の Debug ビルドの署名が、オーナーの Team に依存する。Apple Development の証明書を持たない人は、ヘルパーを要する機能を手元で試せない。
- 自宅の回線のように `timestamp.apple.com` に届かない環境では、タイムスタンプを要する署名ができない（`EVID-HLP-004`）。Debug ではタイムスタンプを付けないので影響しない。Release は CI で署名する。
- `DEC-SYS-024` の Debug アプリの確認の範囲に、SMAppService の登録と状態の読み取りを入れるかは、実装のチケットで決める。

## 覆す条件

- ほかの電源管理アプリのない Mac で、`disablesleep 1` が再起動で 0 に戻ると確かめられたら（`HYP-BLK-007` が外れたら）、起動時の後片付けを外すかを比べ直す。
- Developer ID で署名して公証した版で、登録、承認、更新、XPC のどれかが試作と違う振る舞いをしたら、この判断を見直す。最初のリリースの前に確かめる。
- 将来の macOS で、同じ Team ID の版への更新のたびに承認を求められるようになったら、(b) と比べ直す。
