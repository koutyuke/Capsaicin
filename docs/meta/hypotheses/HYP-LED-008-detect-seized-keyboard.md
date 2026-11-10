---
schema: hypothesis
id: HYP-LED-008
title: キーボードを別のプロセスが占有していることは、アプリ名に頼らず、権限なしで検出できる
status: open
affects: ["REQ-LED-007", "SPEC-LED-005", "DEC-LED-003"]
evidence: ["EVID-LED-006"]
---

# HYP-LED-008 キーボードを別のプロセスが占有していることは、アプリ名に頼らず、権限なしで検出できる

## 主張

キー配列を変えるアプリが実機の LED を書き換えうるのは、そのアプリがキーボードを占有（seize）しているときである。占有は、IORegistry のキーボードのデバイスの下にある `IOHIDLibUserClient` で、`ClientOpened` が `true`、`ClientOptions` に `kIOHIDOptionsTypeSeizeDevice` が立っていることで分かる。これは入力監視の権限なしで読める。Karabiner-Elements が占有をやめると、この印は消える。

## 外れたときに起きること

占有の有無を汎用には検出できない。Karabiner-Elements のプロセスの検出（`SPEC-LED-005`）を続けるか、条件をつけずに常に案内するかを選び直す。

当たっていれば、案内の条件を「Karabiner-Elements のプロセスがある」から「キーボードがほかのプロセスに占有されている」に変えられる（`REQ-LED-007`、`DEC-LED-003` の見直し）。ただし `DebugState` はデバッグ用の値で、OS の版で変わりうる（`EVID-LED-006`）。製品の判定に使うかは、この危うさと比べて判断する。

## 確かめ方

1. 調査: IOHIDFamily のソースで、`DebugState` の各値の意味と、占有の状態を示す公開のキーや API がほかにないかを確かめる。
2. 実機: `docs/manual/led-remapper-verification.md` の B3 で、Karabiner-Elements の停止、デバイスの「Modify events」のオフ・オン、Karabiner-Elements の起動のそれぞれで、内蔵と外付けキーボードのクライアントの `ClientOpened` と `ClientOptions` を記録する。
3. 成功: 占有しているときだけ、そのキーボードに `ClientOpened = Yes` かつ `ClientOptions` が奇数のクライアントがある。失敗: 占有していないのに印がある、または占有しているのに印がない。

## 結果

未確認。
