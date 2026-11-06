# LaunchAgent の非起動条件を調べる準備

電源・LED・入力状態に触れない専用プローブで、`RunAtLoad = false` と
`KeepAlive = { Crashed = true }` の組み合わせを調べる。
承認済みなのは準備だけであり、実機での登録・起動・ログアウトは未実施である。

```text
[準備: コンパイルとファイル生成だけ]
│
▼
[独立レビュー → PM が利用者へ渡す → 利用者が実機操作を承認]
│
▼
[撤去方法を確認 → 登録 → bootstrap の非起動 → 手動起動と終了・復旧]
│                         └─ 意図せず起動 → 記録して中止・撤去
▼
[ログアウト・ログインの非起動 → 記録 → 専用項目だけ撤去]
```

## 準備だけを実行する

リポジトリのルートで次を実行する。既存の Nix 開発環境とホスト Xcode の
`xcrun clang`、`codesign` を使う。新しい依存は導入しない。

```sh
nix develop --command python3 scripts/manual/launchagent-probe/prepare.py prepare
```

成功時は `.build/manual/launchagent-probe-<UUID>/` の絶対パスを表示する。
毎回新しい UUID とモード `0700` の作業領域を作る。既存の領域は再利用しない。
コンパイルと ad-hoc 署名だけを行い、生成した実行ファイルは起動しない。
`launchctl` の実行も、LaunchAgents への配置も行わない。

生成物は `probe`、ビルド用 C ソースとヘッダー、専用 plist、空の `events.log` と `probe-stderr.log`、
`manifest.json`、パスを確定した `instructions.md` である。
失敗時も自動削除せず、その実行の部分生成物のパスをエラーに表示する。
完了した manifest がない領域では手動実験を始めない。

## 実機操作は生成した手順のレビュー後に利用者だけが行う

[`procedure.md`](procedure.md) は手順の原本であり、そのまま実行しない。
生成された `instructions.md` には manifest 固有の絶対パス、UID、ラベルが入る。
レビュー担当は登録より前に撤去対象と非起動の判定条件を確認する。
エージェントは生成した手順のコマンドを実行しない。

`operations.py install/cleanup/observe <manifest.json の絶対パス>` は別承認後の手動操作専用である。
install は完成済み plist のハードリンクを同じ配置ディレクトリの排他的ステージに置き、
そこから最終パスを上書きなく原子的に公開する。別ファイルシステムの場合は中止する。
cleanup は現在 UID、ジョブの実行先・配置元、manifest の inode・内容を再照合し、
対象ジョブだけを解除して、専用 plist・ステージ・作業領域だけをゴミ箱へ移す。
未登録が確定していれば、配置の中断時も同じ manifest から回収できる。
symlink・別オブジェクト・内容変更・未知の状態なら触らず中止する。
import・prepare・テストから実環境の配置・解除・削除は行わない。

実機操作はユーザー領域の専用 LaunchAgent 一件を永続的に登録し、
プローブを起動・正常終了・一度だけ自己クラッシュさせ、ログアウトを伴う。
専用プローブはシェルや任意のコマンドを受け付けず、数値 PID に signal を送らない。
各インスタンスは最大 900 秒で正常終了する。登録自体は撤去まで残る。

## 観測できることと保証しないこと

ログには UNIX 時刻（UTC）、自身の PID、起動ごとの乱数 instance、専用ラベル、
イベントだけを記録する。環境変数や秘密情報は出力しない。
制御はその作業領域の最新 instance 専用ファイルだけを使う。
自己クラッシュ要求は消費後に `crash-used` を排他的に作り、自分に `SIGABRT` を発生させる。
次の instance に古い要求は渡らず、同じ領域で二度目の自己クラッシュは行わない。
core dump は無効にするが、OS がクラッシュ診断や通知を作る可能性はある。

これは ad-hoc 署名した通常の実行ファイルであり、LSUIElement アプリではない。
本体アプリの署名、バックグラウンド項目管理（BTM）、承認状態との一致は保証しない。
承認や署名の問題は設定を変えて解消せず、未判定として PM に報告する。
`XPC_SERVICE_NAME` は調べないため、起動元判定の仮説も検証しない。

macOS 同梱の `launchd.plist(5)`（`/usr/share/man/man5/launchd.plist.5`）は
KeepAlive による暗黙の RunAtLoad と
状態確認のための speculative launch を説明している。
非起動はこの一般説明と食い違う可能性のある未確認の仮説であり、成功を前提にしない。
有限の 120 秒観測で分かるのは、その環境・ラベル・実行形式・時間内での結果だけである。
準備と自動テストの成功は、launchd の仮説の裏付けにならない。
空のログと PID 不在だけでは起動試行を否定できない。
launchd 側の起動回数・終了・spawn/exec 失敗の情報を bootstrap と再ログインで別々に保存する。
print は安定 API ではなく、対象 OS のフィールドの意味・完全性は実機で未確認である。
必要な証拠が取得できなければ未判定とし、後の kickstart 成功で補わない。

## 準備の自動テスト

```sh
mkdir -p .build/tmp
TMPDIR="$PWD/.build/tmp" PYTHONPYCACHEPREFIX="$PWD/.build/pycache" \
  nix develop --command python3 -m unittest discover -s scripts/tests -p test_launchagent_probe.py -v
```

準備のコンパイラー・署名と、手動操作のコマンド結果を注入し、隔離した配置先で
上書き防止、中断、変更対象の拒否、制御要求を検査する。
出力失敗テストだけは C のテスト専用 shim をコンパイル・実行する。
本番の main は呼ばず、実プローブも launchd も起動しない。
