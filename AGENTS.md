# AGENTS.md

このリポジトリでエージェントが作業するときの前提。

## このリポジトリは何か

Capsaicin は、Mac のスリープを種類ごとに止め、止めている間は Caps Lock の LED を点灯させるメニューバーアプリである。Caps Lock の入力状態は変えず、LED だけを制御する。何を作るかは [`docs/product/`](docs/product/)、満たすべきことは [`docs/meta/requirements/`](docs/meta/requirements/)、振る舞いは [`docs/specs/`](docs/specs/) にある。

文書を足したり直したりする前に、[`docs/documentation-management.md`](docs/documentation-management.md) を読む。新しい ID は PM が割り当てる。作業の依頼に含まれていない ID を自分で振らない。

## 作業の進め方

- 作業はチケット（[`docs/meta/tasks/`](docs/meta/tasks/)）単位で進める。チケットの「範囲」に書かれたファイルだけを変更する。範囲外の変更が必要だと分かったら、変更せずに報告する。
- PM の指示がない限り、`git commit` や `git push` をしない。変更は作業ツリーに残し、PM がレビューしてからコミットする。
- ブランチの規則は [`DEC-SYS-014`](docs/meta/decisions/DEC-SYS-014-git-flow-branches-and-release-pull-requests.md) に従う。チケットで指示されたときは、作業ブランチを push し、`develop` への PR を作ってよい。スキル `capsaicin-release` による、オーナーが承認した `release/*` または `hotfix/*` の push を除き、`main`、`develop`、`release/*`、`hotfix/*` への push と、タグの作成と push はしない。マージはオーナーだけが行う。
- リリースの準備はスキル `capsaicin-release` で行う。push と PR の作成はオーナーの承認を得てから行う。
- 判断に迷ったら、推測で埋めずに報告する。確かめていない前提は仮説（`HYP-*`）として扱う。

## 破ってはいけないもの

1. **開発機に永続的なシステム変更をしない。** `sudo`、`pmset` の設定変更、`launchctl` の実行、LaunchAgents・LaunchDaemons・sudoers・PrivilegedHelperTools のシステム配置先への書き込み、ヘルパーのインストールを、ビルドでもテストでも手作業でも行わない。通常の開発ツールによるキャッシュ書き込みや、Xcode によるビルド済み `.debug` アプリの LaunchServices 登録は、この禁止に含めない。禁止対象を確かめる必要があるときは、手順を書いて PM に渡す。`scripts/manual/` はアプリの起動とプロセスの停止を行うオーナー専用の補助なので、エージェントは実行しない。
2. **Caps Lock の入力状態を変えない。** LED の表示だけを扱う。
3. **root で動くコードを増やさない。** ヘルパーが受け付けるのは決められたサブコマンドだけにする。ヘルパーにシェル、任意のパス、任意の環境変数を通さない。
4. **本番コードに `REQ-*` と `SPEC-*` を書かない。** 仕様との対応はテスト名が持つ。
5. **秘密情報をコードやログに書かない。**

## 開発環境

Apple Silicon の Mac、macOS 26 以上、Xcode 27.2（Swift 6.4）、flakes が有効な Nix を前提とする。`/usr/bin/xcode-select -p` が Xcode の Developer ディレクトリを指すことを確認する。プロジェクトから Xcode の選択やシステム設定は変更しない。

`nix develop` で devShell に入る。エージェントはシェルの状態に依存しないよう、リポジトリのルートから `nix develop --command just …` の形で実行する。`.envrc` は `use flake` だけを持つ。direnv は devShell に含めない。自動適用したい利用者が開発機に別途用意し、`direnv allow` を判断する。エージェントは実行しない。

Nix は以下のツールを `flake.lock` で固定して供給する。Swift コンパイラーと macOS SDK は Nix から入れず、ホストの `/usr/bin/xcrun` と `/usr/bin/xcodebuild` を使う。devShell は `mkShellNoCC` とし、`DEVELOPER_DIR` と `SDKROOT` は設定しない。SwiftLint に必要な Xcode のツールチェーン指定は、その呼び出しにだけ渡す。

