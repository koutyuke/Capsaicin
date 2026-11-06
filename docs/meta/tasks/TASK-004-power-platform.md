---
schema: task
id: TASK-004
title: 電源の仕組みと機器の能力を macOS につなぐ
status: done
requirements: []
depends_on: [TASK-003]
assignee: OpenCode / GPT-6.1 Sol・GPT-6 Astra
---

# TASK-004 電源の仕組みと機器の能力を macOS につなぐ

## 目的

`CapsaicinCore` のポートのうち、電源に関わるものを macOS の API で実装する。あわせて、起動時に判定する機器の能力と、「蓋を閉じたら画面を消す」に使う蓋の監視を用意する。アプリへの組み込みは別のチケットで行う。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Power/`
- `Packages/CapsaicinKit/Tests/CapsaicinPlatformTests/Power/`
- このチケット（PM の作業・レビュー・検証記録）

触らない: `CapsaicinCore`、`CapsaicinIPC`、`Package.swift`、アプリ、CLI、ヘルパー、上記以外の `docs/`、`project.yml`。ほかの場所の変更が必要なら、変更せずに報告する。

## 作るもの

仕様は `docs/specs/blocking.md`（`SPEC-BLK-001`、`SPEC-BLK-002`、`SPEC-BLK-006`、`SPEC-BLK-007`、`SPEC-BLK-012`）、`docs/specs/settings.md`（`SPEC-SET-005`、`SPEC-SET-006`）、`docs/specs/lifecycle.md`（`SPEC-LCY-006`、`SPEC-LCY-007`）に従う。方式は `DEC-BLK-001`、`DEC-BLK-002`、`DEC-BLK-004`にある。

1. `PowerAssertionControlling` の実装。`AssertionKind` ごとに `DEC-BLK-001` の種類のアサーションを1つ作り、解放する。`pmset -g assertions` で Capsaicin のものと分かる名前を付ける。作成と解放はどちらも冪等にする。作ってある種類の作成と、作っていない種類の解放は、何もせずに成功とする。
2. `LidSleepControlling` の実装。`IOPMrootDomain` の `kPMSetClamshellSleepState` を使う（`EVID-BLK-002`、`EVID-BLK-004`、`EVID-BLK-006`）。この制御で蓋閉じスリープだけが止まるかは未確認である（`HYP-BLK-002`）。
3. `PowerStateProviding` の実装と、電源の変化の通知。`IOPSCopyPowerSourcesInfo` から残量と電源アダプターの接続を求め、変化したら登録された処理を呼ぶ。呼ばれたアプリが `BlockingController.powerStateChanged()` を呼ぶ。
4. `BootTimeProviding` の実装。`kern.boottime` を読み、読めなければ取得不能を示す `Date.distantPast` を返す。これは過去の起動時刻ではなく、`SPEC-LCY-007` の取得不能の分岐に渡す値である。呼び出すコントローラーが通常の起動と判定し、自動再開せず、前回のセッションと所有を捨てる（`SPEC-HLP-005`）。
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

### 2026-11-06 の実装・検証記録

- Sol / high の初回実装は4スイート・26テストが成功し、対象の整形と lint も通った。
- Astra / high の独立レビューで P1 が2件見つかった。アサーションの成功誤報・所有の不確実性と、画面消灯用の子プロセスの PID に対するシグナル送信競合・回収前の完了扱いである。
- アサーションの P1 は Sol / high が2ファイルで修正した。旧実装では、解放応答の喪失後に作成済みと誤って成功を返すことと、所有未確認の ID の再解放を RED で確認した。修正後は13テスト・31ケースが GREEN となり、対象の strict lint と整形も通った。Astra / high の独立再レビューでは、完了を妨げる指摘はなかった。
- 再レビュー後、数値のオーバーフローと破棄時の解放失敗のテストを補った。実装は変更しておらず、追加分も統合検証で成功した。
- 2026-11-06: 操作結果が不明なアサーションの扱いは過剰なので、利用者が安全ゲートと同じく簡素化を承認したのに合わせて取りやめ、TASK-010 で実装を簡素にした。
- 画面消灯の P1 は Astra / high が再実装した。旧実装が KILL の直後に後片付けを完了することを RED で確認し、修正後は2スイート・16テスト・25ケースが GREEN となった。対象4ファイルの整形・strict lint も成功した。別の Astra / high による独立レビューでは、PID の所有・回収、キャンセル競合、資源解放に完了を妨げる指摘はなかった。

`TASK-004` と `TASK-005` を合わせた状態で、`nix develop --command just check` と `nix develop --command just build` は成功した。スクリプト33件、パッケージ231件、アプリのバンドル検査3件が通った。整形・lint・文書検査も成功し、完了を妨げる指摘は残っていない。

### 残る検証とアプリ統合の前提

`canBlockLidSleepAlone` は1か所の定数で `false` とする。`HYP-BLK-002` が未検証のためであり、実機の結果で見直す。電源・蓋・機器判定に関する元の HYP の実機検証は未実施である。実際のアサーション操作、蓋制御、`pmset displaysleepnow` は検証で実行していない。

画面消灯の実装と、後続のアプリ統合が守る契約は次のとおりである。SDK との照合、偽物のテストと独立レビューで確認しており、実機で子プロセスを起動・停止した結果ではない。

- 自分が起動した子の回収とシグナル送信を一か所で直列化する。実行前に `SIGCHLD` が既定動作で、`SA_NOCLDWAIT` がないことを読み取って検査し、満たさなければ起動を拒否する。親のシグナル設定は変更しない。
- 子の所有中に、別の処理がその子を回収したり、親の `SIGCHLD` の設定を変えたりしないことを統合時に確認する。実行前の検査だけでは、この前提を保証できない。
- 2 秒で TERM、その後 0.5 秒で KILL とする停止スケジュールを持つ。ただし、合計 2.5 秒以内の回収完了を保証するものではない。
- 子を回収する前に、後片付け成功として完了しない。
