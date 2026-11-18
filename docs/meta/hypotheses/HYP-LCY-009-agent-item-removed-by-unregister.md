---
schema: hypothesis
id: HYP-LCY-009
title: agent の plist を持つビルドから unregister すると、SMAppService の agent の項目はシステム設定から消える
status: supported
affects: ["DEC-LCY-008"]
evidence: ["EVID-LCY-008"]
---

# HYP-LCY-009 agent の plist を持つビルドから unregister すると、SMAppService の agent の項目はシステム設定から消える

## 主張

PR Preview や手元のビルド（bundle ID `io.github.koutyuke.capsaicin.debug`）が登録した SMAppService の agent は、同じ bundle ID で、同じ名前の agent の plist をバンドルに持つビルドから `SMAppService.agent(plistName:).unregister()` を呼ぶと、次のすべてが成り立つ。

1. `status` が `notRegistered` になり、`launchctl print gui/<uid>/io.github.koutyuke.capsaicin.debug` が失敗する。
2. 同じ bundle ID のデーモンの登録と、システム設定の「ログイン項目と機能拡張」の Capsaicin の項目のスイッチは変わらない。

## 外れたときに起きること

agent をやめた版に移った Mac に、使われない agent の項目が残る。開発者向けの片付けの手順（`docs/manual/verification/prepare.md`）を、別の方法で書く。利用者の Mac には SMAppService の agent を配布していないので、利用者向けの移行には影響しない。

## 確かめ方

オーナーが、試作のアプリ（ブランチ `spike/daemon-cleanup-probe`、`TASK-114`）を起動し、そのアプリが一度だけ行う unregister の前後で、`launchctl print` と、試作のアプリがログに出す `status` を見る。agent の登録の解除は永続的なシステム変更で、元に戻すには今の `feature/smappservice` のビルドを起動し直す。

## 結果

主張1と2は実機の1回の試行で支持された（`EVID-LCY-008`）。別のビルドが登録した agent は `notRegistered` になり、`launchctl print` は失敗した。デーモンの登録とスイッチは変わらなかった。ただし、題の「システム設定から消える」はそのとおりではない。BTM の agent の項目は `disabled` で残り、デーモンと1つの行にまとまっているシステム設定の「Capsaicin.app」の行も残った。
