# リリースの手順

オーナーが GitHub Release を作る手順である。ブランチとタグの方針は `DEC-SYS-010`、ワークフローの中身は `DEC-SYS-011` にある。タグの push は外部への公開なので、エージェントは行わない。

## 前提

- 最初のリリースの前に、`HYP-HLP-003`（別の Mac でもヘルパーが署名によらず動くか）を確かめ、根拠を残している。確かめていなければリリースしない。
- リリースするコミットが `main` にあり、そのコミットの CI が成功している。

## 手順

1. `project.yml` の `MARKETING_VERSION` を新しい版にし、`CURRENT_PROJECT_VERSION` を1増やす。版は Semantic Versioning に従う。
2. `nix develop --command just check` を実行し、変更をコミットして `main` に push する。CI の成功を待つ。
3. 版の変更を含むコミットに、注釈付きのタグを付ける。タグの本文がリリースノートになる。

   ```sh
   git tag -a v0.1.0 -F release-notes.txt
   git push origin v0.1.0
   ```

4. Actions の Release ワークフローの成功を待ち、GitHub Release に `Capsaicin-{版}.zip` と `SHA256SUMS.txt` が添付されていることを確かめる。1.0.0 未満の版はプレリリースになる。
5. ダウンロードした zip が、このリポジトリのワークフローでビルドされたものかを確かめる。

   ```sh
   gh attestation verify Capsaicin-0.1.0.zip --repo koutyuke/Capsaicin
   ```

## 失敗したとき

- ランナーの一時的な不調で落ちたときは、同じワークフローを再実行する。
- ワークフローが版の不一致で落ちたときや、コードを直す必要があるときは、タグを付け直さない。`v*` のタグは削除も更新もできないので、直したコミットで次の PATCH の版を出す。
- 作成済みの GitHub Release は immutable なので、添付ファイルを差し替えられない。問題のある版は、リリースノートでそのことを知らせ、次の版を出す。
