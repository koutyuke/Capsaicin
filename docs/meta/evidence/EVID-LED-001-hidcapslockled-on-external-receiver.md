---
schema: evidence
id: EVID-LED-001
title: 外付けの機器（2.4G Wireless Receiver など）に HIDCapsLockLED があることを ioreg で確認した
observed_on: 2026-11-06
environment: 作者の開発用 Mac（移行元に macOS のバージョンと機種の記載なし）、外付けの「2.4G Wireless Receiver」などを接続
sources: ["d6cb7b3:docs/requirements.md"]
---

# EVID-LED-001 外付けの機器（2.4G Wireless Receiver など）に HIDCapsLockLED があることを ioreg で確認した

## 確かめた事実

観測した日は記録されていない。分かるのは、移行元の要件定義書を書いた 2026-11-06 以前ということだけである。`observed_on` の値は、この根拠を記録した日（移行元の基準日）であり、観測した日ではない。

作者の開発用 Mac で `ioreg` を見ると、プロパティ `HIDCapsLockLED` は内蔵キーボードのほか、外付けの機器（「2.4G Wireless Receiver」など）にもあった。

## 確かめ方

移行元の要件定義書（コミット `d6cb7b3` の `docs/requirements.md` の 4.3 節。移行後に削除した）に、作者が `ioreg` で確認したと記録されている。具体的なコマンドと出力は残っていない。同じ形の観測を再現する手順は `EVID-LED-002` にある。

## 適用範囲

外付けの機器が `HIDCapsLockLED` というプロパティを持ちうることの根拠に使ってよい。

## 未確認のこと

- 外付けキーボードで、`HIDCapsLockLED` によって LED が実際に光るか（`HYP-LED-003`）。
- 観測した日、観測した Mac の macOS のバージョンと機種、「など」に含まれるほかの機器。
