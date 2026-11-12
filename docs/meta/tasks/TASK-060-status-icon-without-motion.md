---
schema: task
id: TASK-060
title: メニューバーのアイコンを動かさずに替え、どのディスプレイでも抑止の状態を正しく示す
status: done
requirements: ["REQ-MENU-004", "REQ-UI-002"]
depends_on: ["TASK-048"]
assignee: PM（Claude Opus 5.5）が直接実装する
---

# TASK-060 メニューバーのアイコンを動かさずに替え、どのディスプレイでも抑止の状態を正しく示す

## 目的

ディスプレイを2枚つないでいると、メニューバーで抑止を切り替えたとき、フォーカスのないディスプレイのメニューバーのアイコンが前の状態のまま残る（オーナーの報告）。原因は `EVID-MENU-001` にある。`DEC-MENU-003` のとおり、置き換えの動きをやめ、`NSStatusBarButton` の `image` に直接画像を入れる形にして、どのディスプレイのメニューバーにも正しい状態のアイコンが出るようにする。

## 範囲

書いてよい:

- `Sources/Capsaicin/MenuBar/MenuBarController.swift`
- `Tests/CapsaicinTests/MenuBar/MenuBarTests.swift`
- `docs/specs/menu.md`（`SPEC-MENU-005`）、`docs/specs/ui.md`（`SPEC-UI-006`）
- `docs/meta/decisions/DEC-MENU-002-status-icon-follows-blocking.md`（「影響」の動きの行だけ）、`docs/meta/decisions/DEC-MENU-003-status-icon-without-motion.md`、`docs/meta/evidence/EVID-MENU-001-other-display-icon-is-snapshot.md`

触らない: 作業ツリーにある、ほかの作業の未コミットの変更。

## 作るもの

1. `MenuBarController` から、ボタンに重ねた `NSImageView`、ボタンの幅を測る手順、表示中のシンボルの記録、「視差効果を減らす」の分岐を除く。`refresh()` で、抑止の状態に合わせた画像（15 pt の Regular、テンプレート画像）を `statusItem?.button?.image` に入れる。
2. `MenuBarTests.statusIcon()` を、ステータス項目を作ってボタンの画像を確かめる形に直す。停止中と抑止中で画像が替わり、どちらもテンプレート画像であることを確かめる。
3. `SPEC-MENU-005` と `SPEC-UI-006` から置き換えの動きを除き、`SPEC-MENU-005` に2枚のディスプレイでの受け入れ例を足す。

## 完了条件

- 直したテストが、変更前のコードで失敗し、変更後に通る。
- `nix develop --command just check` と `nix develop --command just build` が通る。範囲外の未コミットの変更だけで落ちる場合は、その出力を残す。

## 検証

- `nix develop --command just check`
- `nix develop --command just build`
- 2枚のディスプレイでの見え方（`SPEC-MENU-005` の受け入れ例）と、メニューバーの明暗での色、メニューを開いたときの強調は、オーナーが実機で確かめる。

## レビュー

PM が実装し、差分を読み直して次を確かめた。

- `MenuBarController` は、`refresh()` で抑止の状態に合わせた画像を `statusItem?.button?.image` に入れるだけになった。`NSImageView`、幅を測る手順、`displayedSymbol`、「視差効果を減らす」の分岐はなくなった。`start()` は `refresh()` を呼ぶので、起動直後も正しい画像になる。
- `refresh()` は出来事、分ごとのタイマー、メニューを開くときなどに呼ばれ、そのたびに画像を作り直す。毎秒は呼ばれないので、状態が変わったときだけ作る仕組みは足さない（`TASK-048` の方針どおり）。
- `MenuBarTests.statusIcon()` は、変更前のコードで失敗し（ボタンの画像が空のため6件）、変更後に通った。
- `just check`（アプリ 86、パッケージ 145 などのテスト、文書の検査）と `just build` は成功した。

オーナーが2026-11-12に実機で確かめ、問題はなかった。確かめたのは、2枚のディスプレイで両方のアイコンが切り替わること（`SPEC-MENU-005` の受け入れ例）、メニューバーの明暗での色、メニューを開いたときの強調である。
