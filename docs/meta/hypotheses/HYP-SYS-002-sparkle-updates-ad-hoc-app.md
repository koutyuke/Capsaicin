---
schema: hypothesis
id: HYP-SYS-002
title: Sparkle 2 は、ad-hoc 署名で launchd の管理下にある Capsaicin を、利用者の追加の操作なしに更新できる
status: open
affects: ["DEC-SYS-019", "DEC-LCY-005"]
evidence: []
---

# HYP-SYS-002 Sparkle 2 は、ad-hoc 署名で launchd の管理下にある Capsaicin を、利用者の追加の操作なしに更新できる

## 主張

ad-hoc 署名で公証していない Capsaicin を、Sparkle 2 で同じく ad-hoc 署名の新しいビルドへ更新すると、次のすべてが成り立つ。

1. EdDSA の署名が通る更新を受け入れ、署名を1バイトでも変えたアーカイブ、別の鍵で署名したアーカイブ、署名のない appcast を拒否する。
2. インストールの後、新しい版が Gatekeeper の「このまま開く」を求めずに起動する。新しい版に `com.apple.quarantine` が残らない。
3. 起動し直した新しい版は、Capsaicin の LaunchAgent の管理下で1つだけ動く。インストールの途中で、launchd が古い版を起動し直さない。
4. Mac を再起動してログインした後も、LaunchAgent から新しい版が起動する。ログイン項目やバックグラウンド項目が重複せず、利用者が無効にしていた状態も変わらない。
5. Sparkle による終了は、利用者の終了やセッションの終了ではなく、判定できない終了として扱われる（`DEC-LCY-004`）。

## 外れたときに起きること

- 1 が外れたら、`DEC-SYS-019` の署名と検証の設定を見直す。
- 2 から 4 のどれかが外れたら、更新のたびに利用者の操作が要る。`DEC-SYS-019` を見直し、更新を知らせてリリースのページを開くだけの方式に戻すかを決める。
- 5 が外れたら、`DEC-LCY-005` の終了の扱いを見直す。

## 確かめ方

オーナーが [アプリ内の更新を実機で確認して元に戻す手順](../../manual/update-verification.md)に従う。Debug の2つの版、使い捨ての鍵、手元の HTTP サーバーで主張1〜5を確かめ、結果と未確認の項目を記録する。`launchctl` とアプリの起動はエージェントが実行しない。

## 結果

未確認。
