---
schema: evidence
id: EVID-HLP-007
title: 親のアプリを持たない BTM のデーモンの項目が登録のたびに使い直され、launchd は BundleProgram を解決できずに Invalid path (108) で起動に失敗した
observed_on: 2026-11-18
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、起動は 2026-11-18 14:30:57。デーモンによる後片付けの試作の、ヘルパーのラベルの接尾辞を指定できるようにする前の版を `just build` と `just sign-debug`（Developer ID Application、TeamIdentifier GG7W7F3CTU）で作った Debug ビルド
sources: ["b107708:docs/manual/verification/app-crash-daemon-cleanup.md", "7528138:docs/meta/tasks/TASK-114-daemon-cleanup-probe.md"]
---

# EVID-HLP-007 親のアプリを持たない BTM のデーモンの項目が登録のたびに使い直され、launchd は BundleProgram を解決できずに Invalid path (108) で起動に失敗した

## 確かめた事実

`b107708:docs/manual/verification/app-crash-daemon-cleanup.md` の実施で、オーナーが試作のアプリからヘルパーを登録した。

- 登録は成功し、launchd はジョブを作った（`Submit job succeeded: service = io.github.koutyuke.capsaicin.debug.helper`、smd による）。起動のたびに `Could not find and/or execute program specified by service: 108: Invalid path: Contents/Helpers/capsaicin-helper` で失敗し、`last exit code = 78: EX_CONFIG` になった。launchd は約 10 秒ごとに起動を試し続けた。
- `launchctl print` のジョブは、`program identifier = Contents/Helpers/capsaicin-helper (mode: 2)`、`parent bundle identifier = io.github.koutyuke.capsaicin.debug`、`BTM uuid = 02441BE8-2E87-4108-8776-D4043CA4EB9B` を示した。
- `sfltool dumpbtm` で、デーモンの項目（`16.io.github.koutyuke.capsaicin.debug.helper`、UUID `02441BE8…`）は UID -2 の記録にあり、`Parent Identifier` は `Unknown Developer` だった。Capsaicin のアプリの項目（`2.io.github.koutyuke.capsaicin.debug`）は UID 501 の記録にだけあり、UID -2 にはなかった。
- 同じ Mac の Karabiner-Elements の SMAppService のデーモンは、UID -2 の記録で `Parent Identifier` が `2.org.pqrs.Karabiner-Elements-Privileged-Daemons-v2`（アプリの項目）だった。
- 登録の前、デーモンの項目は同じ UUID で `[disabled, allowed, not notified]`、`Generation: 60`、`Last Use: 2026-11-18 14:31:46`（Mac の起動の約 50 秒後）だった。登録の後も UUID は同じで、`[enabled, allowed, not notified]`、`Generation: 61` になった。新しい項目は作られなかった。
- 試作を `/Applications/Capsaicin.app` に置き直して登録し直しても、同じ `Invalid path (108)` で失敗した。BTM のアプリの項目の URL は `/Applications/Capsaicin.app` に変わったが、デーモンの項目の親は `Unknown Developer` のままだった。
- バンドルには `Contents/Helpers/capsaicin-helper` があり、実行権限と Developer ID の署名は正しかった。

## 確かめ方

オーナーの操作と、PM の役のエージェント（別スレッド）が保存した `sfltool dumpbtm`、`launchctl print`、`log show` の出力を、PM が読み比べた。

## 適用範囲

この Mac の BTM に、親を持たない `.debug` のデーモンの項目が残っている間に当てはまる。アプリからの unregister は項目を消さず（`disabled` になるだけ）、次の登録で同じ項目が使い直される。

## 未確認のこと

- デーモンの項目が、いつ、どの操作で親を失ったか。最初に保存した `sfltool dumpbtm` の出力は、試作が起動時に agent を unregister した後（23:24 以降）に保存されたので、その unregister の影響を否定しきれない。
- 親を失ったことが `Invalid path (108)` の原因であること。launchd が相対の `BundleProgram` を親のアプリの場所から解決するという推定による。BTM 側の判断のログは残っていない。
- `sfltool resetbtm` 以外に、この項目を消す方法。
