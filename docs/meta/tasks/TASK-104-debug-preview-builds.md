---
schema: task
id: TASK-104
title: S-Preview のラベルで署名と公証をした Debug ビルドを作り、PR のコメント1つで状態を示す
status: todo
requirements: []
depends_on: []
assignee: Codex（OpenCode 経由、openai/gpt-6.1-sol）
---

# TASK-104 S-Preview のラベルで署名と公証をした Debug ビルドを作り、PR のコメント1つで状態を示す

## 目的

`DEC-SYS-023` のとおり、`develop` への PR に `S-Preview` を付けたら、Developer ID で署名して公証した Debug 構成のアプリを作る。リリースの確認用ビルドと合わせて、PR のコメントを「ビルド中」から「完了」か「失敗」に書き換える形にする。

## 範囲

変更してよいもの:

- `.github/workflows/release.yml`
- 新しいワークフロー（確認用の Debug ビルドと、署名と公証の再利用可能なワークフロー）
- `.github/actions/` の下（コメントを書く処理を共有する場合）
- `justfile`（Debug の zip を作るレシピを足す場合）
- `docs/manual/release.md` の確認用ビルドのコメントの説明

触らないもの: `.github/workflows/ci.yml`、`.github/workflows/pr-policy.yml`、`project.yml`、アプリのコード、`docs/` のほかのファイル、GitHub のラベルや secret（作るのはオーナー）。

## 作るもの

1. 署名と公証の再利用可能なワークフロー（`workflow_call`）。いまの `release.yml` の `sign-and-notarize` のジョブを移す。入力は、受け取る artifact の名前、zip のファイル名、出力する artifact の名前とする。secret は呼び出し側から明示して渡す。checkout しないこと、一時キーチェーン、後片付け、公証と `stapler validate` と `spctl --assess` で止める動きは変えない。`release.yml` はこれを呼ぶ形にする。
2. 確認用の Debug ビルドのワークフロー。
   - 契機: `develop` への `pull_request` の `opened`、`reopened`、`synchronize`、`labeled`。PR に `S-Preview` があり、head が同じリポジトリのときだけ動く。`labeled` は、付けたラベルが `S-Preview` のときだけ動く。同じ PR の古い実行は取り消す。
   - Debug 構成のアプリを、いまの `just build` と同じ設定（arm64、ad-hoc 署名）でビルドし、`ditto` で zip にする。Debug 構成にだけ入るファイル（`ENABLE_DEBUG_DYLIB` による debug dylib、プレビュー用の dylib など）は、このビルドでは作らない設定を渡す。zip の名前は、PR の番号とコミットの短いハッシュが分かるものにする。
   - 署名と公証は 1 のワークフローで行う。
3. PR のコメントの書き換え。
   - コメントの種類ごとに、本文の先頭に隠しの印（例: `<!-- capsaicin-preview:debug -->`、`<!-- capsaicin-preview:release -->`）を置き、`github-actions[bot]` が書いたその印のコメントを1つだけ使う。なければ作る。
   - ビルドのジョブより前に、「ビルド中」の状態に書き換える。最後に、結果に合わせて「完了」か「失敗」に書き換える。取り消された実行は書き換えない（新しい実行が「ビルド中」にする）。
   - リリースの確認用ビルドのコメントも、同じ形と同じ流れにする。
   - Markdown は、次の形を目安にする（英語）。

     ビルド中:

     ```markdown
     <!-- capsaicin-preview:debug -->
     ### 🔨 Debug preview · building

     Building [`abc1234`](コミットの URL) — [view run](実行の URL)
     ```

     完了:

     ```markdown
     <!-- capsaicin-preview:debug -->
     ### ✅ Debug preview · ready

     | | |
     | --- | --- |
     | **Download** | [Capsaicin-debug-pr12-abc1234.zip](artifact の URL) |
     | **Commit** | [`abc1234`](コミットの URL) |
     | **Build** | Debug · `io.github.koutyuke.capsaicin.debug` |
     | **Signing** | Developer ID · notarized · stapled |
     | **Expires** | 2026-11-25 (7 days) |

     > Installs alongside the release app. Updates through Sparkle are disabled in this build.

     [View run](実行の URL)
     ```

     失敗:

     ```markdown
     <!-- capsaicin-preview:debug -->
     ### ❌ Debug preview · failed

     The build for [`abc1234`](コミットの URL) failed. [View run](実行の URL)
     ```

     リリースの確認用ビルドでは、見出しを `Release preview`、Build の行を `Release <版>`、注記を「Replaces an installed release app.」にする。

## 守ること

- ワークフローの権限は、ジョブごとに必要な最小にする（コメントを書くジョブだけ `pull-requests: write`）。
- 署名の secret は、checkout しないジョブにだけ渡す。PR の head のコードを実行するジョブに secret を渡さない。
- アクションは、既存と同じくコミットのハッシュで固定する。新しいアクションは足さない。コメントは `gh api` で書く。
- PR のタイトルや本文など、利用者が書ける値をシェルに直接埋め込まず、環境変数で渡す。
- just のレシピとスクリプトのメッセージは英語、コメントは日本語にする（`AGENTS.md`）。
- `git commit`、`git push`、GitHub への書き込みをしない。

## 完了条件

- `actionlint` 相当の検査（devShell にあれば使う。なければ YAML の構文と、`just lint` が通ること）が通る。
- リリースの流れ（確認用ビルドと公開）で、署名と公証のジョブの入力と出力が、これまでと同じ zip と artifact になる。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just check`
- ワークフローの静的な検査
- 実際の動作は、オーナーがラベルを作り、PR に付けて確かめる。

## レビュー

未レビュー。
