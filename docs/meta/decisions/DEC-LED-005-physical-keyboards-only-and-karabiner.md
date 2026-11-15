---
schema: decision
id: DEC-LED-005
title: LED は実機のキーボードだけに書き、Karabiner-Elements が管理するキーボードでは点かないことを案内する
status: superseded
supersedes: ["DEC-LED-003"]
superseded_by: ["DEC-LED-006"]
requirements: ["REQ-LED-001", "REQ-LED-003", "REQ-LED-004", "REQ-LED-007"]
based_on: ["DEC-LED-001", "EVID-LED-008", "EVID-LED-009", "EVID-LED-010"]
---

# DEC-LED-005 LED は実機のキーボードだけに書き、Karabiner-Elements が管理するキーボードでは点かないことを案内する

## 結論

`DEC-LED-001` を補い、次のようにする。API の呼び方は `DEC-LED-003` から変えていない。

- **API の呼び方:** SDK の公開ヘッダーにある `IOHIDEventSystemClient` と `IOHIDServiceClient` の関数で呼べるなら、それを使う。公開されていない関数が要る場合は、小さな C のモジュールに宣言を閉じ込め、弱いリンク（weak import）にする。`dlsym` と関数の型の手作業の変換は使わない。関数がないときの振る舞いは `SPEC-LED-006` にある。
- **書き込みの対象:** 実機のキーボードだけに書く。キー配列を変えるアプリが作る仮想キーボードには書かない。
- **Karabiner-Elements との関係:** 取り合わない。Karabiner-Elements が LED を管理するキーボードでは抑止中も LED が点かないことを受け入れ、その旨と避け方（Karabiner-Elements のデバイスの設定で「Manipulate caps lock LED」をオフにする）を案内する（`SPEC-LED-005`）。

## 背景

`DEC-LED-003` は、Karabiner-Elements が LED を書き直すという読解だけを根拠に、検出して案内すると決めていた。2026-11-11 の実機の検証で、次のことが分かった（`EVID-LED-009`）。

- Karabiner-Elements が既定の設定で占有するキーボードでは、実機に書いた `"On"` はすぐ消される。
- Capsaicin は仮想キーボードにも書いていたので、LED は点いたままだった。Karabiner-Elements が仮想キーボードの LED を Caps Lock の状態として読み、実機を点けていたためである。その間、Karabiner-Elements は Caps Lock がオンだとみなし、修飾キーを厳密に照合するルールが成立しなくなった。
- 「Manipulate caps lock LED」か「Modify events」をオフにしたキーボードでは、実機への書き込みが保たれた。

Karabiner-Elements の既定の設定のままでは、LED を点けることと、入力に影響しないことを両立できない。

## 選択肢

- 仮想キーボードにも書き続ける。LED は点くが、抑止中は利用者のルールが効かなくなる（不採用）。
- 実機だけに書き、Karabiner-Elements が管理するキーボードでは点かないことを案内する（採用）。
- Karabiner-Elements より短い間隔で実機に書き直し続ける。LED がちらつく（不採用。`DEC-LED-003` と同じ）。
- Karabiner-Elements の設定ファイルを Capsaicin が書き換える。利用者の設定をほかのアプリが変えることになる（不採用）。

## 理由

- Caps Lock の入力状態を変えないこと（`REQ-LED-003`）は、LED の表示より優先する制約である。仮想キーボードへの書き込みは、Caps Lock そのものは変えないが、利用者のキー入力の結果を変える。
- LED が点かないことは、案内と Karabiner-Elements 側の設定で利用者が解決できる。ルールが効かなくなることは、原因が Capsaicin だと利用者には分からない。
- 取り合うと LED がちらつき、抑止中であることがかえって分かりにくくなる。

## 影響

- Karabiner-Elements が既定の設定で占有するキーボードでは、抑止中も LED が点かなくなる。これまでは点いていたので、Karabiner-Elements の利用者には見た目の後退になる。
- `SPEC-LED-002` の対象から仮想キーボードを外す。実機と仮想の見分け方は `HYP-LED-007` で確かめる。
- `SPEC-LED-005` と設定画面の案内を、「消えることがある」から「点かない。この設定で点く」に変える。「入力機能には影響ありません」は、対象を直した後に正しくなる。
- 案内の条件は、当面は Karabiner-Elements のプロセスの検出のままにする。常駐プロセスが残るので、アプリを終了しても案内が出る。占有されたキーボードがあるときだけに絞るかは、`HYP-LED-008` の結果をもとに決める。

## 覆す条件

- 公開ヘッダーの関数だけで `HIDCapsLockLED` を書けないと分かったら、呼び方を見直す。
- Karabiner-Elements が、仮想キーボードの LED を Caps Lock の状態として使わなくなった、または LED だけを点ける連携の手段を用意したら、対象と案内を見直す。
- 実機と仮想を見分けられないと分かったら（`HYP-LED-007`）、対象の決め方を見直す。
