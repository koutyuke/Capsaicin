---
schema: decision
id: DEC-SYS-031
title: 自前の Homebrew tap に Cask を置き、GitHub Release の DMG をそのまま配る
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-SYS-001", "REQ-SYS-002", "REQ-SYS-008"]
based_on: ["DEC-SYS-019", "DEC-SYS-021", "DEC-SYS-028", "DEC-CLI-004", "EVID-SYS-001", "EVID-SYS-010"]
---

# DEC-SYS-031 自前の Homebrew tap に Cask を置き、GitHub Release の DMG をそのまま配る

## 結論

- 公開リポジトリ `koutyuke/homebrew-tap` を作り、Cask `capsaicin` を `Casks/capsaicin.rb` に置く。利用者は `brew install --cask koutyuke/tap/capsaicin` で入れる。GitHub Release から DMG を入れる方法（`DEC-SYS-028`）は変えない。
- Cask は、GitHub Release に添付した `Capsaicin-{版}.dmg` をそのまま指す。Homebrew のために別のビルドや公開物を作らない。
- Cask には次を書く。
  - `depends_on arch: :arm64` と `depends_on macos: :tahoe`（macOS 26 以上。`REQ-SYS-001`、`REQ-SYS-002`）。
  - `auto_updates true`。更新は Sparkle が行う（`DEC-SYS-019`）。
  - `livecheck` は `strategy :sparkle, &:short_version` で、安定版の appcast（`https://github.com/koutyuke/Capsaicin/releases/latest/download/appcast.xml`）を読む。
  - `app "Capsaicin.app"` と、`DEC-CLI-004` の `binary`。
  - `uninstall quit: "io.github.koutyuke.capsaicin"`。ヘルパーの登録を外す処理、`launchctl:`、root で動く `script:` は書かない。
  - `caveats` で、ヘルパーを入れた利用者は `brew uninstall` の前に設定の「ヘルパー」の「削除…」で外すよう伝える。
  - `zap trash:` に、`~/Library` の設定（`Preferences`、`Application Support`、`Caches`、`HTTPStorages` の bundle ID の項目）と、ヘルパーが書く `/Library/Application Support/io.github.koutyuke.capsaicin` を挙げる。
- Cask の版と `sha256` は、tap のワークフローが更新する。定期実行と手動実行で `livecheck` を確かめ、新しい版があれば、DMG が Capsaicin のビルドの来歴の attestation（`DEC-SYS-028`）に一致することを `gh attestation verify` で確かめてから、版と `sha256` を書き換え、tap 自身の `GITHUB_TOKEN` で既定のブランチにコミットする。Capsaicin のリポジトリには、tap に書き込む秘密情報もジョブも足さない。
- tap のワークフローは、push と PR で `brew style` と `brew audit` を実行する。
- 知名度の条件（`EVID-SYS-010`）を満たしたら、公式 Cask に出す。載ったら、tap の Cask を消し、`tap_migrations.json` で公式 Cask へ移す。

## 背景

Developer ID で署名・公証した DMG を配るようになり（`DEC-SYS-021`、`DEC-SYS-028`）、Gatekeeper の条件では公式 Cask を妨げるものがなくなった（`EVID-SYS-001`）。しかし、公式 Cask は作者が自分で出す場合に stars 225 などを求め、作成から30日未満のリポジトリを原則として受け付けない。Capsaicin のリポジトリはどちらも満たさない（`EVID-SYS-010`）。

Capsaicin は Sparkle で自分で更新し、ヘルパーのデーモンを `SMAppService` で登録する。どちらも、Homebrew がアプリを入れ替えたり消したりする操作と重なる。

## 選択肢

置き場所:

- 公式 Cask に出す。今は条件を満たさない（不採用）。
- 自前の tap に置き、条件を満たしたら公式へ移す（採用）。
- Capsaicin のリポジトリ自体を tap にする。`brew tap koutyuke/capsaicin <URL>` のように URL を渡す必要があり、アプリのリポジトリに Homebrew の規則が混ざる（不採用）。
- tap の名前を `homebrew-capsaicin` にする。Capsaicin 専用になり、ほかのアプリを置くと名前と中身が合わなくなる（不採用）。

Cask の更新:

- tap のワークフローが定期的に確かめて更新する（採用）。Capsaicin のリポジトリに秘密情報が増えず、署名や公開のジョブ（`DEC-SYS-019`、`DEC-SYS-021`）も変えない。公開から Cask の更新までは、最大で実行の間隔だけ遅れる。
- Capsaicin の Release ワークフローが、公開の後に tap へ push する。すぐに反映されるが、tap に書き込めるトークンを Capsaicin に置き、公開のジョブに外部への書き込みが増える（不採用）。
- オーナーが手で更新する。仕組みは増えないが、更新を忘れうる（不採用）。

ヘルパーの扱い:

- Cask の `uninstall` で、`launchctl:` や root の `script:` を使ってデーモンを止めて消す。`SMAppService` の登録はアプリが外すもので、外から launchd のジョブだけを消すと、バックグラウンド項目の記録と食い違う。Homebrew の操作で root の処理が増える（不採用）。
- `caveats` で、`brew uninstall` の前にアプリから外すよう伝える（採用）。README の手順と同じ順序になる。
- 何も書かない。`brew uninstall` だけを使う利用者が、ヘルパーを残したままアプリを消しやすい（不採用）。

## 理由

- 署名・公証・attestation を済ませた1つの DMG を、GitHub Release、Sparkle、Homebrew が共有するので、検証の対象が増えない。
- tap に Capsaicin のリポジトリへの権限を渡さず、Capsaicin にも tap への権限を渡さないので、片方が破られても他方を書き換えられない。tap のワークフローは attestation を確かめるので、来歴の違う DMG で Cask を更新しない。
- `auto_updates true` にすると、`brew upgrade` は `--greedy` を付けない限り Capsaicin を対象にしない（`EVID-SYS-010`）。更新の経路が Sparkle の1つにまとまる。

## 影響

- `koutyuke/homebrew-tap` のリポジトリ、Cask、ワークフローを作り、保守する。
- README と README.ja の「Homebrew」と「アンインストール」の節を、tap を公開した後に書き直す。
- Homebrew で入れた利用者のアプリは `/Applications/Capsaicin.app` にあり、Sparkle が更新する。Homebrew が記録する版は、tap の Cask が更新されるまで古いままになりうる。
- `brew uninstall` だけを使った利用者は、ヘルパーを残したままアプリを消すことがある。そのときの直し方は README の「アンインストール」の手順と同じである。
- GitHub は、公開リポジトリで活動のない状態が続くと定期実行のワークフローを止める。リリースの間が空いて止まったら、オーナーが tap の Actions で有効にし直すか、手動で実行する。

## 覆す条件

- 公式 Cask の条件を満たしたら、公式へ移す。
- Homebrew 経由で入れたアプリが Gatekeeper の検査に通らないと分かったら、公開物の作り方を見直す。
- tap の定期実行による遅れが問題になったら、更新の方法を見直す。
- アプリの更新を Sparkle 以外に任せるように変えたら、`auto_updates` を見直す。
