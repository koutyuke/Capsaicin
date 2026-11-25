---
schema: hypothesis
id: HYP-HLP-005
title: Team ID を持つ署名のアプリは、SMAppService.daemon を登録し、承認の後に XPC で同じ Team ID の相手とだけ通信できる
status: supported
affects: ["DEC-HLP-004"]
evidence: ["EVID-HLP-004"]
---

# HYP-HLP-005 Team ID を持つ署名のアプリは、SMAppService.daemon を登録し、承認の後に XPC で同じ Team ID の相手とだけ通信できる

## 主張

macOS 26 以上で、`/Applications` に置いたアプリが次のすべてを満たす。

1. Apple Development の証明書で署名したアプリは、バンドルに入れたデーモンを `SMAppService.daemon` で登録できる。状態は `.requiresApproval` になり、管理者がシステム設定で許可すると `.enabled` になる。Developer ID で署名して公証したアプリでも同じである。
2. 許可した後、アプリが Mach サービスに接続すると、launchd がデーモンを root で起動し、XPC の要求に応答する。使われなくなったデーモンが終了しても、次の接続で再び起動する。
3. デーモンが `xpc_connection_set_peer_team_identity_requirement` で要求する条件を満たさない相手（ad-hoc 署名のプログラムなど）の接続は、デーモンに届く前に拒まれる。アプリの側でも、同じ方法でデーモンを確かめられる。
4. ad-hoc 署名のアプリでは、登録か起動か接続のどこかで失敗する。どこで、どのエラーで失敗するかが分かる。
5. `RunAtLoad` は Mac の起動時のほか、登録と許可のときにも実行される。`kern.bootsessionuuid` は Mac の起動ごとに変わり、同じ起動の中では変わらない。

## 外れたときに起きること

1〜3 のどれかが外れたら、`DEC-HLP-004` の (c) は成り立たない。(b) に戻す。4 の結果は、ad-hoc 署名のビルドで root を要する機能を使えないことの示し方に使う。5 が外れたら、起動ごとに1回だけ後片付けをする方法を考え直す。

## 確かめ方

オーナーが、試作のアプリと、その手順書で確かめる。試作のデーモンは `pmset` を実行せず、要求に自分の uid と版と `kern.bootsessionuuid` を返すだけにする。

デーモンの登録は、永続的なシステム変更である。終わったら、試作のアプリから unregister し、システム設定の「ログイン項目と機能拡張」から項目が消えたことを確かめ、`/Applications` から試作のアプリを削除する。

## 結果

支持された（`EVID-HLP-004`）。Apple Development で署名し、公証していない試作で、主張の 1、2、3、5 が成り立った。登録は `requiresApproval` を経て、許可の後に `enabled` になった。デーモンは `euid=0` で応答し、使われないと終了し、次の接続で起動し直した。ad-hoc 署名の相手の接続は、デーモンの署名の条件で落とされた。後片付けは Mac の起動ごとに1回だけだった。

主張の 4 は外れた。ad-hoc 署名のアプリでも、登録、承認、ad-hoc 署名のデーモンの起動まで進んだ。止めたのは、デーモンが自分で求める XPC の署名の条件だけだった。この主張は (c) の成否に関わらないので、ほかの主張とあわせて支持とした。ad-hoc 署名のビルドで root を要する機能を使えないのは、XPC の署名の条件で接続が落とされるためである。Developer ID で署名して公証した版では試していない。
