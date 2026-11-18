---
schema: task
id: TASK-117
title: 試作のヘルパーのラベルを、ビルドのときの環境変数で変えられるようにする
status: done
requirements: []
depends_on: []
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-117 試作のヘルパーのラベルを、ビルドのときの環境変数で変えられるようにする

## 目的

`HYP-HLP-011`（デーモンを登録したアプリのコピーを消すか動かすと、BTM のデーモンの項目が親を失う）を確かめたい。この Mac には、`.debug` のヘルパーのラベル（`io.github.koutyuke.capsaicin.debug.helper`）で、親のない項目が既に残っている（`EVID-HLP-007`）。そのラベルで登録すると、その項目が使い直されて実験にならない。実験のたびに未使用のラベルで登録できるよう、試作のビルドで、ヘルパーのラベルに付ける接尾辞を環境変数で指定できるようにする。

必ず読む: `EVID-HLP-007`、`HYP-HLP-011`、`TASK-114`（試作の今の変更）、`DEC-HLP-005`。

## 範囲

作業する場所: worktree `/Users/koutyuke/Developer/github.com/koutyuke/capsaicin-daemon-cleanup-probe`（ブランチ `spike/daemon-cleanup-probe`）。`feature/smappservice` には取り込まない。

変更してよいもの: `project.yml`、`Packages/CapsaicinKit/Sources/CapsaicinPlatform/Helper/`、`Sources/capsaicin-helper/`、それらのテストと `Tests/`（バンドルの検査が名前に依存する場合）。

触らないもの: `docs/`、`justfile`、`scripts/`、String Catalog、`feature/smappservice` の worktree。

## やること

1. ビルドのときの環境変数 `HELPER_LABEL_SUFFIX` を読む。空か未設定なら、今と同じラベル `io.github.koutyuke.capsaicin.debug.helper` にする。値があれば `io.github.koutyuke.capsaicin.debug.helper-<値>` にする（例: `HELPER_LABEL_SUFFIX=r1` で `...helper-r1`）。値は英小文字と数字だけを許し、それ以外ならビルドを失敗させる。Debug 構成だけに効かせ、Release 構成のラベルは変えない。
2. そのラベルを、次のすべてにそろえて使う。
   - `Contents/Library/LaunchDaemons/` の plist のファイル名、`Label`、`MachServices` のキー（`project.yml` のビルドフェーズ）
   - ヘルパーの `HELPER_SERVICE_NAME`
   - アプリが `SMAppService.daemon(plistName:)` と XPC の接続に使う名前（`HelperIdentity.serviceName`）。アプリは、ビルドで `Info.plist` に入れた値を読む形にする。
3. `HELPER_APP_IDENTIFIER`（署名の識別子の照合）、デーモンが受け付ける要求（`on` と `off`）、ログのサブシステムは変えない。
4. 接尾辞を指定しない `just build` の成果物が、今と同じ名前になることを保つ。

## 守ること

- `AGENTS.md` を読んでから始める。アプリを起動しない。`sudo`、`launchctl`、`pmset` の設定変更、`sfltool`、SMAppService の登録を、自分で実行しない。
- 試作なので、変更は最小にする。新しい設定の画面、防御、抽象化を足さない。
- 本番のコードに `REQ-*`、`SPEC-*`、`HYP-*` を書かない。コメントは日本語で、コードを言い換えるだけのコメントを書かない。
- `git commit` と `git push` をしない。

## 完了条件

- 1〜4 を満たす。
- `nix develop --command just check` が通る。
- `HELPER_LABEL_SUFFIX=r1 nix develop --command just build` の成果物で、plist のファイル名・`Label`・`MachServices`、`Info.plist` の値、ヘルパーの実行ファイルの文字列が `...helper-r1` になっている。指定しない `just build` では、どれも `...helper` のままである。

## 検証

- `nix develop --command just check`
- `HELPER_LABEL_SUFFIX=r1 nix develop --command just build` の後、`plutil -p` と `strings` で成果物を確かめ、報告にそのまま載せる。続けて、接尾辞なしで `just build` し直して同じ確認をする。

## レビュー

PM がレビューした。`spike/daemon-cleanup-probe` で `just check` が通る。ヘルパーのターゲットのビルド前の処理が `HELPER_LABEL_SUFFIX` を英小文字と数字だけか確かめ（違えばビルドが失敗する）、Debug の `HELPER_SERVICE_NAME` をヘッダーで定義する。アプリのビルドの処理が、同じラベルを daemon の plist のファイル名・`Label`・`MachServices` と `Info.plist` の `CapsaicinHelperServiceName` に入れ、`HelperIdentity.serviceName` はその値を読む。`r1` を指定したビルドと指定しないビルド、不正な値、Release で接尾辞が無視されることを、Codex の報告の出力で確かめた。
