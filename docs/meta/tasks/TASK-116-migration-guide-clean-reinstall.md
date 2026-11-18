---
schema: task
id: TASK-116
title: v0.1.0 からの移行の手順書を、設定と記録も消して入れ直す形にする
status: done
requirements: []
depends_on: []
assignee: Gemini（Antigravity、gemini-3.8-flash）
---

# TASK-116 v0.1.0 からの移行の手順書を、設定と記録も消して入れ直す形にする

## 目的

v0.1.0 の利用者に渡す移行の手順書は、Git の外に置いている。オーナーは、v0.1.0 以前の利用者には、システムに置いたものだけでなく、設定と記録も含めて一度すべて消してから新しい版を入れ直してもらう方針にした。手順書をこの方針に合わせる。

## 範囲

変更してよいもの: `/Users/koutyuke/Developer/github.com/koutyuke/capsaicin/.koutyuke/migration-from-v0.1.0.md`（Git の外のファイル）だけ。

触らないもの: リポジトリの中のファイルすべて。main のチェックアウトのブランチを切り替えない。

## やること

1. 今の手順書を読む。ヘルパーと `~/Library/LaunchAgents` の plist の削除、`SleepDisabled` の確認は既にある。これは残す。
2. v0.1.0 の版が利用者の Mac に書く設定と記録の場所を、v0.1.0 のタグのソース（`git -C /Users/koutyuke/Developer/github.com/koutyuke/capsaicin-smappservice show v0.1.0:<path>` や `git grep v0.1.0`）から調べる。設定の `defaults` のドメイン、Application Support などに置く記録のファイル（再開用の記録、輝度の記録など）、ヘルパーが root で書く記録が対象である。ソースで確かめられた場所だけを書く。macOS がどのアプリにも作る場所（`~/Library/Caches/<bundle ID>`、`~/Library/HTTPStorages/<bundle ID>`、`~/Library/Saved Application State/<bundle ID>.savedState`）は、「あれば」消すものとして書いてよい。
3. 設定と記録を消す手順を足す。設定は `defaults delete <ドメイン>` で消す。ファイルとフォルダーは、`/bin/rm` に完全なパスを渡して消し、ワイルドカードを使わない。消す前に Capsaicin が終了していることを確かめる手順を置く。
4. 「設定は、そのまま引き継がれます」をやめ、新しい版で設定を入れ直すことを書く。
5. 文体と構成は今の手順書に合わせる。利用者が一度読めば迷わない、自然な日本語にする（`~/.claude/skills/yomiyasu/SKILL.md` の方針に従う）。

## 守ること

- 手順のコマンドを自分で実行しない。読み取りのための `git` と、ファイルの閲覧だけを使う。
- ソースで確かめられなかった場所を推測で書かない。確かめられなかったものは報告に書く。

## 完了条件

- 1〜5 を満たす。
- 報告に、足した場所ごとの根拠（ファイルと行）と、確かめられなかったものを書く。

## 検証

- PM が、根拠のファイルと行を照らし合わせて読む。

## レビュー

PM がレビューした。Gemini は根拠に今の作業ツリーのファイルを挙げたので、PM が v0.1.0 のタグで照らし合わせた。設定のドメイン（`AppComposition.swift:16` の `UserDefaults.standard`、Release の bundle ID は `project.yml:45`）と、`~/Library/Application Support/io.github.koutyuke.capsaicin/resume-record.json`（輝度の記録も同じファイル）は合っていた。v0.1.0 のヘルパーが root で書く記録はなかった。PM が次を直した。

- v0.1.0 の CLI との通信のソケットのフォルダー `/private/tmp/io.github.koutyuke.capsaicin-<uid>`（`IPCEndpoint.swift:13`）が抜けていたので足した。
- 画面の名前を実装に合わせた。v0.1.0 の「Capsaicinを終了」「削除…」、新しい版の「ログイン時に起動」「システム設定での許可待ち」。
- `pkill` で終了させる案内は、終了時の後片付けを経ないので外し、メニューから終了して確かめ直す案内にした。
