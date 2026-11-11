---
schema: task
id: TASK-052
title: 蓋を閉じたときに輝度を 0 にする方式を、オーナーが実機で確かめる手順と補助を作る
status: done
requirements: ["REQ-BLK-005"]
depends_on: ["TASK-051"]
assignee: Codex（OpenCode、openai/gpt-6.1-sol、variant high）
---

# TASK-052 蓋を閉じたときに輝度を 0 にする方式を、オーナーが実機で確かめる手順と補助を作る

## 目的

`Q-BLK-001` を決めるために、`HYP-BLK-010`〜`HYP-BLK-012` と `HYP-BLK-008`（開いたことの検知）を、オーナーが実機で確かめられるようにする。蓋を閉じた状態での光り方、ロック、取り込みは、エージェントには確かめられない。

## 範囲

書いてよい:

- `docs/manual/lid-close-dimming-verification.md`（新規）
- `scripts/manual/display-brightness.swift`（新規）

触らないもの: 上記以外のすべて。特に、同じ作業ツリーで進んでいる LED の作業（`Packages/CapsaicinKit/Sources/CapsaicinPlatform/LED/`、`Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/LED/`、`docs/manual/led-remapper-verification.md`、`docs/meta/tasks/TASK-050-led-write-result-log.md`）。`git add`、`git stash`、`git commit` もしない。

読むもの:

