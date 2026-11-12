---
schema: plan
id: PLAN-LED-001
title: キー配列を変更するアプリごとの LED の対処を Web ページで案内する
depends_on: []
---

# PLAN-LED-001 キー配列を変更するアプリごとの LED の対処を Web ページで案内する

## 目的

キー配列を変更するアプリを使う利用者が、抑止中に Caps Lock の LED が消える理由と対処を知れるようにする。アプリ内の案内は、点灯しないことがあると伝えるだけで、アプリの名前、設定、避け方を書かない（`DEC-LED-006`、`SPEC-LED-005`）。アプリごとの具体的な対処は、製品の Web ページに置く。

## 想定する体験

1. 利用者が、抑止中に LED が消えることに気づく。メニューか設定の「LED」セクションに、キー配列を変更するアプリの案内が出ている。
2. 利用者が、製品の Web ページのトラブルシューティングを開く。
3. 使っているアプリの項目を読み、対処と、その副作用を知る。

Karabiner-Elements の項目には、次を書く（`EVID-LED-012`）。

- 抑止中に Caps Lock を切り替えると、LED が Caps Lock の状態に合わせて消える。Karabiner-Elements が、実機の LED を Caps Lock の状態で書き直すためである。
- Devices の設定で、キーボードごとに「Manipulate caps lock LED」をオフにすると、抑止中の点灯が保たれる。
- オフにしたキーボードでは、抑止していない間も、Caps Lock をオンにして LED が点かなくなる。
- Capsaicin は、Karabiner-Elements のルールや Caps Lock の入力状態を変えない。

## 実現の見込み

- 書く内容のうち、Karabiner-Elements の項目は実機とソースで確かめてある（`EVID-LED-009`、`EVID-LED-012`）。
- 製品の Web ページは、まだない。ページを作る作業に依存する。
- Karabiner-Elements 以外のアプリは確かめていない。項目を足すには、そのアプリでの実機の確認が要る。

## 要件にする前に決めること

- 製品の Web ページを、どこに、どの形で置くか。
- アプリ内の案内から、Web ページへのリンクを張るか。張るなら、案内の見た目と `SPEC-LED-005` を直す。
- Karabiner-Elements 以外に、どのアプリの項目を用意するか。
- 公開の前に、「Manipulate caps lock LED」をオフにした状態での長時間の点灯と、外付けキーボードでの結果を確かめるか（`EVID-LED-012` の未確認のこと）。
