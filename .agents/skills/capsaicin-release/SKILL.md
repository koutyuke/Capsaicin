---
name: capsaicin-release
description: Capsaicin のリリース準備を進めるときに使う。オーナーから「リリースして」「リリースの準備をして」「hotfix を出して」などと頼まれたら、通常のリリースと緊急の修正のどちらでも使う。材料の作成、互換性の確認、英語と日本語のリリースノート、承認後の push と main 向け PR、マージ後の戻しマージを扱う。
---

# capsaicin-release

ブランチ、ラベル、リリースの流れは `docs/meta/decisions/DEC-SYS-014-git-flow-branches-and-release-pull-requests.md` に、版のどの部分を上げるかは `docs/meta/decisions/DEC-SYS-022-release-kind-chosen-by-owner.md` に従う。このスキルではその判断を繰り返さず、実行する手順だけを定める。

GitHub 上で PR を `main` や `develop` にマージせず、タグの作成と push、GitHub の設定変更も行わない。リリースブランチの push と PR の作成は、まとめて承認された場合だけ行う。戻しマージの push には別の承認を得る。

## 1. 準備

通常のリリースでは、版のどの部分（`major`、`minor`、`patch`）を上げるかをオーナーに確かめる。依頼に含まれていなければ尋ね、自分で決めない。`develop` で次を実行する。

```bash
nix develop --command just prepare-release {major|minor|patch}
```

緊急の修正では `hotfix/*` で次を実行する。

```bash
nix develop --command just prepare-release patch
```

コマンドが止まったら、表示された理由をオーナーに伝えて作業を終える。前提の確認を省く、手作業で版を変えるなど、止まった原因を自分で回避しない。

## 2. 材料を読む

コマンドが表示した版と `.build/release/v{版}.json` を読む。以降は JSON の `version`、`previous_tag`、`kind`、`branch`、`pull_requests`、`commits` を材料にする。

## 3. 互換性を確かめる

通常のリリースでは `pull_requests` の各 PR について `gh pr diff <番号>` を実行する。差分と材料の `labels`、`breaking` を照らし合わせ、`I-Breaking` がないのに次を非互換に変えていないかを確かめる。材料の `kind` が `patch` なら、互換性を壊す変更が1つもないことを確かめる。

- CLI の引数: `Packages/CapsaicinKit/Sources/CapsaicinIPC/CLIArguments.swift`
- CLI の実行と出力: `Sources/capsaicin-cli/main.swift`、`Sources/capsaicin-cli/CLIRunner.swift`、`Sources/capsaicin-cli/CLIOutput.swift`
- CLI の終了コード: `Packages/CapsaicinKit/Sources/CapsaicinIPC/ExitCode.swift`
- 設定の保存形式: `Packages/CapsaicinKit/Sources/CapsaicinCore/Settings/Settings.swift`、`Packages/CapsaicinKit/Sources/CapsaicinCore/Settings/SettingValues.swift`、`Packages/CapsaicinKit/Sources/CapsaicinCore/Settings/LidCloseDisplay.swift`
- 設定の保存処理: `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Settings/UserDefaultsSettingsStore.swift`
- 別に保存するホットキー: `Sources/Capsaicin/Hotkey/HotkeyController.swift`

名前の変更だけで判断せず、以前の引数が通らなくなる、stdout・stderr・終了コードの意味が変わる、保存済みの設定を同じ意味で読めなくなるなど、利用者との互換性で判断する。ヘルパーのサブコマンドは確認の対象にしない。

緊急の修正では `git diff origin/main...HEAD` を読み、機能の追加や上の互換性を壊す変更が含まれていないかを確かめる。含まれていれば、通常のリリースで出すべき変更なので、オーナーに伝えて止める。

疑わしい PR があれば、PR 番号、疑わしい差分、現在のラベルをオーナーに示して判断を仰ぎ、そこで止める。オーナーがラベルを直した場合は、通常のリリースで作った `release/v{版}` を削除し、手順 1 からやり直す。

## 4. リリースノートを書く

`T-Refactor`、`T-Test`、`T-Chore`、`T-Documentation` の PR は載せない。載せる項目は要対応（`I-Breaking`）、機能（`T-Feature`、`T-Enhancement`）、修正（`T-Bug`）の順に並べる。各行は利用者に起きることを書き、PR のタイトルを写さない。緊急の修正では `commits` から同じように利用者向けの文を書く。

次の形で英語と日本語の両方を書く。総括は下書きを本文に置き、HTML コメントにはしない。

```md
## English

{総括}

- **Action required:** … (#20)
- Added … (#12)
- Fixed … (#15)

---

## 日本語

{総括}

- **要対応:** … (#20)
- …を追加しました。 (#12)
- …を修正しました。 (#15)

---

**Full Changelog**: https://github.com/koutyuke/Capsaicin/compare/{前回のタグ}...v{版}
```

日本語は `~/.claude/skills/yomiyasu/SKILL.md` に従って推敲する。変更に関係する仕様と判断を読み、`DEC-UI-011` などで定めた画面の用語に合わせる。

## 5. オーナーに見せる

次をオーナーに見せ、ブランチの push と PR の作成をまとめて承認してよいか尋ねる。明確な承認が得られるまでは、どちらも行わない。

- 版とリリースの種類
- プレリリースにするか。`DEC-SYS-016` に従って案を示し、オーナーに決めてもらう
- リリースノートの全文
- 材料の一覧との対応。載せた PR と載せなかった PR、緊急の修正では各コミットを示す

## 6. push と PR

承認されたら、材料の `branch` にいることを確かめて `git push -u origin HEAD` を実行する。リリースノートを本文にし、末尾に材料の一覧を `<!--` と `-->` で囲んで添える。通常のリリースでは各 PR の番号、タイトル、ラベル、載せたかどうかと載せなかった理由を記す。緊急の修正では各コミットの SHA と件名を記す。

本文をファイルに保存し、次の条件で `gh pr create --base main --head {branch} --title "Release v{版}" --body-file {本文のファイル}` を実行する。

- 通常のリリース: `--label S-Release`
- 緊急の修正: `--label S-Hotfix` と、オーナーに確かめた種類のラベル
- プレリリースにする場合は、どちらも `--label S-Prerelease` を足す

作成した PR の URL をオーナーに伝える。

## 7. マージ後の戻しマージ

リリース用の PR がマージされたあと、オーナーから頼まれた場合だけ戻しマージを行う。

1. 作業ツリーが空であることを確かめ、`git fetch origin` を実行する。
2. `develop` を `origin/develop` に fast-forward し、`origin/main` を `--no-ff` でマージする。
3. `main` 向けの開いた `release/*` PR があれば、そのブランチにも `origin/main` を `--no-ff` でマージする。
4. `project.yml` の版の行だけが競合した場合は、取り込む側のブランチにある版を採る。それ以外の競合は自分で決めず、オーナーに伝えて止める。
5. 作った merge commit と push するブランチをオーナーに示し、承認を得てから push する。

戻しマージでも `main` へは push せず、タグを作らない。
