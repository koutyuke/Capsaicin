---
schema: task
id: TASK-006
title: ヘルパーと、その呼び出し・設置・削除を作る
status: in_progress
requirements: []
depends_on: [TASK-003]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-006 ヘルパーと、その呼び出し・設置・削除を作る

## 目的

root で動く C のヘルパーを作る。アプリの側には、次のものを作る。

- ヘルパーの呼び出しと、`SleepDisabled` の読み取り（`CapsaicinCore` の `HelperSleepControlling`）
- 設置、修復、削除の処理
- インストールの状態の判定

root で動くコードと管理者認証を扱うので、ほかのチケットより厳しくレビューする。画面とアプリへの組み込みは別のチケットで行う。

## 範囲

書いてよい:

- `Sources/capsaicin-helper/`
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Helper/`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/Helper/`

触らない: `CapsaicinCore`、`CapsaicinIPC`、ほかの `CapsaicinPlatform` のディレクトリ、`Package.swift`、アプリ、CLI、`docs/`、`project.yml`。ほかの場所の変更が必要なら、変更せずに報告する。

## 作るもの

仕様は `docs/specs/helper.md` のすべて（冒頭の「状態」を含む）に従う。あわせて、`docs/specs/blocking.md` の `SPEC-BLK-007` と、`docs/specs/lifecycle.md` の `SPEC-LCY-007` にも従う。方式は `DEC-HLP-001` と `DEC-HLP-002` にあり、`visudo` の検査は `EVID-HLP-001`、`SleepDisabled` の読み方は `EVID-BLK-003` にある。

### 1. ヘルパー（C）

`SPEC-HLP-002` と `DEC-HLP-002` に従う。

- 引数がちょうど `on` か `off` のときだけ、空の環境変数で `/usr/bin/pmset -a disablesleep 1|0` を `execve` する。
- それ以外は、何もせずに 64 で終わる。
- シェル、PATH の探索、任意の引数を使わない。

### 2. `HelperSleepControlling` の実装

- `turnOn` と `turnOff` は、`/usr/bin/sudo -n <ヘルパーの固定パス> on|off` を、シェルを介さずに実行する。
  - 子の環境変数は最小にする。
  - 期限は 5 秒とし、過ぎたら throw する。期限を過ぎても子プロセスは止めずに終わるまで見届け、その間に来た `turnOn`、`turnOff`、`readSleepDisabled` は子プロセスを起動せずに throw する（`SPEC-HLP-005`）。
- `readSleepDisabled` は、`EVID-BLK-003` の方法か、それと同じ値を一般ユーザーの権限で読める方法で実装し、選んだ理由を報告する。読めなければ throw する。期限と見届けの規則は `turnOn` と同じにする。
- `isHelperInstalled` は、3つの構成要素がそろっているときだけ真にする。

### 3. インストールの状態の判定

`SPEC-HLP-004` の「未インストール」「一部だけ残っている」「インストール済み」を返す型を作る。

### 4. 設置、修復、削除の処理

`SPEC-HLP-001`、`SPEC-HLP-004`、`SPEC-HLP-005` の削除の項、`DEC-HLP-002` の順序に従う。

- 管理者認証は1回だけにする（`osascript` の `do shell script … with administrator privileges`）。
- 処理の内容は固定にする。外から入る値は、次の3つだけにする。
  - アプリのバンドル内のヘルパーのパス
  - uid
  - 削除のときに `disablesleep` を戻すかの真偽値
- それぞれの値は検証し、AppleScript とシェルの両方で安全に引用する。空白、引用符、改行、`$`、バックスラッシュを含むパスも試す。
- sudoers のルールは、`.` を含む一時名で書き、`visudo -c -f` で検証してから置く。主体は uid（`#<uid>`）で書く。
- 結果は「成功」「取り消し（管理者認証を取り消した）」「失敗（何ができなかったか）」を区別して返す（`SPEC-HLP-001`、`SPEC-HLP-006`）。
- 削除に失敗したときに読み直すための情報を返す。読み直しは `SPEC-HLP-004` に従う。

### 5. Debug ビルドとの分離

Debug ビルドは、置き場所の名前、sudoers のファイル名、LaunchDaemon のラベルに `.debug` 相当の区別を付け、Release と衝突させない（`DEC-SYS-008`）。sudoers.d のファイル名に `.` が使えないことに注意する。

## 守ること

- 開発機にヘルパーを設置しない。`sudo`、`osascript` による管理者認証、`launchctl`、`pmset` の設定変更を、ビルドでもテストでも手作業でも実行しない。
- `/Library/PrivilegedHelperTools`、`/etc/sudoers.d`、`/Library/LaunchDaemons` に書き込まない（`AGENTS.md`）。
- テストでは、生成するスクリプト、sudoers のルール、LaunchDaemon の plist の中身と、引用と検証を確かめる。
- `visudo -c -f` で一時ファイルの書式を確かめるテストは、root を要さず、システムの設定を変えない場合に限って書いてよい。
- ヘルパーの実行ファイルは、不正な引数で 64 を返すことだけを確かめてよい。`on` と `off` は実行しない。
- 実機での確認（`SPEC-HLP-001`〜`SPEC-HLP-005` の受け入れ例）は、手順を報告に書く。手順は PM が承認を得て実行する。

## 完了条件

- 上の 1〜5 がある。
- 外から入る値の検証と引用、スクリプトの順序、状態の判定、期限切れの扱いに Swift Testing のテストがあり、テスト名に仕様の ID を含む。
- ヘルパーのソースは `clang-format` と `-Werror` を通る。
- 本番コードに `REQ-*` と `SPEC-*` を書いていない。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just test-package`
- `nix develop --command just check`
- `nix develop --command just build`

## レビュー

- C ヘルパー（上の 1）は先に実装し、独立レビューで指摘はなかった。不正な引数の拒否、固定のコマンドと空の環境を、本番の `on`・`off` を実行せずに確かめている。
- 2026-11-06: Codex が PM だった間に、Mac の起動ごとの journal、UID 共通のロック、Debug と Release の間の所有の引き渡しからなる「安全ゲート」が足された。期限切れへの対策としては過剰なので、利用者の承認を得て取りやめ、`SPEC-HLP-005` の期限と見届けの規則に置き換えた。
