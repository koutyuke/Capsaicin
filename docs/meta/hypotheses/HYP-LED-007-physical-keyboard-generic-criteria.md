---
schema: hypothesis
id: HYP-LED-007
title: アプリ名やベンダーに頼らず、IORegistry の属性だけで実機のキーボードのサービスを選べる
status: open
affects: ["REQ-LED-004", "REQ-LED-007", "SPEC-LED-002", "SPEC-LED-005"]
evidence: ["EVID-LED-006", "EVID-LED-007", "EVID-LED-014", "EVID-LED-015"]
---

# HYP-LED-007 アプリ名やベンダーに頼らず、IORegistry の属性だけで実機のキーボードのサービスを選べる

## 主張

次の両方を満たすサービスを実機のキーボードとして選ぶと、内蔵、USB、Bluetooth、2.4 GHz のレシーバーの外付けキーボードはすべて入り、キー配列を変えるアプリの仮想キーボードは入らない。

- `HIDVirtualDevice` が `true` でない。
- `Transport` を持ち、デバイスが DriverKit で作られた仮想デバイス（`AppleUserHIDDevice` で、上位に実際のバスを持たないもの）ではない。

選び方の候補はこれに限らない。調査（`TASK-049` の A2）で、OS が実機と仮想をどう区別しているかを確かめ、もっと確かな属性があれば置き換える。

`EVID-LED-006` から、`HIDVirtualDevice` だけでは足りないことは分かっている。Karabiner-Elements の仮想キーボードはこの印を持たず、Apple の VendorID を名乗る。Apple 自身の仮想デバイスも `Transport = "USB"` を名乗る。

## 外れたときに起きること

汎用の属性では実機と仮想を見分けられない。次のどれかを選ぶ。

- 製品名の一覧で除外する。アプリごとに追従が要る。
- LED の出力要素を持つかなど、別の観点で選ぶ。
- 仮想キーボードに書く害（`HYP-LED-006`）を、別の方法で避ける。

`SPEC-LED-002` の対象の決め方と、`SPEC-LED-005` の案内の条件が変わる。

## 確かめ方

1. 調査: IOHIDFamily のソースと SDK のヘッダーで、仮想デバイスの印と、実機のバスの種類を確かめる。Karabiner-Elements 以外の仮想キーボードの作り方（`IOHIDUserDevice`、DriverKit）ごとに、付く属性を調べる。
2. 実機: `docs/manual/led-remapper-verification.md`（コミット `14fd1f7`） の B1 の記録で、内蔵と Lofree Flow Lite（USB、Bluetooth、2.4 GHz）、Viper V2 Pro（USB、2.4 GHz）、Karabiner-Elements の仮想キーボードの属性を並べる。
3. 成功: 主張の条件（または調査で置き換えた条件）で、実機のキーボードがすべて入り、仮想キーボードが入らない。失敗: どちらかに反例がある。

## 結果

実機の部分だけ確かめた。調査（確かめ方の 1）は `TASK-049` に残っている。

2026-11-11 の実機の記録では、内蔵（`FIFO`）、Lofree の USB（`USB`）、Bluetooth（`Bluetooth Low Energy`）、2.4 GHz（`USB`）、Viper V2 Pro（`USB`）のサービスはすべて `Transport` を持ち、Karabiner-Elements の仮想キーボードのサービスだけが持たなかった（`EVID-LED-006`、`EVID-LED-007`）。この範囲では「`Transport` を持つ」だけで見分けられる。ほかのアプリの仮想キーボードは未確認である。

2026-11-12 に反例が1つ見つかった。Sidecar の仮想キーボードは `Transport` に `"Virtual"` を持ち、いまの実装の書き込みの対象に入った（`EVID-LED-014`）。「`Transport` を持つ」だけでは足りない。主張の2つ目の条件（DriverKit の仮想デバイスではない）にも当たらない。このデバイスは `IOHIDUserDevice` である。書いたときの害は確かめていない。

同じ日に、対象の条件を「`Transport` を持ち、その値が `"Virtual"` ではない」に変えた（`TASK-058`）。この条件で、内蔵と Lofree（2.4 GHz）には書き、Sidecar の仮想キーボードには書かなかった（`EVID-LED-015`）。主張の条件そのものと、ほかの作り方の仮想キーボードは、まだ確かめていない。
