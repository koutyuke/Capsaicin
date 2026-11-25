---
schema: evidence
id: EVID-HLP-011
title: 親のない項目が消えた後、標準のラベルのヘルパーを登録すると、新しい項目が親付きで作られ、Invalid path なしで起動した
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）。`EVID-HLP-009` の再起動の後の状態から、デーモンによる後片付けの試作を標準の Debug のヘルパーのラベルでビルドし、Developer ID Application で署名した
sources: ["docs/meta/hypotheses/HYP-HLP-012-reboot-drops-missing-app-item.md", "7528138:docs/meta/tasks/TASK-114-daemon-cleanup-probe.md"]
---

# EVID-HLP-011 親のない項目が消えた後、標準のラベルのヘルパーを登録すると、新しい項目が親付きで作られ、Invalid path なしで起動した

## 確かめた事実

- 登録の前の `sfltool dumpbtm` には、`16.io.github.koutyuke.capsaicin.debug.helper` の項目がなかった。`EVID-HLP-007` の親のない項目（`Parent Identifier: Unknown Developer`）は残っていなかった。
- オーナーが試作の「ヘルパー」からヘルパーを登録して許可すると、`16.io.github.koutyuke.capsaicin.debug.helper` の項目が新しい UUID（`1B0B227D…`）、`Generation: 1`、`[enabled, allowed, not notified]` で作られた。`Parent Identifier` は `2.io.github.koutyuke.capsaicin.debug` だった。
- UID -2 のアプリの項目（`6254535B…`）の URL は、ゴミ箱の中のコピーから、今回の試作のパスに変わった。
- launchd はヘルパーを起動し、今回の起動の時間帯のログに `Invalid path` はなかった。デーモンは `on` と `off` を処理した（`EVID-HLP-010`）。

## 確かめ方

`docs/manual/verification/app-crash-daemon-cleanup.md`（`b107708`）の準備で、登録の前と後の `sfltool dumpbtm` を比べ、`launchd` のログから `Invalid path` を探した。

## 適用範囲

`EVID-HLP-008` の手順で親のない項目が消えた後に、元のラベルを登録し直した場合に当てはまる。親のない項目が残ったまま元のラベルを登録した場合は含まない。

## 未確認のこと

- 親のない項目ができる操作（`HYP-HLP-012` の主張1と2）。
