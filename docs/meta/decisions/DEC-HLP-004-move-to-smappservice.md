---
schema: decision
id: DEC-HLP-004
title: root ヘルパーとバックグラウンド項目を SMAppService に移す方向を採り、試作で前提を確かめてから設計を確定する
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-SYS-005", "REQ-SYS-006", "REQ-HLP-002", "REQ-HLP-004", "REQ-LCY-001", "REQ-LCY-003"]
based_on: ["DEC-SYS-021", "DEC-HLP-001", "DEC-HLP-003", "DEC-LCY-002", "HYP-BLK-007", "HYP-HLP-005", "HYP-HLP-006", "HYP-HLP-007", "HYP-LCY-006", "HYP-LCY-007"]
---

# DEC-HLP-004 root ヘルパーとバックグラウンド項目を SMAppService に移す方向を採り、試作で前提を確かめてから設計を確定する

## 結論

オーナーが Developer ID を得たので（`DEC-SYS-021`）、署名に依存しない方式を選んだ判断（`DEC-HLP-001` など）を見直し、次の構成を目標にする。

- root ヘルパーは、アプリのバンドルに入れた `SMAppService.daemon` にする。C で書き、libxpc の Mach サービスとして要求を受ける。受け付ける要求は `on` と `off` の2つだけにし、処理はこれまでどおり空の環境で `/usr/bin/pmset -a disablesleep 1|0` を `execve` する。非公開の IOKit API は使わない。
- デーモンとアプリは、互いの接続相手を、同じ Team ID と決めた署名識別子を持つものに限る（`xpc_connection_set_peer_team_identity_requirement`）。
- デーモンはオンデマンドで起動し、使われていなければ終了する。Mac の起動時の後片付けは、Mac の起動ごとに1回だけ行い、登録や接続のたびに `off` しない。
- sudoers のルール、`/Library/PrivilegedHelperTools` への複写、`osascript` による設置と削除のスクリプトをなくす。
- ログイン時の起動は `SMAppService.mainApp` で切り替える。クラッシュ時の再起動は、`KeepAlive` の `Crashed` を持つ `SMAppService.agent` で行い、直接起動したアプリはその agent に引き渡す。
- アプリは起動時に、前回登録した版と今の版を比べ、違えばデーモンと agent を登録し直す。Sparkle による更新と手での入れ替えを、同じ経路で扱う。
- `REQ-SYS-005`（Developer Program なしでソースからビルドして使える）と `REQ-SYS-006`（コード署名に依存しない）は、この構成を実装する変更で取り下げる。手元の Debug ビルドは Apple Development の証明書で署名する。CI のテストは ad-hoc 署名のままにする。
- v0.1.0 で設置した sudoers、ヘルパー、LaunchDaemon、LaunchAgent は、アプリで片付けない。Git に入れない手順書をオーナーが利用者に渡す。

実装に入る前に、`HYP-BLK-007`、`HYP-HLP-005`、`HYP-HLP-006`、`HYP-HLP-007`、`HYP-LCY-006`、`HYP-LCY-007` をオーナーが実機の試作で確かめる。結果を受けて、`DEC-HLP-001`、`DEC-HLP-003`、`DEC-LCY-002` を置き換える判断を作り、要件と仕様を直す。

## 背景

アプリを更新しても、`/Library/PrivilegedHelperTools` のヘルパーは古いまま残り、インストールの状態は3つのファイルの有無だけで判定している。Sparkle には、更新した後の新しい版で必ず呼ばれるフックがない。システム設定の「ログイン項目と機能拡張」には、LaunchAgent と LaunchDaemon が別々の項目として出る。

オーナーは Developer ID を得て、手元でソースからビルドする人を支える必要はないと決めた。配布は、公証した GitHub Releases の zip と Homebrew にする。実装のコストより、最終的に利用者と保守する人にとって良いものになることを優先する。

## 選択肢

- (a) sudoers と LaunchDaemon を保ち、同梱のヘルパーとの不一致を検出して、管理者認証で置き直す。署名に依存しないが、版のずれを利用者の操作で直すことになり、表示も分かれたままになる（不採用）。
- (b) (a) に、plist の `AssociatedBundleIdentifiers` を足して表示をまとめる。費用は小さい。ただし、同じ利用者のほかのプロセスもヘルパーを呼べるままで、root で動く設置と削除のスクリプトも残る（試作で (c) の前提が崩れたときの代わりの案）。
- (c) `SMAppService.daemon` と XPC に移り、ログイン時の起動とクラッシュ時の再起動も SMAppService に移す（採用）。

2つのアドバイザーの意見は分かれた。片方は、root で動くコードを増やさない規則（`AGENTS.md`）と `REQ-SYS-005` を重く見て (b) を推した。もう片方は、版のずれと呼び出し元の制限を重く見て (c) を推した。`REQ-SYS-005` を取り下げると決めた後に、オーナーは (c) を選んだ。

## 理由

- ヘルパーがアプリの中に入るので、更新でアプリとヘルパーの版がずれない。更新後の扱いは、起動時に登録し直すことの1つにまとまる。
- ヘルパーを呼べる相手が、同じ利用者の任意のプロセスから、同じ Team ID の Capsaicin だけに絞られる。sudoers のルールと、root で実行する設置と削除のスクリプトがなくなる。
- システム設定の項目が、Apple の既定の振る舞いでアプリのもとにまとまる。
- root で行う処理は `on` と `off` のまま変えない。root で動く C のコードは、接続の受け付けと相手の照合の分だけ増える。これは、root で行う処理を増やさないという規則の趣旨の範囲だと、オーナーと判断した。

## 影響

- ヘルパーの設置は、管理者パスワードの入力から、システム設定での承認に変わる。承認の待ちと取り消しを、設定画面で示す必要がある。
- デーモンを含むアプリは公証が要る（`SMAppService.h`）。手元の Debug ビルドは Apple Development の証明書で署名し、オーナーの Team に依存する。ad-hoc 署名のビルドでは、root を要する機能を使えない。
- アプリを捨てると、Mac の起動時の後片付けも一緒になくなる。削除の流れ（`SPEC-HLP-004`）を見直す。
- アプリは `/Applications` に置く前提になる（`SMAppService.h` が勧めている）。App Translocation された場所からは登録しない。
- CLI とアプリの通信（`DEC-CLI-002`）は変えない。同じ利用者は CLI を実行できるので、CLI の署名を確かめても守れる範囲は増えない。
- 試作のために、オーナーの Mac にデーモンと agent を登録する。試作の手順書で、片付け方を示す。

## 覆す条件

- 試作で、同じ Team ID の版へ更新して登録し直すたびに承認が要る、登録し直しが自動で回復しない、または更新した後に XPC がつながらないと分かったら（`HYP-HLP-006`）、(b) に戻す。
- `SMAppService.agent` で `KeepAlive` の `Crashed` か `launchctl kickstart` が効かないと分かったら（`HYP-LCY-006`）、ログイン時の起動とクラッシュ時の再起動は、いまの LaunchAgent のまま `AssociatedBundleIdentifiers` を足す方式にする。
- バンドルの中のデーモンを書き換えても launchd が起動すると分かったら（`HYP-HLP-007`）、デーモンの安全性の前提が崩れるので、(c) を採るかを比べ直す。
- `HYP-BLK-007` が外れ、`disablesleep` が再起動で残らないと分かったら、起動時の後片付けを設計から外す。
