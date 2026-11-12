---
schema: task
id: TASK-058
title: Transport が "Virtual" のキーボードに書かない
status: done
requirements: ["REQ-LED-004"]
depends_on: ["TASK-054"]
assignee: Codex（Codex のハーネス、gpt-6.1-sol、推論 high）
---

# TASK-058 Transport が "Virtual" のキーボードに書かない

## 目的

Capsaicin は、`Transport` を持つキーボードのサービスを実機とみなして書く。Sidecar の仮想キーボードは `Transport` に `"Virtual"` を持つので、実機として扱われ、`"On"` と `"Auto"` が書かれていた（`EVID-LED-014`）。

`SPEC-LED-002` の「OS の仮想キーボードには書かない」を満たす。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/CapsLockLEDController.swift`
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/VirtualKeyboardMonitor.swift`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/LED/`

触らない: 上記以外のすべて。

## 作るもの

- 書き込みの対象を、キーボードで、`Transport` を持ち、その値が `"Virtual"` ではないサービスにする。
- 案内の条件（`VirtualKeyboardMonitor`）は変えない。キーボードで、`Transport` を持たないサービスがあるときだけ、案内を出す。`Transport` が `"Virtual"` のサービスだけでは出さない。
- テストは次を確かめる。
  - `Transport` が `"Virtual"` のキーボードに、`"On"` も `"Auto"` も書かない。同じ一覧にある実機には書く。
  - `Transport` が `"Virtual"` のキーボードだけがあるとき、案内を出さない。
  - `Transport` を持たないキーボードの扱い（書かない、案内を出す）は、いままでどおりである。

サービスの `Transport` の読み方は、いまの `hasTransport` を置き換えても、足してもよい。読み手が把握するものが少ない形を選ぶ。

## 守ること

- `HIDCapsLockLED` に書く値、失敗の判定、`throw` するエラー、ログの書式を変えない。
- 製品名、ベンダー、アプリ名で見分けない。
- 非公開の関数を増やさない。入力監視の権限を求めない（`REQ-LED-008`）。
- 本番コードに `REQ-*`・`SPEC-*`・`HYP-*`・`DEC-*`・`EVID-*`・`TASK-*` を書かない。
- `git commit` をしない。アプリの起動や、`scripts/manual/` の実行をしない。

## 完了条件

- 上の「作るもの」を満たす。
- `nix develop --command just check` と `nix develop --command just build` が通る。
- オーナーの実機の確認で、`Transport` が `"Virtual"` のキーボードが書き込みの対象に入らず、内蔵キーボードが点灯する。

## 検証

- PM が差分を読み、`just check` と `just build` を流す。
- 実機はオーナーが確かめる。準備は `docs/manual/led-fix-verification.md` の手順0を使う。
  1. Karabiner-Elements を終了する。`kbds` の出力に、`Transport` が `Virtual` の行があることを確かめ、その登録 ID を控える。行がなければ、実機では判定不能として、その旨を記録する。
  2. メニューと、設定の「LED」セクションに、案内がないことを見る。
  3. 抑止を始め、内蔵キーボードの LED を目視する。`snap 58-on` を実行する。
  4. 抑止を解除し、`applog > "$LC/58-applog.txt"` を実行する。
- 期待: 内蔵は点灯する。`applog` の `targets` に、控えた登録 ID（10進）が入らない。`58-on-leds.txt` で、そのサービスは `Auto` である。案内は出ない。

## レビュー

2026-11-12、PM が差分を読み、オーナーが実機で確かめた。完了条件をすべて満たした。

- サービスの `hasTransport` を、`Transport` の値をそのまま返す `transport` に置き換えた。書き込みの対象は、値があり、`"Virtual"` ではないもの。案内の条件は、値がないもの。
- 判定の理由を伝えるコメントを、PM が1行足した。
- テストは既存の3本の引数を広げた。`"Virtual"` のキーボードに書かないこと、`"Virtual"` だけでは案内を出さないこと、`Transport` を持たないキーボードの扱いが変わらないことを確かめる。
- `just check` と `just build` は通った。
- 実機（`2e1c028`、`EVID-LED-015`）: Sidecar の仮想キーボードは、どの書き込みの対象にも入らず、`HIDCapsLockLED` は `"Auto"` のままだった。内蔵と Lofree（2.4 GHz）は点灯し、案内は出なかった。