- `AGENTS.md`、`docs/documentation-management.md` の「書き方」
- `Q-BLK-001`、`HYP-BLK-008`、`HYP-BLK-010`、`HYP-BLK-011`、`HYP-BLK-012`、`EVID-BLK-007`、`EVID-BLK-008`
- 書き方の手本として `docs/manual/led-remapper-verification.md` と `docs/manual/verification.md`、`scripts/manual/verify.sh`
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Power/LidStateMonitor.swift`（蓋の開閉の通知の受け取り方）

## 作るもの

### 1. `scripts/manual/display-brightness.swift`

オーナーだけが実行する、試験用の補助。アプリには組み込まない。`xcrun swift scripts/manual/display-brightness.swift <サブコマンド>` で動くようにする（動かし方が違うなら、手順書にその方法を書く）。

| サブコマンド | すること |
| --- | --- |
| `get` | 1行を出す。時刻、蓋の状態（`AppleClamshellState`）、内蔵ディスプレイの `CGDisplayIsActive` と `CGDisplayIsAsleep`、DisplayServices の輝度、電池の電流（`AppleSmartBattery` の `InstantAmperage` を符号付きにした mA）と電圧（mV）、外部電源の有無 |
| `set <値>` | 内蔵ディスプレイの輝度を `<値>`（0 以上 1 以下）にし、`get` と同じ1行を出す。範囲外や数でない値は、何も変えずに終了コード 0 以外で終わる |
| `watch` | 蓋の開閉の通知を受けるたびと、10秒ごとに、`get` と同じ1行を出す。Ctrl-C で終わる |
| `watch --dim` | `watch` に加えて、開いていると分かっている状態から閉じたら、その時点の輝度を覚えてから 0 にする。開いたら覚えた輝度に戻す。SIGINT と SIGTERM を受けたら、暗くしている間なら戻してから終わる。起動時に蓋が閉じていたら、暗くしない |

- 内蔵ディスプレイだけを対象にする。オンラインの内蔵ディスプレイがなければ、何も変えずに終了コード 0 以外で終わる。
- DisplayServices は `dlopen` と `dlsym` で引く。関数が見つからない、または状態が 0 以外のときは、その旨を出して終了コード 0 以外で終わる（`watch --dim` の途中なら1行出して続ける）。
- ファイルに何も保存しない。システムの設定を変えない。
- 150行程度までにする。起こりにくい競合への防御を重ねない。
- Capsomnia のコードを見て書かない（`REQ-SYS-007`）。

### 2. `docs/manual/lid-close-dimming-verification.md`

オーナーが実機で行う手順書。冒頭に、確かめる問いと仮説の対応表を置く。各手順に、目的、前提、操作、期待する結果、途中で止める条件、元に戻す方法、記録することを書く。節の名前と内容は次のとおりにする（仮説の文書がこの名前で参照している）。

| 節 | 確かめること | 仮説 |
| --- | --- | --- |
| 準備 | 変更前の輝度、自動輝度調節、True Tone、Night Shift、「ディスプレイがオフになったあとにパスワードを要求」の設定を記録する。明るさのキーで戻せることを確かめる。Capsaicin で抑止し、「ディスプレイを閉じたとき」を「オンのまま」、「ディスプレイを自動でオフにしない」をオンにする。外部ディスプレイを外し、机の上で行う | なし |
| C1 | 蓋を開けたまま `set 0` にする。暗い部屋で画面が真っ暗になるか、`CGDisplayIsAsleep` が `0` のままか、QuickTime の画面収録で動く時計が写り続けるかを見る。明るさのキーか `set` で戻す | `HYP-BLK-011` |
| C2 | 「オンのまま」で、明るさのキーで最大にしてから蓋を閉じ、暗い部屋で隙間からの光を見る。`watch` の出力をリポジトリの外のファイルに残し、閉じている間の電流を記録する。最小にしても同じことをして比べる | `HYP-BLK-010` |
| C3 | `watch --dim` を動かして蓋を閉じ、5分待って開ける。開閉の通知が両方とも出たか、閉じている間の輝度が 0 のままか、開けた後に元の値に戻ったかを記録する。自動輝度調節をオンとオフの両方で行う | `HYP-BLK-012`、`HYP-BLK-008` |
| C4 | QuickTime の画面収録と `watch --dim` を動かして蓋を閉じ、パスワードを要求するまでの時間と10分の両方を過ぎるまで待つ。開けたときにロック画面が出るか、収録に時計が写り続けたかを見る。できれば離れた場所から画面共有で見る。比べるために、「ディスプレイをオフ」でも閉じて開ける | `HYP-BLK-011` |
| C5 | 電池駆動で、同じアプリを開いたまま操作せず、蓋を閉じて10分ずつ電流を記録する。「オンのまま」（輝度は元のまま）、`watch --dim`、「ディスプレイをオフ」の3つを比べる | `Q-BLK-001` の電力 |
| C6 | `watch --dim` で暗くしている間に、そのプロセスを `kill -9` で止めて蓋を開け、暗いまま残るか、明るさのキーで戻せるかを見る。任意で、輝度を 0 にしたまま Mac を再起動し、ログイン画面の明るさを見る | `Q-BLK-001` の取り残し |

- 電流は単発の値ではなく、区間の平均で比べる。機体全体の電力なので、バックライトだけの電力とは書かない。
- レジストリの `IODisplayParameters` は蓋を閉じても変わらないので、判定に使わない（`EVID-BLK-008`）。
- かばんに入れない。熱いと感じたら止める。
- 最後に、記録を PM に渡す形（表）を置く。

## 守ること

- 補助のうち、エージェントが実行してよいのは `get` だけにする。`set` と `watch` は輝度を変えうるので、型検査とビルドだけで確かめる（`AGENTS.md` の `scripts/manual/` の扱い）。
- `sudo`、`pmset` の設定変更、`launchctl`、Capsaicin と `scripts/manual/verify.sh` の実行をしない。
- サブエージェントを起動しない。

## 完了条件

- 補助が `xcrun swiftc -typecheck` を通り、`get` が1行を出す。
- 手順書に、準備と C1〜C6 があり、各手順に目的・前提・操作・期待・止める条件・元に戻す方法・記録がある。
- `nix develop --command just fmt-check` と `nix develop --command just lint` が通る。

## 検証

- `xcrun swiftc -typecheck scripts/manual/display-brightness.swift`
- `xcrun swift scripts/manual/display-brightness.swift get`
- `nix develop --command just fmt-check`、`nix develop --command just lint`
- PM が補助のコードと手順書を読む。

## レビュー

PM が補助のコードと手順書を読んだ。

- 補助は182行で目安を超えたが、過剰な防御や独自の仕組みはなく、受け入れた。蓋の開閉の通知の受け方は `LidStateMonitor` と同じで、`set` と `watch --dim` の書き込みは内蔵ディスプレイだけに限られている。入力の検査と電流の符号の変換は `assert` で自己検査している。
- 手順書から、補助そのものの動きを試すだけで `Q-BLK-001` の判断に効かない手順（SIGTERM での復元、起動時に閉じていた場合）を PM が削った。SIGINT での復元は、閉じたまま輝度を戻せるか（閉じたままの解除に当たる）を確かめる手順に改めた。
- 開始前の輝度を手入力せず、`before.log` から読むように PM が直した。
- オーナーの時間を考え、判断に効く順（準備 → C2 → C3 → C4）と、C2 の結果次第で打ち切ってよいことを冒頭に足した。

PM が `xcrun swift scripts/manual/display-brightness.swift get`、`just fmt-check`、`just lint` を実行し、通ることを確かめた。
