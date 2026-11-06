---
schema: evidence
id: EVID-LCY-002
title: 初めて登録した直後のレガシー LaunchAgent は、バックグラウンド項目の記録がまだない
observed_on: 2026-11-06
environment: macOS 27.0.1（ビルド 26A434）、Mac16,8（Apple M4 Pro）、ad-hoc 署名の Debug ビルド
sources: []
---

# EVID-LCY-002 初めて登録した直後のレガシー LaunchAgent は、バックグラウンド項目の記録がまだない

## 確かめた事実

- `~/Library/LaunchAgents` に plist を初めて書いた。続いて `bootstrap` と `kickstart` が成功し、launchd がアプリを起動した。その直後に `SMAppService.statusForLegacyPlist(at:)` を呼ぶと、`backgroundtaskmanagementd` が `record not found` を記録した。アプリは、この結果を `.enabled` 以外として受け取った。直接起動したプロセスも、launchd が起動したプロセスも、同じ結果だった。
- その後、同じ plist に同じ照会をすると `.enabled`（生の値 `1`）が返った。
- このため、照会の結果で引き渡しの成否を決めていた版では、直接起動したプロセスが終了しなかった。launchd が起動したプロセスと2つ並んで動いた。

## 確かめ方

`docs/manual/verification.md` の 2.1 で、Finder からアプリを起動した。その後、次を実行した。

```sh
/usr/bin/log show --style compact --start "2026-11-06 13:46:10" --end "2026-11-06 13:47:30" \
  --predicate '(process == "backgroundtaskmanagementd" AND eventMessage CONTAINS[c] "capsaicin") OR (subsystem == "io.github.koutyuke.capsaicin")'
```

時間をおいて、`SMAppService.statusForLegacyPlist(at:)` だけを呼ぶ小さなプログラムで照会した。

## 適用範囲

バックグラウンド項目の照会の結果は、`launchctl` の要求が成功したかの代わりに使えない。この根拠はその判断に使ってよい。また、launchd が起動したプロセスで「記録がない」を「無効」とみなさない理由にも使ってよい。

## 未確認のこと

- 記録が作られるまでにかかる時間と、それが何で決まるか。
- 利用者がバックグラウンド項目を無効にしたとき、`bootstrap` と `kickstart` のどちらが、どう失敗するか（`verification.md` の 2.3 で確かめる）。
