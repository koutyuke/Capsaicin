---
schema: task
id: TASK-004
title: 電源の仕組みと機器の能力を macOS につなぐ
status: todo
requirements: []
depends_on: [TASK-003]
assignee: OpenCode / GPT-6.1 Sol
---

# TASK-004 電源の仕組みと機器の能力を macOS につなぐ

## 目的

`CapsaicinCore` のポートのうち、電源に関わるものを macOS の API で実装する。あわせて、起動時に判定する機器の能力と、「蓋を閉じたら画面を消す」に使う蓋の監視を用意する。アプリへの組み込みは別のチケットで行う。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Power/`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/Power/`

触らない: `CapsaicinCore`、`CapsaicinIPC`、`Package.swift`、アプリ、CLI、ヘルパー、`docs/`、`project.yml`。ほかの場所の変更が必要なら、変更せずに報告する。

## 作るもの

仕様は `docs/specs/blocking.md`（`SPEC-BLK-001`、`SPEC-BLK-002`、`SPEC-BLK-006`、`SPEC-BLK-007`、`SPEC-BLK-012`）、`docs/specs/settings.md`（`SPEC-SET-005`、`SPEC-SET-006`）、`docs/specs/lifecycle.md`（`SPEC-LCY-006`、`SPEC-LCY-007`）に従う。方式は `DEC-BLK-001`、`DEC-BLK-002`、`DEC-BLK-004` にある。

1. `PowerAssertionControlling` の実装。`AssertionKind` ごとに `DEC-BLK-001` の種類のアサーションを1つ作り、解放する。`pmset -g assertions` で Capsaicin のものと分かる名前を付ける。
2. `LidSleepControlling` の実装。`IOPMrootDomain` の `kPMSetClamshellSleepState` を使う（`EVID-BLK-002`、`EVID-BLK-004`、`EVID-BLK-006`）。この制御で蓋閉じスリープだけが止まるかは未確認である（`HYP-BLK-002`）。
3. `PowerStateProviding` の実装と、電源の変化の通知。`IOPSCopyPowerSourcesInfo` から残量と電源アダプターの接続を求め、変化したら登録された処理を呼ぶ。呼ばれたアプリが `BlockingController.powerStateChanged()` を呼ぶ。
4. `BootTimeProviding` の実装。`kern.boottime` を読み、読めなければ `Date.distantPast` を返す（ポートのコメントのとおり）。
5. `MachineCapabilities` を起動時に判定する処理。
   - 蓋の有無: `HYP-SET-001` の方法による。
   - 内蔵バッテリーの有無: `HYP-SET-002` の方法による。
   - 蓋閉じスリープだけを止められるか（`canBlockLidSleepAlone`）: 実行時に副作用なしで判定できる根拠がなければ、1か所の定数にし、値と理由を報告する。`HYP-BLK-002` の結果で見直す。
6. 蓋の開閉の監視と、閉じたときに画面を消す処理（`SPEC-BLK-002`、`DEC-BLK-002`）。
   - `AppleClamshellState` の変化を通知で受け取る（`HYP-BLK-008`）。
   - 画面を消すのは `/usr/bin/pmset displaysleepnow` で行う（`HYP-BLK-001`）。シェルを介さず、固定のパスと固定の引数で実行し、期限を持つ。
   - 消すかどうかの判断（抑止中で、抑止に使う設定値の `turnsOffDisplayOnLidClose` が真）はアプリが渡す。この部品は判断を持たない。

IOKit の呼び出しは、テストで偽物に差し替えられる境界の後ろに置く。ただし、実装が1つしかない抽象を増やさない。境界を置く場所は、テストに必要なところだけにする。

## 守ること

- テストで、副作用のある OS の呼び出し（アサーションの作成、`kPMSetClamshellSleepState`、`pmset displaysleepnow`）をしない。蓋閉じスリープの制御はプロセスの終了後も残りうるので、特に呼ばない。読み取りだけの呼び出し（`IOPSCopyPowerSourcesInfo`、`sysctl`、IORegistry の読み取り）は、テストで呼んでよい。
- 実機でしか確かめられない振る舞い（上の HYP）は、確かめる手順を報告に書く。手順は PM が承認を得て実行する。
- `AGENTS.md` の「破ってはいけないもの」を守る。

## 完了条件

- 上の 1〜6 があり、それぞれ `CapsaicinCore` のポートか、アプリが組み込める型として公開されている。
- 自明でない変換（電源の情報から `PowerState` を作る処理、`kern.boottime` の値から `Date` を作る処理、蓋の状態の変化の判定）に Swift Testing のテストがあり、テスト名に仕様の ID を含む。
- 本番コードに `REQ-*` と `SPEC-*` を書いていない。
- `nix develop --command just check` が通る。

## 検証

- `nix develop --command just test-package`
- `nix develop --command just check`

## レビュー

未実施。
