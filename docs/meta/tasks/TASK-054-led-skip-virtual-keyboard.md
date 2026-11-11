---
schema: task
id: TASK-054
title: 仮想キーボードを LED の書き込み先から外し、Karabiner-Elements の案内を直す
status: in_review
requirements: ["REQ-LED-003", "REQ-LED-004", "REQ-LED-007"]
depends_on: ["TASK-053"]
assignee: Codex（Codex のハーネス、gpt-6.1-sol、推論 high）
---

# TASK-054 仮想キーボードを LED の書き込み先から外し、Karabiner-Elements の案内を直す

## 目的

Capsaicin は、Karabiner-Elements の仮想キーボードにも `HIDCapsLockLED` を書いている。Karabiner-Elements はこれを Caps Lock オンと受け取り、抑止中は修飾キーを厳密に照合するルールが成立しなくなる（`EVID-LED-009`）。仮想キーボードを書き込み先から外し、案内を実際の振る舞いに合わせる（`DEC-LED-005`、`SPEC-LED-002`、`SPEC-LED-005`）。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/CapsLockLEDController.swift`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/LED/`
- `Sources/Capsaicin/Settings/SettingsLed.xcstrings`（案内の本文だけ）

触らない: 上記以外のすべて。案内を出す条件（`KarabinerElementsMonitor`、`KarabinerProcessSource`）は `TASK-055` で扱う。

## 作るもの

- 書き込みの対象を、キーボード（usage page 1・usage 6）のうち `Transport` を持つサービスに限る。`Transport` は、公開ヘッダーの `IOHIDServiceClientCopyProperty` と `kIOHIDTransportKey` で読む。
  - 根拠: 実機の記録では、内蔵、USB、Bluetooth Low Energy、2.4 GHz のサービスはすべて `Transport` を持ち、Karabiner-Elements の仮想キーボードだけが持たなかった（`EVID-LED-006`、`EVID-LED-007`）。製品名やベンダーでは判定しない。
  - ログの `targets` には、書いたサービスだけを出す。
- テスト名の「内蔵・外付け・仮想のキーボードだけに On と Auto を書く」を、仮想キーボードに書かないことを確かめる内容に直す。
- 設定の案内の本文を、次の内容に直す。日本語と、String Catalog にあるほかの言語の両方を直す。
  - Karabiner-Elements が LED を管理しているキーボードでは、スリープ防止中も LED が点灯しないこと。
  - Karabiner-Elements のデバイスの設定で「Manipulate caps lock LED」をオフにすると点灯すること。
  - 「入力機能には影響ありません」は残してよい。対象を直した後は正しい。

## 守ること

- `Transport` を持たないサービスへは、`"On"` も `"Auto"` も書かない。移行のための書き込みは足さない。前の版が異常終了して仮想キーボードに `"On"` を残していた場合は戻せないが、仮想キーボードは Karabiner-Elements の再起動やスリープからの復帰で作り直される。
- 非公開の関数を増やさない。
- 本番コードに `REQ-*`・`SPEC-*`・`HYP-*` を書かない。
- String Catalog は Xcode の書式（`"key" : value`、末尾の改行なし）を保つ。
- `git commit` をしない。LED への書き込みを伴うアプリの起動や、`scripts/manual/` の実行をしない。

## 完了条件

- 上の「作るもの」を満たす。
- `nix develop --command just check` と `nix develop --command just build` が通る。
- オーナーの実機の確認で、`SPEC-LED-002` の「仮想キーボードには書かない」が満たされ、Lofree の3つの接続方式と内蔵が、Karabiner-Elements を止めた状態で点灯する。

## 検証

- PM が差分を読み、`just check` と `just build` を流す。
- 実機はオーナーが `docs/manual/led-remapper-verification.md` の B1 と B3 で確かめる。アプリのログの `targets` に仮想キーボードの登録 ID がないこと、抑止中もルールが成立することを見る。
- Karabiner-Elements が既定の設定で占有するキーボードでは、LED が点かなくなる。これは `DEC-LED-005` で受け入れた振る舞いである。

## レビュー

- Codex が実装し、`just check` と `just build` を通した。キーボードのうち `Transport` を持つサービスだけに書き、ログの `targets` にも書いたサービスだけが出る。設定の案内の本文を置き換えた。
- PM が直したこと: テストのフィクスチャが `Transport` の値を文字列で持ち、値を変えて同じテストを5回流していた。本番の判定は値の有無だけを見るので、フィクスチャは有無だけを持つ形にし、繰り返しをやめた。
- PM が `just check` と `just build` を流し直し、どちらも通った。
- 実機では未確認。オーナーが `docs/manual/led-remapper-verification.md` の B1 と B3 で確かめるまで、`in_review` のままにする。
