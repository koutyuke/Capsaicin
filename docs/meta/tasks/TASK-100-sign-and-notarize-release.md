---
schema: task
id: TASK-100
title: リリースの配布物を Developer ID で署名して公証する
status: todo
requirements: ["REQ-SYS-005", "REQ-SYS-006", "REQ-SYS-008"]
depends_on: []
assignee: Codex（OpenCode 経由の openai/*）
---

# TASK-100 リリースの配布物を Developer ID で署名して公証する

## 目的

`DEC-SYS-021` のとおり、Release ワークフローで、確認用のビルドと公開する zip を Developer ID で署名し、公証して staple する。手元のビルドと `just dist` は ad-hoc 署名のまま変えない。

## 範囲

変更してよいファイル:

- `.github/workflows/release.yml`
- `docs/manual/release.md`
- `README.md`、`README.ja.md`
- `AGENTS.md`（検証の節の「署名は ad-hoc で」の1文だけ）

変更してはいけないもの:

- `project.yml`、`justfile`、`Sources/`、`Packages/`、`scripts/`。手元のビルドと `just dist` は ad-hoc 署名のままにする。
- `docs/meta/` の判断・仮説・要件。PM が書く。食い違いを見つけたら報告する。
- Actions secret の登録、`git push`、`gh` での書き込み。secret はオーナーが登録する。

## 作ること

### secret の名前

| 名前 | 中身 |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Developer ID Application の `.p12` を base64 にしたもの |
| `DEVELOPER_ID_P12_PASSWORD` | `.p12` の書き出し用パスワード |
| `NOTARY_API_KEY` | App Store Connect の Team Key の `.p8` の中身（PEM の文字列） |
| `NOTARY_API_KEY_ID` | Team Key の Key ID |
| `NOTARY_API_ISSUER_ID` | Team Key の Issuer ID |

### ワークフロー

- 署名と公証は、同じリポジトリの再利用できるワークフロー（`workflow_call`）か、各ジョブで同じ手順を持つジョブにまとめ、確認用のビルドと公開の両方で同じ処理を通す。どちらにするかは、重複が少なく読みやすい方を選び、理由を報告する。
- 署名のジョブは `actions/checkout` をせず、`just dist` のジョブが upload した zip を download して処理する。`runs-on: xcode-27`、`permissions: contents: read` にする。
- 手順:
  1. 5つの secret がすべて空でないことを確かめ、欠けていたら名前を示して失敗する。
  2. `$RUNNER_TEMP` に一時キーチェーンを作り、`.p12` を読み込み、`codesign` が使えるようにする（`security set-key-partition-list` など）。キーチェーンの検索リストは、元の内容を保ったうえで一時キーチェーンを足す。後片付けは `if: always()` のステップで行う（一時キーチェーンの削除、`.p12` と `.p8` のファイルの削除）。
  3. zip を `ditto -x -k` で展開する。
  4. 内側から順に `codesign --force --timestamp --options runtime --sign "Developer ID Application"` で署名する。対象と順序は、`Contents/Helpers/capsaicin`、`Contents/Helpers/capsaicin-helper`、`Sparkle.framework/Versions/B/XPCServices/Installer.xpc`、`Sparkle.framework/Versions/B/XPCServices/Downloader.xpc`（`--preserve-metadata=entitlements` を付ける）、`Sparkle.framework/Versions/B/Autoupdate`、`Sparkle.framework/Versions/B/Updater.app`、`Sparkle.framework`、最後に `Capsaicin.app`。`--deep` は使わない。CLI とヘルパーには、今の ad-hoc 署名と同じ識別子（`--identifier`。`project.yml` の `OTHER_CODE_SIGN_FLAGS` を参照）を保つ。署名する ID は証明書の名前の一部で指定し、Team ID をワークフローに直接書かない。
  5. `codesign --verify --strict --deep --verbose=2` でアプリを検証する。
  6. 公証に出すための zip を `ditto -c -k --keepParent` で作り、`xcrun notarytool submit --key --key-id --issuer --wait` で出す。`.p8` は `$RUNNER_TEMP` の所有者だけが読めるファイルに書く。結果が `Accepted` でなければ、`notarytool log` の結果を出して失敗する。
  7. `xcrun stapler staple` でアプリに staple し、`xcrun stapler validate` と `spctl --assess --type execute -vv` で確かめる。出力に `source=Notarized Developer ID` がなければ失敗する。
  8. `just dist` と同じ `ditto` のオプションで `Capsaicin-{版}.zip` を作り直し、`SHA256SUMS.txt` を作り直して upload する。
- 公開の流れは、`release-package`（ビルドと版の確認）→ 署名と公証 → `release-appcast` → `publish` の順にする。appcast の EdDSA 署名と attestation は、署名と公証の後の zip に対して作る。
- 確認用のビルドも、`preview-package` → 署名と公証 → `preview-comment` の順にする。PR のコメントの `Signing: ad-hoc (not notarized)` を、Developer ID で署名し公証したことを示す文に変える。
- 秘密情報をコマンドの引数、ログ、`set -x` の出力に出さない。secret は、それを使うステップの `env` にだけ渡す。外部の Action を新しく使う場合は、コミットの SHA で固定し、版をコメントで添える。新しい外部の Action は、使わずに済むなら使わない。

### 文書

- `docs/manual/release.md`: 「Developer ID の証明書と公証用のキーを登録する（初回と、証明書を作り直したとき）」の節を足す。オーナーが 1Password に保管した `.p12` と `.p8` から、`gh secret set` で5つの secret を登録する手順を書く。値を画面、シェルの履歴、平文のファイルに残さない方法にする（例: `base64 -i file.p12 | gh secret set DEVELOPER_ID_P12_BASE64 --repo koutyuke/Capsaicin`、パスワードは対話の入力で渡す）。証明書の有効期限（2027年12月17日）の前に作り直すことも書く。「通常のリリース」の手順3に、確認用のビルドが Developer ID で署名され公証されていることの確かめ方（`codesign -dv --verbose=2`、`spctl --assess -vv`）を足す。
- `README.md`、`README.ja.md`: 公証していないので「このまま開く」を選ぶ、という段落を消す。
- `AGENTS.md`: 「署名は ad-hoc で」を、手元のビルドは ad-hoc 署名で、配布物は Release ワークフローで Developer ID で署名して公証する（`DEC-SYS-021`）という内容に直す。

## 完了条件

- 上の「作ること」をすべて満たす。
- `nix develop --command just check` が通る。
- `actionlint` が使えるなら、`release.yml` にエラーがない（devShell にない場合は `nix shell nixpkgs#actionlint --command actionlint` で一時的に使い、使ったことを報告する）。
- secret がない状態でワークフローが動いた場合に、どの secret が欠けているかが分かる形で失敗する。
- 差分が範囲のファイルだけに収まっている。

## 検証

- `nix develop --command just check`
- `actionlint .github/workflows/release.yml`
- 手元で `nix develop --command just dist` を実行し、zip の中のアプリの内側の実行ファイル（上の手順4の対象）が、ワークフローの署名の対象とすべて一致することを `find` で確かめる。抜けや余りがあれば報告する。
- ワークフローは実際には動かせないので、PM がレビューで手順を読み、オーナーが最初のリリース用の PR で確かめる（`HYP-SYS-004`）。

## レビュー

（未記入）
