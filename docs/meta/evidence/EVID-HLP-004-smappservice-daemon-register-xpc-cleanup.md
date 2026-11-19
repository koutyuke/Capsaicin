---
schema: evidence
id: EVID-HLP-004
title: Team ID を持つ署名の試作は SMAppService.daemon を承認の後に root で動かし、署名の条件で XPC の相手を絞れ、起動時の後片付けは起動ごとに1回だった
observed_on: 2026-11-18
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、試作 CapsaicinProbe を Apple Development の証明書（Team ID あり、公証なし）と ad-hoc で署名、/Applications に配置
sources: ["8e003dc:docs/meta/tasks/TASK-103-smappservice-probe.md"]
---

# EVID-HLP-004 Team ID を持つ署名の試作は SMAppService.daemon を承認の後に root で動かし、署名の条件で XPC の相手を絞れ、起動時の後片付けは起動ごとに1回だった

## 確かめた事実

試作のデーモンは C で書き、`MachServices` を1つ持ち、`RunAtLoad=true`、KeepAlive なしの plist を `BundleProgram` で指す。接続のたびに、`xpc_connection_set_peer_team_identity_requirement` で同じ Team ID とアプリの署名識別子を求める。接続を受け付ける前の listener にも同じ条件を付ける。アプリの側も、同じ方法でデーモンを確かめる。接続がなくなって約30秒経つと、デーモンは自分で終了する。デーモンは `pmset` を実行せず、`kern.bootsessionuuid` を `/Library/Application Support/CapsaicinProbe/` のファイルと比べて、違うときだけ「起動時の後片付け」を記録する。

Apple Development で署名し、公証していない試作で、次を確かめた。

- 登録と承認: 最初の `register()` は `SMAppServiceErrorDomain` の `code=1`（Operation not permitted）を返し、状態は `requiresApproval` になった。システム設定で許可すると `enabled` になり、その時点でデーモンが `RunAtLoad` で起動し、後片付けを1回記録した。許可した後にもう一度 `register()` を呼ぶと成功したが、デーモンは起動し直さなかった。
- XPC: 許可の後の問い合わせに、デーモンが `euid=0` で応答した。
- 使われていないときの終了: 応答の約40秒後に、デーモンのプロセスはなくなった。次の問い合わせで、launchd がデーモンを起動し直した（`because ipc (mach)`）。pid は変わり、後片付けは行わなかった。
- 相手の制限: ad-hoc 署名の CLI から接続すると、`Connection interrupted` が返り、中身は返らなかった。デーモンのログに `Dropping check-in message due to code signing requirement` が出た。正規でない相手の接続でも、launchd はデーモンを root で起動した（このときも後片付けは行わなかった）。
- Mac の起動: 再起動すると、起動から約20秒後にデーモンが起動し、後片付けを1回だけ記録した。`kern.bootsessionuuid` は再起動の前と違う値になった。その後、50秒空けた2回の問い合わせでは、どちらも後片付けを行わなかった。

ad-hoc で署名した試作（アプリとデーモンに Team ID がない）でも、次を確かめた。それまでの登録を unregister してから、アプリを入れ替えた。

- `register()` は同じく `code=1` を返して `requiresApproval` になり、システム設定で許可すると `enabled` になった。
- 許可の直後に、ad-hoc 署名のデーモンが `RunAtLoad` で起動した。カーネルと amfid は `adhoc signed`（`-423`）を記録したが、起動の制約の違反は出ず、起動は止まらなかった。plist に `UserName` がない system ドメインのジョブだった。
- アプリからの問い合わせは `Connection interrupted` で、デーモンが署名の条件で接続を落とした。

## 確かめ方

使い捨ての試作のアプリを、オーナーが自分の Mac で操作した。試作の作りは `sources` のチケットにある。コードはリポジトリに残していない。操作したのは、登録と承認、問い合わせ、40秒待ってからの問い合わせ、ad-hoc 署名の CLI からの接続、再起動の後の問い合わせ、ad-hoc 署名の版での登録と承認である。結果は、試作の画面の記録と、`/usr/bin/log show` による launchd、xpcproxy、amfid、カーネルのログで確かめた。

自宅の回線から `timestamp.apple.com`（17.157.80.35:80）に TCP で接続できず、`codesign --timestamp` は Apple Development でも Developer ID でも `A timestamp was expected but was not found.` で失敗した。ビルドだけ、別の回線で行った。

## 適用範囲

- 使ってよい: SMAppService のデーモンの登録と承認の流れ、XPC で相手を絞る方法、Mac の起動ごとに1回だけ処理を行う方法を判断するとき。公証していない Apple Development 署名の Debug ビルドで、デーモンを試せることの根拠。
- 使ってはいけない: Developer ID で署名して公証したビルドでの振る舞いの根拠（同じだと見込むが試していない）。ad-hoc 署名のデーモンが root で動いたことの直接の根拠（`euid` は測れていない）。

## 未確認のこと

- ad-hoc 署名のデーモンの `euid`。
- 登録と承認が、再起動や再ビルドの後も ad-hoc 署名で保たれるか。
- 1台、1つの macOS のバージョンでしか確かめていない。
