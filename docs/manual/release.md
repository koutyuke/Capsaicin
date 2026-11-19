# リリースの手順

オーナーがリリース用の PR を確認し、GitHub Release を公開する手順である。ブランチ、バージョン、ラベルの規則は `DEC-SYS-014`、PR の検査と公開の仕組みは `DEC-SYS-015`、プレリリースの決め方は `DEC-SYS-016` を参照する。

## 前提

- リリースの流れを試すときは、試運転用の分岐を足さず、`0.0.x` のバージョンで本番と同じ流れを通す。
- Sparkle 対応版を初めて公開する前に、オーナーが次の署名鍵を用意する。更新の配信の仕組みは `DEC-SYS-019` を参照する。
- Developer ID で署名した版を初めて公開する前に、オーナーが「Developer ID の証明書と公証用のキーを登録する」の secret を登録する。署名と公証の方針は `DEC-SYS-021` を参照する。

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

## Developer ID の証明書と公証用のキーを登録する（初回と、証明書を作り直したとき）

オーナーが Mac のターミナルで行う。1Password に保管した Developer ID Application 証明書の `.p12`、その書き出し用パスワード、App Store Connect の Team Key の `.p8`、Key ID、Issuer ID が必要である。シェルのトレース（`set -x`）を無効にし、値を画面やシェルの履歴へ書かない。

1. 所有者だけが読める一時フォルダーを作る。

   ```sh
   umask 077
   key_dir="$(mktemp -d "${TMPDIR:-/tmp}/capsaicin-developer-id.XXXXXX")"
   ```

   1Password から `.p12` を `$key_dir/developer-id.p12`、`.p8` を `$key_dir/AuthKey.p8` に書き出し、所有者だけが読めることを確かめる。

   ```sh
   chmod 600 "$key_dir/developer-id.p12" "$key_dir/AuthKey.p8"
   ```

2. ファイルの内容を標準入力から Actions secret に登録する。base64 の内容や Team Key を画面へ表示したり、別の平文ファイルへ保存したりしない。

   ```sh
   base64 -i "$key_dir/developer-id.p12" |
     gh secret set DEVELOPER_ID_P12_BASE64 --repo koutyuke/Capsaicin
   gh secret set NOTARY_API_KEY --repo koutyuke/Capsaicin < "$key_dir/AuthKey.p8"
   ```

3. 次の3つは、各コマンドの対話入力へ 1Password から値を貼り付ける。値をコマンドの引数に書かない。

   ```sh
   gh secret set DEVELOPER_ID_P12_PASSWORD --repo koutyuke/Capsaicin
   gh secret set NOTARY_API_KEY_ID --repo koutyuke/Capsaicin
   gh secret set NOTARY_API_ISSUER_ID --repo koutyuke/Capsaicin
   ```

4. 一時フォルダーを片付ける。

   ```sh
   trash "$key_dir"
   unset key_dir
   ```

   ゴミ箱に移した一時フォルダーを Finder で選び、「今すぐ削除」で平文のファイルを消す。クリップボードにも値を残さない。

Developer ID Application 証明書の有効期限は 2027年12月17日である。期限の前に証明書を作り直し、`.p12` と `DEVELOPER_ID_P12_BASE64`、`DEVELOPER_ID_P12_PASSWORD` を差し替える。

## 通常のリリース

1. `develop` で、エージェントにスキル `capsaicin-release` を使ってリリースの準備を進めるよう依頼する。
2. エージェントが示したバージョン、プレリリースにするか、PR の本文を確かめる。問題がなければ、ブランチの push と PR の作成を承認する。プレリリースにするかは、マージの前なら PR の `S-Prerelease` を付け外しして変えられる。
3. PR の `Release preview` コメントが `ready` になったら、Download から確認用のビルドをダウンロードする。コメントは種類ごとに1つで、ビルドの前に `building`、成功時に `ready`、失敗時に `failed` へ書き換わる。`ready` にはコミット、Release の版、署名と公証の状態、artifact の期限（7日間）、実行のログが表示される。Release の確認用ビルドは、インストール済みの正式版を置き換える。

   Developer ID で署名され、公証されていることと、実機で既存の機能が動くことを確かめる。zip を展開し、次を実行する。`codesign` の出力に `Authority=Developer ID Application`、`spctl` の出力に `source=Notarized Developer ID` が含まれている必要がある。

   ```sh
   codesign -dv --verbose=2 Capsaicin.app 2>&1
   spctl --assess --type execute -vv Capsaicin.app
   ```
