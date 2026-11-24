---
schema: task
id: TASK-129
title: 公開物、Sparkle の更新、確認用のビルドを DMG にする
status: todo
requirements: ["REQ-SYS-008"]
depends_on: []
assignee: Codex（OpenCode openai/gpt-6.2-sol）
---

# TASK-129 公開物、Sparkle の更新、確認用のビルドを DMG にする

## 目的

`DEC-SYS-028` を実装する。利用者が受け取るもの（GitHub Release の公開物、appcast の `enclosure`、リリース用の PR と `develop` への PR の確認用のビルド）を、署名・公証・staple した DMG にする。ビルドのジョブから署名のジョブへの受け渡しは、今の ad-hoc 署名の zip のままにする。

## 範囲

変更してよいファイル:

- `.github/workflows/sign-and-notarize.yml`
- `.github/workflows/release.yml`
- `.github/workflows/debug-preview.yml`
- `scripts/preview_comment.py`、`scripts/tests/test_preview_comment.py`
- `justfile`（`dist` と `dist-debug` のコメントだけ。zip を作る処理は変えない）
- `AGENTS.md`（検証の表の `dist` の行）
- `README.md`、`README.ja.md`（インストールと検証の手順）
- `docs/manual/release.md`（DMG に関わる手順）

変更しないもの: アプリのコード、`project.yml`、ほかの判断・根拠・仮説（過去の記録は書いた時点のまま残す）、`.github/actions/build-tools/`。

## 作り方

### 署名のジョブ（`sign-and-notarize.yml`）

- 入力の `zip-name`（受け取る ad-hoc の zip）は残す。`output-artifact` の入力はなくし、代わりに出力 `dmg_name` を足す。DMG の名前は `${ZIP_NAME%.zip}.dmg` で作る。
- 今の「アプリを内側から署名 → zip にして公証 → アプリに staple → 検証」はそのまま残す。その後に次を足す。
  1. 一時フォルダーに staple 済みの `Capsaicin.app` を `ditto` で写し、`ln -s /Applications Applications` を置く。
  2. `hdiutil create -volname Capsaicin -srcfolder <一時フォルダー> -fs APFS -format ULFO -ov <DMG>` で DMG を作る。
  3. DMG を `codesign --timestamp --keychain "$KEYCHAIN_PATH" --sign "Developer ID Application"` で署名する（`--options runtime` は付けない）。
  4. DMG を `notarytool` で公証する。結果を確かめてログを出す処理は、アプリの公証と同じ処理を使う。同じ処理を2か所に書き写さず、1つのステップの中のシェル関数にするなどして共有する。
  5. `xcrun stapler staple` と `xcrun stapler validate` を DMG に実行する。`spctl --assess --type open --context context:primary-signature -vv <DMG>` の出力に `source=Notarized Developer ID` が含まれることを確かめる。
- `SHA256SUMS.txt` はこのジョブでは作らない。
- DMG を `actions/upload-artifact`（今と同じ v7.0.2 の pin）に `archive: false` でアップロードする。`artifact_url` の出力は今と同じに返す。
- 後片付けのステップで、一時フォルダーと公証用の zip を消す。

### Release ワークフロー（`release.yml`）

- `preview-package` と `release-package` の zip の作成とアップロードは変えない。`Require increasing build number` も、今の zip から読むままにする。
- `sign-and-notarize` の呼び出しから `output-artifact` を外す。
- `preview-comment` には `sign-and-notarize` の出力の `dmg_name` を渡す。
- `release-appcast`: `actions/download-artifact` の `name` に DMG のファイル名を指定して受け取る。「Expected exactly the release zip」の検査は DMG に変え、`SUPublicEDKey` は DMG を `hdiutil attach -readonly -nobrowse -mountpoint <一時フォルダー>` でマウントして `Info.plist` から読む。読み終えたら成功でも失敗でも `hdiutil detach` する。appcast の検査の `expected_url` は DMG の URL にし、エラーメッセージの「zip」も直す。
- `publish`: DMG を受け取り、`SHA256SUMS.txt` を `sha256sum Capsaicin-{版}.dmg` と同じ形式（ファイル名だけを書く）で作る。attestation の対象と `gh release create` の添付を DMG にする。

### Debug preview（`debug-preview.yml`）と `preview_comment.py`

- `sign-and-notarize` の呼び出しから `output-artifact` を外し、`preview-comment` に `dmg_name` を渡す。
- `preview_comment.py` の `zip_name` と環境変数 `ZIP_NAME` を、ファイルの種類に依らない名前（`package_name`、`PACKAGE_NAME`）に変え、エラーメッセージも合わせる。テストも直す。

### 文書

- README（英語と日本語）: DMG をダウンロードして開き、`Capsaicin.app` を `Applications` のリンクへドラッグする手順にする。`SHA256SUMS.txt` と `gh attestation verify` の例も DMG にする。
- `docs/manual/release.md`: 確認用のビルドの確かめ方を、DMG を開いてアプリを「アプリケーション」へ移してから `codesign` と `spctl` を実行する形にし、DMG 自体の `spctl --assess --type open --context context:primary-signature -vv` も足す。公開物と Debug の確認用ビルドのファイル名、attestation の例、取り下げの手順3の「前の安定版の zip」（前の版は zip のこともあるので「アーカイブ」にする）を直す。
- `AGENTS.md` の `dist` の行: 署名のジョブへ渡す ad-hoc 署名の zip を作ること、公開する DMG は Release ワークフローの署名のジョブが作ることが分かる説明にする。

## 完了条件

- 上の「作り方」がすべて反映されている。
- 利用者に渡るもの（公開物、appcast、PR のコメントのリンク）に zip が残っていない。CI の中の受け渡しにだけ zip が残る。
- ワークフローの中で秘密情報を出力しない、checkout しないジョブで秘密鍵を扱う、という今の隔離を崩していない。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just check`
- DMG の作り方は、手元の Mac で ad-hoc 署名の `just build-release` の成果物を使い、上の1・2の `hdiutil create` を一時フォルダー（リポジトリの `.build/` の下）で実行して確かめる。`hdiutil attach -readonly -nobrowse -mountpoint` でマウントし、`Capsaicin.app` と `/Applications` を指す `Applications` があることを確かめ、`hdiutil detach` する。署名と公証は手元では行わない。
- ワークフローの YAML は、変えた式と参照（`needs.*.outputs.*`、入力、出力の名前）を目で追い、呼び出し側と定義側が一致していることを確かめる。
- 署名と公証の実際の動きは、PR に `S-Preview` を付けた CI でオーナーが確かめる（`HYP-SYS-006`）。

## レビュー

未レビュー。
