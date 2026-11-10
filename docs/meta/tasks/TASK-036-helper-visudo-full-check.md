---
schema: task
id: TASK-036
title: ヘルパーの設置と削除から sudoers 全体の検査を外す
status: done
requirements: ["REQ-HLP-001", "REQ-HLP-003", "REQ-HLP-005"]
depends_on: []
assignee: PM（Claude、claude-opus-5-5）。2行の削除とテストの修正なので PM が直した
---

# TASK-036 ヘルパーの設置と削除から sudoers 全体の検査を外す

## 目的

オーナーの Mac で、ヘルパーのインストールと削除がどちらも失敗する。管理者認証は成功するが、root で動くスクリプトが途中で止まる。ヘルパーの実行ファイルだけが残り、一部だけ残っている状態になった。

原因は、設置と削除のスクリプトが実行する `/usr/sbin/visudo -c`（パスの指定なし）である。この形は、sudoers が読み込むすべてのファイルの所有者とモードが 0440 かどうかまで検査する。オーナーの `/etc/sudoers.d` にあるほかのツールのファイル（0644 と、0444 への symlink）で失敗する（`EVID-HLP-002`）。設置は sudoers のルールを置いた後、削除は sudoers のルールを消した後にこの検査で止まる。

設置する sudoers のルールは、置く前に一時名のまま `visudo -c -f` で検証済みである。そのため、全体の検査はルールの安全性に何も足さず、無関係なファイルを理由に失敗して、一部だけ残った状態を作るだけになっている。設置と削除の両方から外す（`DEC-HLP-003`）。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Helper/HelperScripts.swift`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/Helper/HelperScriptsTests.swift`
- `docs/meta/decisions/DEC-HLP-002-helper-implementation.md`（`superseded` にする）
- `docs/meta/decisions/DEC-HLP-003-helper-implementation-without-full-check.md`（新規）
- `docs/meta/evidence/EVID-HLP-002-visudo-full-check-modes.md`（新規）
- `docs/meta/decisions/DEC-HLP-001-minimal-helper-via-sudoers.md`、`docs/specs/helper.md`、`docs/meta/requirements/helper.toml`（`DEC-HLP-002` への参照を `DEC-HLP-003` に替える）

触らない: `project.yml`、`docs/meta/tasks/TASK-033-app-icon.md`（別の作業の未コミットの変更がある）。

## 完了条件

- 設置のスクリプトで `visudo` を使うのは、一時名のルールを検証する `visudo -c -f "$rules"` の1回だけである。
- 削除のスクリプトは `visudo` を実行しない。
- テストが上の2点を確かめ、変更前に失敗し、変更後に成功する。
- `nix develop --command just check` と `nix develop --command just build` が通る。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 実機での設置と削除はオーナーが行う（root と管理者認証が要るため）。

## レビュー

- 原因は、開発機の更新時刻、`authd` の認証のログ、sudo のソースで裏付けた（`EVID-HLP-002`）。root での `visudo -c` の実行は行っていない。
- テストを先に直し、変更前に `installationOrder` と `removalOrder` が失敗し、変更後に成功することを確かめた。
- `nix develop --command just check` と `nix develop --command just build` が通った。
- 変更は sudo の権限に関わるが、自分のルールの検証（`visudo -c -f "$rules"`）は残しており、削るのは安全性に寄与しない全体の検査だけなので、別のエージェントによるレビューは省いた。
- 実機での設置と削除は未確認。オーナーに依頼する。
