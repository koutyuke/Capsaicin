---
schema: hypothesis
id: HYP-HLP-013
title: BTM の UID -2 にある親のアプリの記録が disabled のとき、バックグラウンドの項目をオフにしても macOS はアプリを終了させない
status: open
affects: ["SPEC-HLP-004", "DEC-LCY-012"]
evidence: []
---

# HYP-HLP-013 BTM の UID -2 にある親のアプリの記録が disabled のとき、バックグラウンドの項目をオフにしても macOS はアプリを終了させない

## 主張

親の記録 `2.io.github.koutyuke.capsaicin.debug`（UID -2）が `disabled` なら、項目をオフにしても BTM は `forceQuitAppWithURL` を出さず、アプリは動き続ける。`enabled` なら終了させる。

根拠になっている観測は、`EVID-HLP-016`（親が `disabled`、アプリは動き続けた）と `EVID-HLP-017`（親が `enabled`、どの条件でも終了した）の対比だけで、ほかの違い（アプリの置き場所の worktree）も残っている。

## 外れたときに起きること

アプリが動き続ける場合の扱い（切断と承認待ちの検知で解除し、HUD で知らせる）が、実機で起きない経路になる。`DEC-LCY-012` で残すとした理由が弱まる。

## 確かめ方

親の記録を `disabled` にする手順が分かっていないので、今は確かめられない。親の記録の状態が変わる操作が見つかったら、`EVID-HLP-017` の試験 A を繰り返す。

## 結果

未確認。
