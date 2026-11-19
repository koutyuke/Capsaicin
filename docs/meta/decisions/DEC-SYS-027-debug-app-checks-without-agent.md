---
schema: decision
id: DEC-SYS-027
title: agent をやめた後の、Debug アプリの実機確認の範囲と app レシピ
status: accepted
supersedes: ["DEC-SYS-024", "DEC-SYS-026"]
superseded_by: []
requirements: []
based_on: ["DEC-SYS-008", "DEC-LCY-010", "DEC-LCY-011"]
---

# DEC-SYS-027 agent をやめた後の、Debug アプリの実機確認の範囲と app レシピ

## 結論

`DEC-SYS-024` と `DEC-SYS-026` を置き換える。agent に関する部分を除き、ほかは引き継ぐ。

レシピと署名:

- 実機確認で Debug アプリを操作する入口は、justfile の `app` グループのレシピ（`start`、`stop`、`restart`、`status`）にする。レシピの出力は英語にする。
- レシピは、Debug の bundle ID（`io.github.koutyuke.capsaicin.debug`）のアプリを、置き場所によらず `NSRunningApplication` で見つける。手元のどの worktree のビルドも、`/Applications` などに置いた PR の Debug ビルドも対象にし、Release は対象にしない。`status` と `stop` はそのすべてを対象にする。`start` は、そのどれかが動いていれば起動せずに失敗し、動いていなければこのチェックアウトのビルドを開いて、その実行ファイルだけが動いていることを確かめる。同じ bundle ID のアプリは1つしか動けない（`DEC-LCY-011`）ためである。レシピは launchd のジョブを扱わない。
- `just build` と CI のテストは ad-hoc 署名のビルドを作る。手元のビルドでヘルパーを確かめるときは、`just sign-debug` で「Developer ID Application」の証明書を使って署名し直す。引数でほかの証明書も選べる。内側の実行コードから順に署名し、最後にアプリを署名する。署名の識別子、entitlements、フラグを保ち、タイムスタンプは付けない。`just sign-debug` はオーナーのキーチェーンの鍵を使うので、エージェントは承認を得て実行する。
- 実機の確認手順（`docs/manual/verification/`）が持つシェル変数は、検証ごとの退避先 `B` と、CLI を試すファイルが冒頭で定義する試験対象のパス `CLI` だけにする。

エージェントは、確認する対象と手順をオーナーに示して承認を得たら、その範囲で次を行ってよい。

- 自分の worktree でビルドした Debug アプリを起動し、終了する。justfile の `app` グループのレシピを使ってよい。
- Debug アプリが行う mainApp の登録（「ログイン時に起動」がオンのとき）。
- 状態の読み取り: `log show` と `log stream`、`launchctl print`、`sfltool dumpbtm`、`pmset -g`（`assertions` などの読み取りを含む）、`ps`、Debug の CLI の `status`。
- 承認された手順に含まれる場合だけ、Debug の CLI の `on` と `off`。
- `screencapture` による画面写真。画面収録の許可は、オーナーが与える。

次は、承認があってもエージェントは行わず、手順書でオーナーに渡す。

- 画面のボタンなどの操作、UI の自動操作。
- 管理者の認証やシステム設定での承認が要る操作（ヘルパーの設置と削除、SMAppService のデーモンの承認）。
- `sudo`、`pmset` の設定の変更、`launchctl` による読み取り以外の操作、Mac の再起動とログアウト。
- 開発機に残った古い agent の登録の片付け（`docs/manual/verification/prepare.md`）。
- Release のアプリ（`io.github.koutyuke.capsaicin`）の操作。

## 背景

`DEC-SYS-024` と `DEC-SYS-026` は、アプリが agent から起動されることを前提にしていた。レシピは agent のジョブを外して開き、ジョブの PID の実行ファイルで起動を確かめ、エージェントには Debug のジョブへの `launchctl` の `bootout` と `kickstart` を許していた。`DEC-LCY-010` で agent をやめ、`DEC-LCY-011` で同じ bundle ID のアプリを1つだけ動かすことにしたので、この前提がなくなった。

## 選択肢

1. Debug のプロセスを、これまでどおり実行ファイルの絶対パスの形（`.build/xcode/Build/Products/Debug/`）で見つける: PR の Debug ビルドを見落とす。そのビルドが動いていると、手元のビルドを開いても単一インスタンスの判定で終了し、どのビルドが動いているか分からなくなる。
2. bundle ID で `NSRunningApplication` から見つける（採用）: アプリの単一インスタンスの判定と同じ基準になり、置き場所によらない。

## 理由

手元のビルドと PR のビルドが混ざって確認できなくなる問題は、同じ bundle ID のコピーをレシピが見落とすことから起きていた。アプリと同じ基準で見つければ、`start` が成功したときに動いているのは、このチェックアウトのビルドだけだと言える。

## 影響

- justfile の `app` グループと `scripts/debug-app.sh` を、この判断に合わせる。
- `AGENTS.md` の禁止の例外とレシピの表を、この判断に合わせる。agent の登録と Debug のジョブへの `launchctl` の操作は、例外から外れる。
- 確認の手順書の app レシピの説明を合わせる。

## 覆す条件

- 同じ bundle ID のアプリを複数動かす必要が生じたとき（`DEC-LCY-011` を覆すとき）。
- `NSRunningApplication` で、終了しかけのプロセスや起動途中のプロセスを取り違え、レシピの判定が実際と食い違うことが分かったとき。
