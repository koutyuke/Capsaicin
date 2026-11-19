---
schema: evidence
id: EVID-BLK-015
title: 「明るさを0」で暗くしたままアプリが SIGKILL か SIGSEGV で終了しても、開くと最低限の明るさで表示され、輝度のキーとスライダーで戻せ、アプリを起動すると記録した輝度に戻った
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、バッテリー駆動、外部ディスプレイなし、内蔵ディスプレイの「輝度を自動調節」はオン。試作 `spike/daemon-cleanup-probe` の `d76d393` を標準の Debug のヘルパーのラベルでビルドし、Developer ID Application で署名した
sources: ["docs/meta/hypotheses/HYP-BLK-013-brightness-keys-restore-from-zero.md", "7528138:docs/meta/tasks/TASK-114-daemon-cleanup-probe.md"]
---

# EVID-BLK-015 「明るさを0」で暗くしたままアプリが SIGKILL か SIGSEGV で終了しても、開くと最低限の明るさで表示され、輝度のキーとスライダーで戻せ、アプリを起動すると記録した輝度に戻った

## 確かめた事実

オーナーが「ディスプレイを閉じたとき」を「明るさを0」、「ディスプレイを自動でオフにしない」をオンにして抑止し、ディスプレイを閉じてから、アプリに `kill -9` と `kill -SEGV` を1回ずつ送った。輝度は試作と同じ `DisplayServicesGetBrightness` で読み、画面の見え方はオーナーが目視した。

| 試行 | 閉じる前の輝度 | 記録した輝度 | 閉じている間 | 起動の直前 | 起動の後 |
| --- | --- | --- | --- | --- | --- |
| `SIGKILL` | 0.375 | 0.375 | 0.0 | 0.3347 | 0.375 |
| `SIGSEGV` | 0.375 | 0.375 | 0.0 | 0.6717 | 0.375 |

- どちらも、閉じる途中で画面が暗くなった。終了の後に開くと、画面は輝度 0 のままではなく、最低限の明るさでロック画面が見えた。
- どちらも、キーボードの輝度のキーとコントロールセンターの輝度のスライダーで、普段どおり明るさを変えられた。
- 起動の前の記録には `savedBrightness=0.375` が残っていた。試作を手で起動すると、その時点の輝度によらず 0.375 を書き、記録を消した。抑止は再開しなかった。`SIGSEGV` では、オーナーが開いた後に上げた 0.6717 が 0.375 に戻った。
- どちらも、デーモンが切断を受けて `Disconnect cleanup off: success=true` を出し、終了の1秒後と5秒後は `SleepDisabled 0` だった。アプリは再起動しなかった。閉じたままだったので、システムのログには終了の後のスリープと、開いたときの復帰が残った。

生の記録は `/Users/koutyuke/Capsaicin-verification.uLjbWk/result-brightness-crash-recovery.txt` と同じ場所のログ・画面写真にある。

## 確かめ方

`docs/manual/verification/brightness-crash-recovery.md`（`b107708`）の手順で、閉じる前、閉じている間、起動の直前と直後に輝度を読み、開いたときの見え方と輝度の操作を目視した。

## 適用範囲

外部ディスプレイのない MacBook で、「輝度を自動調節」がオンの場合に当てはまる。開いた直後に最低限の明るさになったのが、ロック画面と自動調節のどちらによるかは分けていない。

## 未確認のこと

- 「輝度を自動調節」がオフの場合に、開いた直後の画面が輝度 0 のままになるか。
- 外部ディスプレイをつないでいる場合。
