---
schema: hypothesis
id: HYP-LED-010
title: キーボードとして名乗るが Caps Lock の LED を持たない機器への書き込みは、LED 全体の失敗として扱われる
status: refuted
affects: ["SPEC-LED-002", "SPEC-BLK-007"]
evidence: ["EVID-LED-007"]
---

# HYP-LED-010 キーボードとして名乗るが Caps Lock の LED を持たない機器への書き込みは、LED 全体の失敗として扱われる

## 主張

マウスやレシーバーには、マクロのためにキーボードとして名乗るサービス（usage page 1・usage 6）を持つものがある（Viper V2 Pro など）。Capsaicin はこのサービスにも `HIDCapsLockLED` を書く。この書き込みは失敗を返し、1台でも失敗すると LED 全体が失敗になるので、抑止のたびに「Caps Lock の LED を切り替えられていません」の警告と、解除時の「一部を戻せません」が出る。

## 外れたときに起きること

失敗を返さないなら、こうした機器は警告の原因にならず、書いても実害はない。対象から外す理由は、見た目の整理だけになる。

当たっていれば、LED を持たないサービスを対象から外すか、失敗に数えない（`SPEC-LED-002`、`SPEC-BLK-007`）。どちらにするかは `HYP-LED-007` の選び方と合わせて決める。

## 確かめ方

`docs/manual/led-remapper-verification.md`（コミット `14fd1f7`） の B1 で確かめる。

1. 外付けキーボードを外し、Viper V2 Pro だけを USB で接続する。`hidutil list` で、Viper V2 Pro がキーボードとして名乗るサービスを持つかを記録する。
2. Capsaicin で抑止を始め、メニューの警告と `resume-record.json` の `misalignments` を見る。解除して HUD を見る。
3. 2.4 GHz のレシーバーで繰り返す。

成功（主張どおり）: キーボードとして名乗るサービスがあり、抑止のたびに警告が出る。失敗: サービスがない、または警告が出ない。

## 結果

外れた。2026-11-11 に、Viper V2 Pro（USB、2.4 GHz）はキーボードとして名乗るサービスを2つ持っていたが、`"On"` と `"Auto"` の書き込みは成功を返し、警告も「一部を戻せません」も出なかった（`EVID-LED-007`）。こうしたサービスを対象から外す必要はなく、`SPEC-LED-002` と `SPEC-BLK-007` は変えない。