| ツール                                 | 用途                                                                |
| -------------------------------------- | ------------------------------------------------------------------- |
| just、XcodeGen                         | コマンドの入口、`project.yml` からの Xcode プロジェクト生成         |
| SwiftFormat（nicklockwood）、SwiftLint | Swift の整形、整形以外の lint                                       |
| clang-tools                            | C の clang-format                                                   |
| Prettier、markdownlint-cli2            | Markdown・YAML・JSON の整形、Markdown の lint                       |
| Taplo、shfmt、ShellCheck               | TOML の整形、シェルの整形と lint                                    |
| nixfmt、statix、deadnix                | Nix の整形、誤りや未使用の定義の検出                                |
| treefmt（treefmt-nix）                 | 各言語の formatter をまとめ、`nix fmt` と `just fmt` で共有する入口 |
| Python 3、PyYAML                       | 文書の TOML・YAML Front Matter・ID の検査と、検査スクリプトのテスト |
| Ruff                                   | Python スクリプトの整形と lint                                      |
| lefthook                               | Git フックの実行と、実行環境に lefthook があることの確認            |

アプリは `Sources/Capsaicin/`、CLI は `Sources/capsaicin-cli/`、C ヘルパーは `Sources/capsaicin-helper/` に置く。SwiftPM の3モジュールは `Packages/CapsaicinKit/` に置く。ソースはディレクトリ単位で指定しているので、既存フォルダーへの Swift ファイル追加で `project.yml` を編集する必要はない。ビルドとアプリのテストは必ずプロジェクト生成を先に実行する。

String Catalog は機能フォルダーごとに別のテーブルを置き、`Text` の `tableName` で指定する。雛形は `Sources/Capsaicin/MenuBar/MenuBar.xcstrings`、開発言語は `en` である。すべてのキーに英語と日本語の値を持たせる。Xcode は String Catalog を開くたびに独自の形（`"key" : value`、末尾の改行なし）で書き直すので、その形を正として自動整形の対象から除く。手で編集するときもこの形に合わせる。`bundle.localizedString(forKey:)` などでコードから動的に引くキーは、Xcode がコードから見つけられず `stale` を付けるので、`"extractionState" : "manual"` を付ける。`fmt-check` は `stale` のキーが残っていると失敗する。CLI の内部ターゲット名は `CapsaicinCLI` とする。アプリ名と大小文字だけが違うターゲット名にすると、中間出力が衝突するためである。生成物の名前は `capsaicin` のままである。

CLI とヘルパーはアプリの `Contents/Helpers/` に埋め込む。どちらもアプリに付属する非公開の実行ファイルなので同じ場所にまとめ、`Contents/MacOS/Capsaicin` との衝突も避ける。ヘルパーをシステムにインストールしたり、特権を付けたりはしない。

## エージェントのスキル

スキルの実体は `.agents/skills/` に置き、Claude Code が読む `.claude/skills/` からは相対パスの symlink を張る。実体、symlink、`skills-lock.json` はすべてコミットする。`skills-lock.json` は取得元のコミットを固定しておらず、lock から復元すると取得元の最新が入る。そのため実体をリポジトリに持ち、変更を差分でレビューできるようにする。未追跡のファイルは新しい worktree に入らないので、コミットしておけば委譲先の worktree でも同じスキルを使える。

- 外部のスキル（`skills-lock.json` に載っているもの）は `bunx skills add <source>` で入れ、`bunx skills update` で更新する。手では編集しない。手で直しても次の更新で上書きされる。
- 追加と更新は PM が判断する。更新したら差分を読み、意図しない指示が混ざっていないことを確かめてからコミットする。
- 自作のスキル（`skills-lock.json` に載っていないもの）は `bunx skills update` の対象外なので、他のファイルと同じく直接編集してレビューする。
- `.agents/skills/` は自動整形と Markdown lint の対象から除く。外部のスキルを整形すると、取得元との差分が更新のたびに生じるためである。自作のスキルの品質はレビューで確かめる。

## 検証

変更後は `nix develop --command just check`、アプリの生成確認には `nix develop --command just build` を実行する。署名は ad-hoc で、Debug の bundle ID は `io.github.koutyuke.capsaicin.debug`、Release は `io.github.koutyuke.capsaicin` である。

