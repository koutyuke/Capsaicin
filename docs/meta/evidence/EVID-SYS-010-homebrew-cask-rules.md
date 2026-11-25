---
schema: evidence
id: EVID-SYS-010
title: Homebrew の公式 Cask の掲載条件と、自前の tap の Cask で使える定義
observed_on: 2026-11-26
environment: Web 上の文書（Homebrew Documentation）、Homebrew 7.0.16 のソースとコマンドのヘルプ、GitHub の koutyuke/Capsaicin リポジトリと v0.2.0 の Release
sources: ["https://docs.brew.sh/Package-Acceptance-Policy", "https://docs.brew.sh/Acceptable-Casks", "https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap", "https://docs.brew.sh/Cask-Cookbook", "https://docs.brew.sh/Brew-Livecheck", "https://docs.brew.sh/Homebrew-Security-and-Supply-Chain", "https://github.com/Homebrew/brew/blob/7.0.16/Library/Homebrew/macos_version.rb", "https://github.com/Homebrew/brew/blob/7.0.16/Library/Homebrew/cask/dsl/depends_on.rb", "https://github.com/Homebrew/brew/blob/7.0.16/Library/Homebrew/trust.rb", "https://github.com/koutyuke/Capsaicin/releases/tag/v0.2.0"]
---

# EVID-SYS-010 Homebrew の公式 Cask の掲載条件と、自前の tap の Cask で使える定義

## 確かめた事実

公式 Cask（homebrew/cask）の掲載条件:

- GitHub のプロジェクトは「forks 30、watchers 30、stars 75」のどれかを満たす必要がある。リポジトリの持ち主やその関係者が自分で出す場合は「forks 90、watchers 90、stars 225」のどれかになる。作成から30日未満のリポジトリは、原則として対象外である（Package Acceptance Policy）。
- 新しく載せるものには、動く `livecheck` が必要である（Package Acceptance Policy）。
- 条件を満たさないソフトウェアは、自前の tap で配れる（Package Acceptance Policy）。
- Homebrew は Cask でダウンロードしたものに quarantine の属性を付け、Gatekeeper に Developer ID の署名と公証を検査させる。既定の macOS の設定で検査に通ることを求める（Homebrew Security and Supply Chain、Acceptable Casks）。

確かめた日の koutyuke/Capsaicin は、2026-11-13 に作られ、stars・forks・watchers がどれも 0 だった。

自前の tap:

- リポジトリ名を `homebrew-` で始めると、`brew install user/tap/cask` の短い形で入れられる。Cask は tap の最上位の `Casks` ディレクトリに置く（How to Create and Maintain a Tap）。
- 公式でない tap は、既定では利用者が明示的に信頼する必要がある（How to Create and Maintain a Tap）。
- Homebrew 7.0.16 の `trust.rb` では、信頼は `brew trust` が `~/.homebrew/trust.json`（`XDG_CONFIG_HOME` があればその下）に記録する。信頼していない tap の Cask でも、`install`、`reinstall`、`upgrade` の引数に完全な名前（`user/tap/cask`）を書いたときは読み込める。

Cask の定義（Cask Cookbook、Brew Livecheck、Homebrew 7.0.16 のソースとヘルプ）:

- `binary "#{appdir}/Foo.app/Contents/..."` で、アプリの中の実行ファイルへのリンクを Homebrew の `bin` に置ける。
- `auto_updates true` は、アプリが自分で更新する（アプリのメニューに「アップデートを確認」のような項目があり、Web ページを開くだけではない）ことを示す。`brew upgrade --help` によると、`auto_updates true` の Cask は、`--greedy` か `--greedy-auto-updates` を付けない限り `brew upgrade` の対象から外れる。
- `uninstall` の `quit:` は、bundle ID を指定してアプリに終了の Apple Event を送る。`zap` は `brew uninstall --zap` のときだけ動き、`~/Library` の設定やキャッシュを消す。`trash:` を `delete:` より優先する。
- `depends_on arch: :arm64` は Apple Silicon を求める。`depends_on macos:` は macOS の版の記号を取る。`macos_version.rb` は macOS 26 を `tahoe` とし、`cask/dsl/depends_on.rb` は `depends_on macos:` に比較の記号がなければ `>=` として扱う。
- `livecheck` の `strategy :sparkle` は Sparkle の appcast の URL を読み、`&:short_version` で `CFBundleShortVersionString` の値だけを返す。`livecheck` を使う Sparkle のアプリでは、`brew audit --online` が、アプリの `LSMinimumSystemVersion` と appcast の `minimumSystemVersion` を `depends_on macos:` と比べる。

v0.2.0 の公開物:

- `Capsaicin-0.2.0.dmg` の SHA-256 は `56c09f1e339ca37e45ffc59d71be48dd888cb437c1645b1798e045ef5a027b1c` で、`SHA256SUMS.txt` の値と一致した。
- `gh attestation verify Capsaicin-0.2.0.dmg --repo koutyuke/Capsaicin --signer-workflow koutyuke/Capsaicin/.github/workflows/release.yml` は通り、署名者は `https://github.com/koutyuke/Capsaicin/.github/workflows/release.yml@refs/heads/main` だった。
- `appcast.xml` の `sparkle:shortVersionString` は `0.2.0`、`sparkle:minimumSystemVersion` は `26.0` だった。

## 確かめ方

上の文書を Web で読んだ。Homebrew 7.0.16 のソース（`Library/Homebrew/` の `macos_version.rb`、`cask/dsl/depends_on.rb`、`trust.rb`）を読み、`brew upgrade --help` と `brew trust --help` を実行した。リポジトリの数値は `gh repo view koutyuke/Capsaicin --json stargazerCount,forkCount,watchers,createdAt` で読んだ。v0.2.0 の公開物は `gh release download v0.2.0 --repo koutyuke/Capsaicin` で取り、`shasum -a 256` と上の `gh attestation verify` を実行し、`appcast.xml` を読んだ。

## 適用範囲

Capsaicin を自前の tap で配るか、公式 Cask に出すかの判断と、Cask の定義の根拠に使ってよい。リポジトリの数値は確かめた日のものである。

## 未確認のこと

- Capsaicin の DMG が、Homebrew 経由で入れたときに Gatekeeper の検査に通ること。Developer ID で署名・公証・staple した DMG とアプリ（`DEC-SYS-028`）が `spctl --assess` に通ることからの推論で、`brew install` では確かめていない。
- 自前の tap の Cask が `brew audit` に通ること。
- 信頼していない tap から入れた Cask を、`brew uninstall --cask capsaicin` のように短い名前で消せるか。
