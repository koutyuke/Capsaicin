---
schema: task
id: TASK-051
title: ディスプレイスリープさせずに内蔵ディスプレイを暗くする方式を、読み取りだけで調べる
status: done
requirements: ["REQ-BLK-005"]
depends_on: []
assignee: Codex（OpenCode、openai/gpt-6-astra、variant high）
---

# TASK-051 ディスプレイスリープさせずに内蔵ディスプレイを暗くする方式を、読み取りだけで調べる

## 目的

のちに `DEC-BLK-007` で解決した論点の判断材料を集める。蓋を閉じたとき、ディスプレイスリープ（`DEC-BLK-002`）ではなく、画面を描き続けたまま内蔵ディスプレイを暗くする方式を比べる。類似アプリ Capsomnia の方式（非公開の DisplayServices で輝度を 0 にする）は候補の1つとして扱い、ほかの方式も同じ観点で比べる。実機で蓋を閉じて確かめることは、オーナーが別に行う。

## 問い

- **R1 方式の比較**: 候補は、DisplayServices の輝度の関数、CoreDisplay の輝度の関数、IOKit の `IODisplaySetFloatParameter`、CoreGraphics のガンマ（`CGSetDisplayTransferByTable` など）、内蔵ディスプレイを無効にする非公開の関数（SkyLight など）と、調べる中で見つかったものとする。方式ごとに次を示す。
  - 公開か非公開か、root の要否、Apple Silicon と macOS 26 で効くと言える資料があるか
  - バックライトが消えるか、画素を黒くするだけか
  - 画面収録や Computer Use で取り込む内容が変わるか
  - 「ディスプレイがオフになったあとにパスワードを要求」の対象にならないか
  - プロセスの終了やクラッシュで自動で元に戻るか。戻らないなら、戻すために何を保存する必要があるか
  - 自動輝度調節、True Tone、Night Shift、明るさのキーやコントロールセンターでの変更との干渉
  - 外部ディスプレイをつないでいるとき（クラムシェルモード）の扱い
- **R2 蓋を閉じたときの macOS の振る舞い**: `pmset -a disablesleep 1` でシステムのスリープを止めて蓋を閉じたとき、内蔵ディスプレイが点いたままか、macOS が内蔵パネルを消すか。蓋が開いたことを、閉じたことと同じ通知（`IOPMrootDomain` の一般の通知と `AppleClamshellState`）で一般ユーザーの権限で受け取れるか。
- **R3 先行例**: Capsomnia、Amphetamine、Lunar、MonitorControl、BetterDisplay、`brightness` コマンドなどが、どの方式で輝度を変え、どう元に戻しているか。Issue やリリースノートにある不具合（戻らない、自動輝度調節に上書きされる、macOS の更新で動かなくなった など）も示す。
- **R4 読み取りだけの実験**: この Mac で、DisplayServices と CoreDisplay を `dlopen` できるか、関係する関数のシンボルがあるか、現在の輝度を取得系の関数で読めるかを確かめる。`ioreg` の読み取りで、内蔵ディスプレイと蓋の状態について分かることも示す。
- **R5 実機検証の手順の下書き**: のちに `DEC-BLK-007` で解決した論点の判断に必要だった実機での確認事項と、R1〜R4 で残った不明点を、オーナーが実機で確かめる手順の下書きを作る。各手順に、目的、前提、操作、期待する結果、途中で止める条件、元に戻す方法を書く。電力や発熱の比較は、`sudo` の要らない方法（例: `ioreg -rn AppleSmartBattery` の電流の値）を優先する。

## 範囲

書いてよい: なし（リポジトリのファイルを変更しない）。報告は PM への返答で行う。実験のコードと外部のリポジトリの clone は、リポジトリの外の作業用ディレクトリに置く。

読むもの:

- のちに `DEC-BLK-007` で解決した論点の文書
- `DEC-BLK-001`、`DEC-BLK-002`、`DEC-SET-005`、`DEC-UI-009`、`HYP-BLK-001`、`HYP-BLK-008`、`EVID-BLK-003`、`SPEC-BLK-002`、`REQ-SYS-007`
- `Packages/CapsaicinKit/Sources/CapsaicinPlatform/Power/`
- 外部のソースと資料

## 作るもの

1. R1 の比較表と、問いごとの結論
2. 根拠。ソースはリポジトリ、コミット、ファイル、行で示す。Web の資料は実際に開いた URL だけを示す。SDK のヘッダーは絶対パスで示す。確かめた事実、ソースからの推論、未確認の推測を分ける。
3. 根拠と仮説の下書き。ID は付けず、PM が振る。
4. R5 の手順の下書き

## 守ること

- 輝度、ガンマ、ディスプレイの構成への書き込みをしない。設定系の関数（`Set` を含むもの）を呼ばない。
- `pmset` の設定変更、`sudo`、`launchctl`、Capsaicin と `scripts/manual/` の実行をしない。
- Capsomnia のソースは読んでよいが、コードを写さない（`REQ-SYS-007`）。報告に載せるのは方式の説明と所在だけにする。
- サブエージェントを起動しない。

## 完了条件

- R1〜R5 のそれぞれに、根拠のある答えか、確かめられなかった理由がある。
- R1 の表に、少なくとも上の5つの候補がある。

## 検証

PM が報告の根拠を読み、主要な主張をソースで照合する。リポジトリの変更がないことを `git status --short` で確かめる。

## レビュー

PM が報告を読み、次を照合した。

- 試作プログラムが設定系の関数を呼んでいないこと（ソースを読んだ）と、ログの値が報告と一致すること。
- `IOPM.h` の `kIOPMMessageClamshellStateChange` の説明（蓋の状態と `AppleClamshellCausesSleep` のビットを1つの通知で送る）。
- リポジトリを変更していないこと（`git status --short`）。

報告は、調べた Mac の macOS を 27.2.1 と読み、「macOS 26 の実測ではない」としていた。対応環境は macOS 26 以上（`DEC-SYS-003`）なので、対応環境での観測として扱う。

報告が蓋を閉じた状態の観測とした値のうち、`AppleARMBacklight` の `IODisplayParameters` は、PM が蓋を開けた後に読み直しても同じ値だった。レジストリの値はバックライトの実際の状態を示さないと判断し、`EVID-BLK-008` に残した。

結果は `EVID-BLK-007`、`EVID-BLK-008`、`HYP-BLK-010`〜`HYP-BLK-012` と、のちに `DEC-BLK-007` で解決した論点の更新に反映した。実機の手順は `TASK-052` で作る。
