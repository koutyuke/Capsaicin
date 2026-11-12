---
schema: task
id: TASK-065
title: 抑止中に解除の時刻を置き換える処理を、コア、IPC、CLI、HUD に実装する
status: done
requirements: ["REQ-BLK-006", "REQ-BLK-015", "REQ-CLI-001"]
depends_on: []
assignee: Codex（OpenCode、openai/gpt-6.1-sol、variant high）
---

# TASK-065 抑止中に解除の時刻を置き換える処理を、コア、IPC、CLI、HUD に実装する

## 目的

`DEC-BLK-009` を実装する。時間の指定のある開始の要求は、抑止中なら解除の時刻と由来を置き換える。開始の要求の指定に「時間の条件なし」を加える。メニューの見た目の変更は別のチケット（TASK-066）で行うので、ここでは要求を受ける側と、CLI、HUD までを作る。

## 範囲

書いてよい:

- `Packages/CapsaicinKit/Sources/CapsaicinCore/`、`Packages/CapsaicinKit/Sources/CapsaicinIPC/`、`Packages/CapsaicinKit/Sources/CapsaicinCoreTesting/`
- `Packages/CapsaicinKit/Tests/`
- `Sources/capsaicin-cli/`、`Sources/Capsaicin/CLI/CLI.xcstrings`
- `Sources/Capsaicin/App/`（要求と結果の受け渡し、出来事の振り分けに必要な分だけ）
- `Sources/Capsaicin/HUD/`、`Sources/Capsaicin/MenuBar/MenuHUDRouting.swift`（置き換えたときの HUD に必要な分だけ）
- `Tests/CapsaicinTests/`

触らないもの: 上記以外のすべて。特に `Sources/Capsaicin/MenuBar/` の `MenuContent.swift`、`MenuBarController.swift`、`StartPanel.swift`、`MenuBar.xcstrings`（TASK-066 で変える）、`Sources/Capsaicin/Settings/`、`docs/`（別のエージェントが同時に仕様を直している。読むだけ）。`git add`、`git stash`、`git commit` をしない。

読むもの:

- `AGENTS.md`（特に「破ってはいけないもの」と「検証」）
- `docs/meta/decisions/DEC-BLK-009-replace-time-limit-while-blocking.md`（正はこれ）、`DEC-BLK-005`
- `docs/specs/blocking.md` の `SPEC-BLK-003`、`SPEC-BLK-005`、`SPEC-BLK-009`、`SPEC-BLK-011`、`docs/specs/cli.md`、`docs/specs/hud.md` の `SPEC-HUD-001`、`SPEC-HUD-002`、`docs/specs/lifecycle.md` の `SPEC-LCY-007`（仕様はまだ古い。食い違えば判断を正とする）
- `Packages/CapsaicinKit/Sources/CapsaicinCore/Time/TimeLimit.swift`、`Controller/BlockingController*.swift`、`Controller/BlockingEvent.swift`、`Lifecycle/ResumeRecord.swift`、`CapsaicinIPC/IPCMessages.swift`、`CapsaicinIPC/ExitCode.swift`、`Sources/capsaicin-cli/`、`Sources/Capsaicin/App/AppModel.swift`、`Sources/Capsaicin/HUD/`、`Sources/Capsaicin/MenuBar/MenuHUDRouting.swift`

## 作るもの

- `StartTimeOverride` に「時間の条件なし」を加える。停止中にこれで開始したら、設定のタイマーと指定時刻を使わず、解除の時刻を持たない。
- 抑止中に時間の指定のある開始の要求を受けたら、要求を受けた時刻を起点に `TimeLimitRule` で解除の時刻と由来を決め直し、いまのセッションに入れる。抑止の仕組み（アサーション、`disablesleep`、LED、輝度）には触れない。バッテリーの条件は変えない。
- 指定のない開始の要求は、抑止中は今までどおり何も変えない（`alreadyBlocking`）。
- 置き換えを受けた時点で、いまの解除の時刻を過ぎていたら、自動の解除を先に行い、置き換えでは抑止を続けない。
- 置き換えたら、再開用の記録のセッションを書き直す。保存できないときは、開始以外の出来事と同じ既存の扱いに従う。
- 置き換えの結果を、開始・すでに抑止中と区別できる結果として返し、出来事として通知する。HUD は、メニューから置き換えたときだけ、開始したときと同じ形で新しい条件を表示する。CLI からのときは表示しない。HUD をオフにしているときの読み上げ（`SPEC-HUD-008`）は開始と同じ扱いにする。
- IPC と CLI: 抑止中の `on --for`、`on --until` は置き換え、終了コードは 0。出力で、置き換えたことと新しい解除の時刻を伝える。文言は `CLI.xcstrings` に足し、既存の出力の書き方と `DEC-UI-012` に合わせる。CLI に時間の条件なしの指定は加えない。引数なしの `on` は今までどおり。
- テスト: 名前に仕様 ID を含める（`SPEC-BLK-011`、`SPEC-BLK-003`、`SPEC-CLI-001` など）。少なくとも、抑止中の置き換え（タイマー、指定時刻、時間の条件なし）、起点が要求の時刻であること、バッテリーの条件が残ること、仕組みに触れないこと、記録の書き直し、解除の時刻を過ぎていた場合、停止中に時間の条件なしで開始したときに設定のタイマーを使わないこと、CLI の終了コードと出力を確かめる。

## 守ること

- 起こりにくい競合への防御を重ねない。既存の開始と解除の流れ、記録の更新、出来事の通知の仕組みを使い、新しい仕組みを作らない。
- 本番コードに `REQ-*` と `SPEC-*` を書かない。
- 抑止を一度外して掛け直す実装にしない。
- 判断と仕様にない振る舞いを決める必要があったら、推測で埋めずに報告する。
- サブエージェントを起動しない。

## 完了条件

- 上の振る舞いがテストで確かめられている。
- 次のコマンドが通る。`just check` は、別のエージェントが仕様を直している途中で `lint-docs` が落ちることがあるので使わない。
  - `nix develop --command just fmt-check`
  - `nix develop --command just lint-code`
  - `nix develop --command just test`
  - `nix develop --command just build`

## 検証

上のコマンドの結果と、変えたファイル、型や出来事の追加、迷った点を報告する。

## レビュー

- 判断どおり、抑止中の時間の指定のある開始の要求で解除の時刻を置き換え、仕組みには触れず、記録を書き直している。置き換えた後の解除のタイマーは、既存の状態の変化の通知で掛け直される。
- `StartResult.released`（置き換えより先に期限で解除した）と IPC のバージョンを 2 に上げたことは、既存の規約どおりで受け入れた。
- `CLIOutput.response` の書き換えは、案件の追加で循環的複雑度の上限を超えるのを避けるためだったので、そのまま受け入れた。
- PM が `just fmt-check`、`just lint-code`、`just test` を流し、すべて通った。