| レシピ             | 実行すること                                                                                                                                        |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `gen`              | `project.yml` から `Capsaicin.xcodeproj` を生成する                                                                                                 |
| `build`            | `gen` の後、arm64・macOS SDK を明示して Debug アプリをビルドする                                                                                    |
| `build-release`    | `gen` の後、Release 構成のアプリをビルドする                                                                                                        |
| `dist`             | `build-release` の後、配布用の zip と `SHA256SUMS.txt` を `.build/dist/` に作る                                                                     |
| `prepare-release`  | `develop`（`patch` なら `hotfix/*`）から、版を上げたリリース用のコミットを手元に作り、材料を `.build/release/` に書き出す。push はしない            |
| `test`             | `test-scripts`、`test-package`、`test-app` を実行する                                                                                               |
| `test-scripts`     | 一時フィクスチャで文書・整形検査スクリプトをテストする。実際の formatter による Swift・JSON の不整形検出も含む                                      |
| `test-package`     | Xcode の Swift で3モジュールの Swift Testing を実行する                                                                                             |
| `test-app`         | `gen` の後、アプリを起動しないテストでバンドルと埋め込んだ実行ファイルを検査する                                                                    |
| `fmt`              | treefmt で各言語と justfile を整形する。`nix fmt` も同じ設定・実行ファイルを使う                                                                    |
| `fmt-check`        | 一時コピー上で treefmt を実行し、元のファイルを変えずに各言語と justfile の整形差分を検出する。String Catalog に `stale` のキーがないことも確かめる |
| `lint-code`        | SwiftLint、markdownlint-cli2、ShellCheck、Ruff、statix、deadnix を実行する                                                                          |
| `lint-docs`        | `docs/documentation-management.md` が定める文書の構造と参照を検査する                                                                               |
| `lint-build-tools` | CI が Nix を使わずに入れる `just` と XcodeGen の版（`.github/build-tools.env`）が `flake.lock` の版と一致するかを確かめる                           |
| `lint`             | `lint-code`、`lint-docs`、`lint-build-tools` を実行する                                                                                             |
| `check`            | `fmt-check`、`lint`、`test` を順に実行する                                                                                                          |

文書の移行と衝突しないよう、`docs/` は自動整形と Markdown lint の対象から除き、`lint-docs` で構造を検査する。`*.tpl.*` は文書の構造検査から除く。移行中の文書で検査が落ちても、チケットの範囲外のファイルを直してはならない。

アプリは `.build/xcode/Build/Products/Debug/Capsaicin.app`、DerivedData は `.build/xcode/`、Xcode の SwiftPM 作業領域は `.build/spm/`、`swift test` の作業領域は `.build/swiftpm/` に置き、worktree ごとに分ける。検査スクリプトのフィクスチャ、整形検査の一時コピー、Python の bytecode（`PYTHONPYCACHEPREFIX`）、Ruff のキャッシュも `.build/` に置く。生成した `.xcodeproj`、`.build/`、`.direnv/` は Git に入れない。

開発ツールが通常のキャッシュをユーザー領域に書くことと、Xcode がビルド済み `.debug` アプリを LaunchServices に登録することは許可する。`HOME` や `CFFIXED_USER_HOME` は変更せず、SwiftPM と Swift マクロの標準の sandbox を使う。SwiftFormat には treefmt から `--cache ignore` を渡し、ユーザー領域にキャッシュを書かせない。

この許可はシステム設定や常駐処理の変更には及ばない。`sudo`、`pmset` の設定変更、`launchctl` は実行しない。`~/Library/LaunchAgents`、`/Library/LaunchAgents`、`/Library/LaunchDaemons`、`/etc/sudoers`、`/etc/sudoers.d`、`/Library/PrivilegedHelperTools` への書き込みと、ヘルパーのインストールは禁止する。

Git フックが必要なら `nix develop --command lefthook install` を実行する。pre-commit は `fmt-check` と `lint` だけで、自動整形、自動ステージ、テストは行わない。treefmt の `--ci` はファイルを書き換えるため、検査として直接使わず `just fmt-check` を使う。
