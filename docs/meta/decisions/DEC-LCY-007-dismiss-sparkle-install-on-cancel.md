---
schema: decision
id: DEC-LCY-007
title: 抑止中のインストールは Sparkle に返答する前に確かめ、取り消したら Sparkle に Dismiss を返す
status: accepted
supersedes: []
superseded_by: []
requirements: ["REQ-SYS-008"]
based_on: ["DEC-LCY-005", "HYP-SYS-005"]
---

# DEC-LCY-007 抑止中のインストールは Sparkle に返答する前に確かめ、取り消したら Sparkle に Dismiss を返す

## 結論

- `SPUStandardUserDriver` に処理を委ねる自前の `SPUUserDriver` を使い、利用者がインストールを選んだ返答だけを横取りする。対象は、「インストールして再起動」の画面（`showReadyToInstallAndRelaunch:`）と、準備済みの版の画面（`showUpdateFoundWithAppcastItem:state:reply:` で stage が installing のもの）でのインストールの選択である。
- 抑止中なら、Sparkle に返答する前に、抑止を解除することの確認を出す。続けたら Install を返し、取り消したら Dismiss を返す。抑止を止めているときは、確認を出さずに Install を返す。
- Dismiss を返した版は、利用者が「今すぐ確認」かメニューのアップデートの項目を選んだとき、または Capsaicin を終了したときにインストールされる。抑止の解除や設定ウインドウを閉じたことを契機に、自動ではインストールしない。
- 手動の経路では `updater(_:shouldPostponeRelaunchForUpdate:untilInvokingBlock:)` による延期を使わない。自動のインストールの待ち合わせ（`DEC-LCY-005`）は変えない。

## 背景

これまでは、利用者が抑止中にインストールを選ぶと、Sparkle に Install を返した後で、`shouldPostponeRelaunch` の中で確認を出していた。取り消すと延期のブロックを保持したまま返すので、Sparkle の「インストールの準備完了」の画面が残る。この画面は閉じるボタンを持たず、ボタンのハンドラーは1回押すと捨てられる（Sparkle 2.10.1 の `SPUStandardUserDriver.m`）。そのため、利用者は画面を閉じることも、もう一度インストールを選ぶこともできなかった。

## 選択肢

- 延期を保ったまま、`dismissUpdateInstallation()` で画面だけを閉じる。変更は数行で済む。ただし、このメソッドは Sparkle がセッションの終わりに呼ぶためのもので、アプリが単独で呼んだときの振る舞いは契約にない。閉じた後は、待っている版の画面を開き直す手段もなくなる（不採用）。
- 確認を Sparkle の画面より前、更新の確認のボタンに置く。更新がないときにも確認が出て、ダウンロードの間に抑止の状態が変わる問題も残る（不採用）。
- 自前の user driver で、Sparkle に返答する前に確認し、取り消したら Dismiss を返す（採用）。

## 理由

- Dismiss は `SPUUserDriver.h` が定める返答である。Sparkle が自分で画面を閉じてセッションを終え、準備済みの版は残る。公開された契約だけで、閉じられない画面をなくせる。
- 利用者が取り消した版を、抑止の解除の後に黙ってインストールしない。「確認のみ」を選んでいる利用者の意図に沿い、いつインストールされるかを利用者が決められる。
- 取り消した後も、「今すぐ確認」から同じ版をもう一度選べる。

## 影響

- `SPEC-LCY-008` の手動のインストールの取り消しと、`SPEC-SET-007` の行の状態が変わる。
- `SPUStandardUserDriver` に処理を委ねるだけのメソッドが、`SPUUserDriver` の数だけ増える。
- Dismiss の後の振る舞い（インストーラーが残る、次の確認で同じ版を再び示す、終了時にインストールする）は、Sparkle 2.10.1 の実装で確かめる（`HYP-SYS-005`）。Sparkle の版を上げるときは確かめ直す。
- Capsaicin を終了したときに、取り消した版がインストールされることがある。終了の後片付けは `SPEC-LCY-002` のとおり行われる。
- 「ダウンロードしてインストール」を選んでいる場合は、次の定期の確認で Sparkle が残ったインストーラーを自動の更新として扱い、`DEC-LCY-005` の条件でインストールすると見込む（`SPUAutomaticUpdateDriver.m` だけが `willInstallUpdateOnQuit` を呼ぶことからの推論）。利用者が選んだ自動の設定に従う振る舞いなので、妨げない。

## 覆す条件

- `HYP-SYS-005` が外れ、Dismiss の後にインストーラーが残らない、または次の確認で同じ版を示さないと分かったとき。
- Sparkle の版を上げて、`SPUUserDriver` の契約や Dismiss の扱いが変わったとき。
- 取り消した版を、抑止の解除の後に自動でインストールしたいと決めたとき。
