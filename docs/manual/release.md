# リリースの手順

オーナーがリリース用の PR を確認し、GitHub Release を公開する手順である。ブランチ、バージョン、ラベルの規則は `DEC-SYS-014`、PR の検査と公開の仕組みは `DEC-SYS-015`、プレリリースの決め方は `DEC-SYS-016` を参照する。

## 前提

- リリースの流れを試すときは、試運転用の分岐を足さず、`0.0.x` のバージョンで本番と同じ流れを通す。
- Sparkle 対応版を初めて公開する前に、オーナーが次の署名鍵を用意する。更新の配信の仕組みは `DEC-SYS-019` を参照する。

## 更新の署名鍵を用意する（初回だけ）

オーナーが Mac のターミナルで行う。Xcode の Swift と、このリポジトリの Actions secret を登録できる GitHub CLI の認証が必要である。ログインキーチェーンを使う Sparkle の `generate_keys` は実行しない。秘密鍵を画面やログに出さないよう、シェルのトレース（`set -x`）を無効にしておく。

1. 所有者だけが読める一時フォルダーに、32 バイトの seed を base64 で保存する。

   ```sh
   umask 077
   key_dir="$(mktemp -d "${TMPDIR:-/tmp}/capsaicin-sparkle.XXXXXX")"
   head -c 32 /dev/urandom | base64 > "$key_dir/sparkle-ed-key.txt"
   ```

2. 次を `$key_dir/derive.swift` に保存する。標準入力の seed から、公開鍵だけを出力するスクリプトである。

   ```swift
   import CryptoKit
   import Foundation

   let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
       .trimmingCharacters(in: .whitespacesAndNewlines)
   guard let seed = Data(base64Encoded: input), seed.count == 32 else {
       fatalError("seed must be 32 bytes base64")
   }
   let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
   print(key.publicKey.rawRepresentation.base64EncodedString())
   ```

   ```sh
   xcrun swift "$key_dir/derive.swift" < "$key_dir/sparkle-ed-key.txt"
   ```

   表示された公開鍵を `project.yml` の `SPARKLE_PUBLIC_ED_KEY` に設定する。Release の `Info.plist` の `SUPublicEDKey` に入る値である。秘密鍵はリポジトリに入れない。

3. 同じ seed を Actions secret に登録する。

   ```sh
   gh secret set SPARKLE_ED_PRIVATE_KEY --repo koutyuke/Capsaicin < "$key_dir/sparkle-ed-key.txt"
   ```

4. `sparkle-ed-key.txt` の内容を、パスワードマネージャーと、暗号化したオフラインの外部メディアの2か所に控える。それぞれから取り出せることを確かめてから、一時フォルダーを片付ける。

   **秘密鍵をなくすと、以後の更新は利用者がアプリを手で入れ直すしかない。** Actions secret から秘密鍵を読み戻すことはできない。

   ```sh
   trash "$key_dir"
   unset key_dir
   ```

   ゴミ箱に移したこの一時フォルダーを Finder で選び、「今すぐ削除」で平文のファイルを消す。鍵をコピーしたクリップボードやエディターの保存内容にも残さない。

## 通常のリリース

1. `develop` で、エージェントにスキル `capsaicin-release` を使ってリリースの準備を進めるよう依頼する。
2. エージェントが示したバージョン、プレリリースにするか、PR の本文を確かめる。問題がなければ、ブランチの push と PR の作成を承認する。プレリリースにするかは、マージの前なら PR の `S-Prerelease` を付け外しして変えられる。
3. PR のコメントから確認用のビルドをダウンロードし、実機で確かめる。
4. 必要な修正を PR の本文に反映し、PR をマージする。マージした時点の本文がリリースノートになる。
5. Release ワークフローの成功を待つ。GitHub Release が公開され、`Capsaicin-{バージョン}.zip`、`SHA256SUMS.txt`、`appcast.xml` が添付されていることを確かめる。プレリリースにも `appcast.xml` は付くが、アプリに配信されるのは latest の安定版だけである。
6. zip をダウンロードし、このリポジトリのワークフローでビルドされたものかを確かめる。

   ```sh
   gh attestation verify Capsaicin-0.1.0.zip --repo koutyuke/Capsaicin
   ```

7. 「戻しマージ」へ進む。

v0.1.0 の利用者には、最初の Sparkle 対応版を手で入れ替えてもらう。v0.1.0 にはアプリ内の更新の仕組みがない。

## 緊急の修正

1. `main` から `hotfix/<内容>` を切り、リリース済みのバージョンに必要な修正を入れる。
2. `hotfix/<内容>` で、エージェントにスキル `capsaicin-release` を `patch` で使うよう依頼する。
3. 「通常のリリース」の手順2から7へ進む。

## 戻しマージ

1. `develop` に `origin/main` を merge commit で取り込み、`develop` を push する。
2. 開いている `release/*` があれば、そのブランチにも `origin/main` を merge commit で取り込み、push する。
3. `project.yml` のバージョンの行が競合したら、取り込む側のブランチ（`develop` または `release/*`）のバージョンを採る。

次の公開時には、zip 内の `CFBundleVersion` が latest のタグの `project.yml` にある `CURRENT_PROJECT_VERSION` より大きい必要がある。hotfix の戻しマージで同じ番号になった場合も、Release ワークフローが公開を止める。`MARKETING_VERSION` とは別に、リリース用ブランチの `CURRENT_PROJECT_VERSION` を latest より大きくしてからマージする。

## 問題のある版を取り下げる

取り下げると、まだ更新していない利用者への配信が止まる。更新済みの利用者の版は戻らないので、その利用者には次の PATCH の版を出して直す。

1. GitHub の Releases で問題のある版を開き、編集画面で「Set as a pre-release」を有効にして保存する。タグや添付ファイルは削除しない。
2. 前の安定版が「Latest」と表示され、その版に `appcast.xml` が添付されていることを確かめる。別の版が latest なら、戻す安定版の編集画面で「Set as the latest release」を選んで保存する。
3. `https://github.com/koutyuke/Capsaicin/releases/latest/download/appcast.xml` を開き、1件の項目が前の安定版の zip を指していることを確かめる。

最初の Sparkle 対応版を取り下げて v0.1.0 に戻す場合、戻り先には `appcast.xml` がないため、更新の確認は失敗する。配信を再開するには、修正版に署名済みの `appcast.xml` を添えて安定版として公開する。

## 失敗したとき

- ランナーの一時的な不調でワークフローが失敗したときは、同じワークフローを再実行する。
- PR をマージした後にコードを直す必要があるときは、`v*` のタグを削除も更新もせず、次の PATCH のバージョンを出す。
- 公開済みの GitHub Release は immutable なので、添付ファイルを差し替えられない。問題のあるバージョンはリリースノートで知らせ、次の PATCH のバージョンを出す。
