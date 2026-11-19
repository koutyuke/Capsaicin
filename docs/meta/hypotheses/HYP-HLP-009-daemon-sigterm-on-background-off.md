---
schema: hypothesis
id: HYP-HLP-009
title: バックグラウンドの項目をオフにすると、デーモンは SIGTERM を受けて off を実行でき、アプリはそれを検知できる
status: supported
affects: ["SPEC-HLP-004", "SPEC-BLK-007"]
evidence: ["EVID-HLP-012"]
---

# HYP-HLP-009 バックグラウンドの項目をオフにすると、デーモンは SIGTERM を受けて off を実行でき、アプリはそれを検知できる

## 主張

抑止中（デーモンが `on` を実行し、アプリが接続を保っている）に、システム設定の「一般 > ログイン項目と機能拡張」で Capsaicin の項目をオフにすると、次のすべてが成り立つ。

1. launchd はデーモンに `SIGTERM` を送り、デーモンは終了の前に `off` を実行できる。`pmset -g` が `SleepDisabled 0` を示す。
2. agent を登録していないアプリは終了しない。
3. アプリはヘルパーとの接続の切断を受け取り、そのとき `SMAppService.daemon` の状態は承認待ち（`requiresApproval`）を示す。

## 外れたときに起きること

1 が外れたら、項目をオフにしたときに `SleepDisabled` が残る。Mac の起動時の後片付け（`SPEC-HLP-003`）は、承認待ちの間はデーモンが起動できないので効かない。別の後片付けを考える。3 が外れたら、アプリが解除して HUD で知らせる方針（オフになったことを検知する）を、状態の定期的な読み直しなどに変える。

## 確かめ方

オーナーが、試作のアプリ（ブランチ `spike/daemon-cleanup-probe`）と、`docs/manual/verification/background-off-while-blocking.md` で確かめる。項目のオフとオンは永続的なシステム変更で、終わったらオンに戻す。

## 結果

実機で支持された（`EVID-HLP-012`）。項目をオフにすると、デーモンは `SIGTERM` を受けて `off` を実行し、`SleepDisabled` は 0 になった。アプリは同じ PID のまま `interrupted` と `invalid` を受け、どちらでも `SMAppService.daemon` は `requiresApproval` だった。