4. 必要な修正を PR の本文に反映し、PR をマージする。マージした時点の本文がリリースノートになる。
5. Release ワークフローの成功を待つ。GitHub Release が公開され、`Capsaicin-{バージョン}.zip`、`SHA256SUMS.txt`、`appcast.xml` が添付されていることを確かめる。プレリリースにも `appcast.xml` は付くが、アプリに配信されるのは latest の安定版だけである。
6. zip をダウンロードし、このリポジトリのワークフローでビルドされたものかを確かめる。

   ```sh
   gh attestation verify Capsaicin-0.1.0.zip --repo koutyuke/Capsaicin
   ```

7. 「戻しマージ」へ進む。

v0.1.0 の利用者には、最初の Sparkle 対応版を手で入れ替えてもらう。v0.1.0 にはアプリ内の更新の仕組みがない。

## develop への PR の Debug 確認用ビルド

オーナーが GitHub に `S-Preview` ラベルを作り、同じリポジトリのブランチから `develop` へ向けた PR に付ける（`DEC-SYS-023`）。署名と公証には、上記の Developer ID と公証用の5つの secret を使う。外部リポジトリからの PR では動かない。

```text
S-Preview を付ける／ラベルがある PR を更新する
  → Debug preview: building
  → ad-hoc ビルド → 別ジョブで署名・公証
  → Debug preview: ready または failed
```

`Debug preview` コメントの Download から `Capsaicin-debug-pr{PR番号}-{コミットの先頭7桁}.zip` を取得する。bundle ID は `io.github.koutyuke.capsaicin.debug` で、正式版と同時に入れられる。Sparkle による更新は無効である。artifact は7日間保持される。

ラベルを付けたまま head を更新すると作り直し、同じ PR の古い実行を取り消す。取り消した実行は結果のコメントを更新しない。手動で取り消して後続の実行がない場合は `building` のままなので、コメントの実行ログを確認する。ほかのラベルを付けただけでは作り直さない。

初回は、コメントが増えずに `building` から `ready` へ変わること、コミットとファイル名が PR の head に一致すること、zip の署名と公証が「通常のリリース」の手順3のコマンドで確認できることを確かめる。実機では正式版との共存、更新が無効であること、既存の機能を確認する。push による作り直しと、失敗時の `failed` 表示も確かめる。Release の確認用ビルドでも、同じ状態の切り替えと既存コメントの更新を確認する。

## 緊急の修正

1. `main` から `hotfix/<内容>` を切り、リリース済みのバージョンに必要な修正を入れる。
2. `hotfix/<内容>` で、エージェントにスキル `capsaicin-release` を `patch` で使うよう依頼する。
3. 「通常のリリース」の手順2から7へ進む。

## 戻しマージ

1. `develop` に `origin/main` を merge commit で取り込み、`develop` を push する。
2. 開いている `release/*` があれば、そのブランチにも `origin/main` を merge commit で取り込み、push する。
3. `project.yml` のバージョンの行が競合したら、`MARKETING_VERSION` は取り込む側のブランチ（`develop` または `release/*`）の値を採り、`CURRENT_PROJECT_VERSION` は `origin/main` の値に1を足す。

リリース用ブランチの準備中に hotfix を公開すると、両方が同じ `CURRENT_PROJECT_VERSION` を持つ。そのまま公開すると Sparkle が更新を見つけられないので、PR policy は `main` への PR の `CURRENT_PROJECT_VERSION` が `main` の値より大きくなければ失敗し、マージを止める。

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
