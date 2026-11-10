---
schema: task
id: TASK-049
title: キー配列を変えるアプリと Caps Lock の LED の関係を、読み取りだけで調べる
status: todo
requirements: ["REQ-LED-003", "REQ-LED-004", "REQ-LED-007"]
depends_on: []
assignee: Codex（Codex のハーネス、推論 high 以上）
---

# TASK-049 キー配列を変えるアプリと Caps Lock の LED の関係を、読み取りだけで調べる

## 目的

Karabiner-Elements に限らず、キー配列を変えるアプリ全般に通用する LED の扱いを選ぶための材料を集める。`docs/manual/led-remapper-verification.md` の A1〜A4 を行う。実機での検証（同じ文書の B）はオーナーが別に行う。

## 範囲

書いてよい: なし（リポジトリのファイルを変更しない）。報告は PM への返答で行う。

読むもの:

- `docs/manual/led-remapper-verification.md`
- `HYP-LED-002`、`HYP-LED-005`〜`HYP-LED-010`、`EVID-LED-002`、`EVID-LED-005`、`EVID-LED-006`、`DEC-LED-001`、`DEC-LED-003`
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/` と `Packages/CapsaicinKit/Sources/CapsaicinLEDShim/`
- 外部のソースと資料。リポジトリの外に clone してよい。

## 作るもの

A1〜A4 の問いへの答えを、次の形で返す。

1. 結論（問いごとに数行）
2. 根拠。ソースはコミット、ファイル、行で示す。Web の資料は実際に開いた URL だけを示す。確かめた事実、ソースからの推論、未確認の推測を分ける。
3. 根拠にできる事実の下書き。ID は付けず、PM が振る。
4. `docs/manual/led-remapper-verification.md` の B の手順で、足りない観点や誤りがあれば、その指摘

## 守ること

- 読み取りだけで行う。`HIDCapsLockLED` への書き込み、Caps Lock の操作、Capsaicin や `scripts/manual/` の実行、Karabiner-Elements の起動・停止・設定変更、`sudo`、`launchctl` をしない。
- `hidutil list`、`ioreg`、`log show` の読み取りと、`~/.config/karabiner/karabiner.json` の読み取りはしてよい。読んだ設定の内容を外部に送らない。
- サブエージェントを起動しない。
- アプリ名の一覧に頼る判定を、最初の答えにしない。汎用の判定が成り立たないと分かった場合に、その根拠とともに示す。

## 完了条件

- A1〜A4 のそれぞれに、根拠つきの答えか、確かめられなかった理由がある。
- A1 の表に、少なくとも Karabiner-Elements、Kanata、Raycast の Hyper Key、Keyboard Maestro、BetterTouchTool、Hammerspoon、システム設定の修飾キー、`hidutil` の `UserKeyMapping` がある。

## 検証

PM が報告の根拠を読み、主要な主張をソースで照合する。リポジトリの変更がないことを `git status --short` で確かめる。

## レビュー

未着手。
