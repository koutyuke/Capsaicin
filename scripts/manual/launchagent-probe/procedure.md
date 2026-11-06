# 専用 LaunchAgent を利用者だけが観測する手順

これはレビュー用の手動手順である。準備への承認は、以下の実行への承認ではない。
PM のレビューと利用者の実機操作への承認が済むまで登録に進まない。
所要時間はログイン操作を除き約 15 分。管理者権限は使わない。

```text
[対象照合 → 撤去方法を確認 → 登録]
│
▼
[bootstrap: 120 秒非起動] ─ 起動したら記録・中止・撤去
│
▼
[kickstart → 正常終了 → 120 秒非再起動 → 再 kickstart]
│
▼
[一度だけ自己クラッシュ → 120 秒以内に別 instance → 正常終了]
│
▼
[baseline 保存 → ログアウト・ログイン → 120 秒非起動 → 起動適格性確認]
│
▼
[証拠保存 → 専用ジョブを bootout → 専用 plist と作業領域をゴミ箱へ]
```

## 1. 対象と記録場所を照合する

この生成済み手順と `manifest.json` を照合する。別実行の値を混ぜない。
以下の `id -u` が `@@UID@@` 以外なら中止する。

```sh
/usr/bin/id -u
/bin/cat @@MANIFEST@@
/usr/bin/sw_vers
/usr/bin/uname -m
```

端末出力と各段階の UTC 時刻・結果・観測開始/終了時刻を利用者の実験記録に保存する。
記録には OS ビルド、機種、バックグラウンド項目の既存承認状態も含める。
`events.log` は追記専用の履歴として残し、途中で空にしない。
プローブは最大 900 秒で正常終了する。`timeout`、ログ書き込み失敗、観測中断が
あれば、その段階は未判定として止める。

## 2. 登録より先に撤去方法を確認する

登録前はこの節を読んで撤去対象を確認するだけで、撤去コマンドは実行しない。
中止・完了時は、証拠を作業領域の外へ保存してから次を実行する。
**専用ジョブの解除と、専用 plist・ステージ・作業領域のゴミ箱への移動を伴う。**
新しいシェルでも、この絶対パスの manifest だけで復旧できる。以前のシェル変数は不要である。

```sh
@@MANUAL@@ cleanup @@MANIFEST@@
```

ヘルパーは各操作の直前に現在 UID、作業領域の inode、準備した実行ファイルと plist の
inode・所有者・モード・更新時刻・内容を manifest と照合する。
配置済み plist とステージも準備 plist と同じ inode・内容であることが必要である。
symlink、別オブジェクトへの置換、内容変更、不明な状態は、変更対象に触らず中止する。
登録済みなら print の実行先と配置元も照合してから `bootout @@TARGET@@` だけを実行する。
ラベルだけの一致では解除しない。ドメイン全体の解除や保存 PID への signal は使わない。

未登録は、終了コード 113 と、この UID・ラベルに対する英語の
`Could not find service` 診断の完全一致でだけ判定する。
権限不足、ドメイン不在、未知の文面では中止する。
bootout が失敗しても、再照合で確実に未登録なら自身のファイルだけを回収できる。
まだ登録されている、または不明なら削除しない。
登録前の中断では bootout を呼ばず、照合できた専用ステージ・plist・作業領域だけを回収する。

`/usr/bin/trash` がない、照合や移動が失敗した場合は、その出力と残存パスを PM に渡す。
手作業の削除や `rm` に切り替えない。並行して同じ対象を変更せず、
途中で止まった場合は manifest を保ったまま、このコマンドから再開する。

## 3. 既存対象がないことを確かめ、専用 plist だけを配置する

以下の print は「指定サービスが見つからない」こと、test は成功することが必要である。
print が成功する、権限エラーなどで不在を判定できない、または test が失敗する場合は中止する。
既存のジョブやファイルを上書きしない。バックグラウンド項目の enable/disable も行わない。

```sh
/bin/launchctl print @@TARGET@@
test ! -e @@INSTALLED@@ && test ! -L @@INSTALLED@@
/usr/bin/wc -l @@LOG@@
```

ログは `0` 行が必要である。配置先の `~/Library/LaunchAgents` がない、または
シンボリックリンクの場合は中止して PM に報告する。
配置の影響は manifest の専用 plist 一件の追加であり、次回ログイン時にも読み込まれる。
作業領域を移動せず、次を一度だけ実行する。

```sh
@@MANUAL@@ install @@MANIFEST@@
```

ヘルパーは完成済み plist を排他的なハードリンクで配置先と同じディレクトリの
専用ステージに置き、そこから最終パスをハードリンクで原子的に公開する。
既存ファイル・symlink を上書きせず、不完全な最終ファイルは公開しない。
作業領域と配置先が別ファイルシステムなら中止する。コピーには切り替えない。
ステージは撤去まで残し、manifest に記録した inode・内容で識別する。
公開前後のどこで中断しても、最終パスは未作成か完成済みであり、
専用ステージを含め第 2 節から回収する。ステージの変更・置換は回収せず中止する。
成功時だけ進む。失敗・中断時は bootstrap せず、第 2 節へ戻る。

## 4. bootstrap だけでは起動しないかを観測する

```sh
/bin/date -u
/bin/launchctl bootstrap @@DOMAIN@@ @@INSTALLED@@
/bin/launchctl print @@TARGET@@
@@MANUAL@@ observe @@MANIFEST@@
/bin/cat @@WORKSPACE@@/probe-stderr.log
```

bootstrap が成功して print に指定ラベルのジョブが存在することを記録する。
失敗・承認待ち・無効化の表示は非起動の成功ではなく未判定である。
この時点から 120 秒待ち、次を記録する。

```sh
/bin/sleep 120
/bin/date -u
/usr/bin/wc -l @@LOG@@
/bin/cat @@LOG@@
/bin/launchctl print @@TARGET@@
@@MANUAL@@ observe @@MANIFEST@@
/bin/cat @@WORKSPACE@@/probe-stderr.log
```

ログ `0` 行と PID 不在だけでは非起動を示さない。bootstrap 直後と 120 秒後の print 原文で、
launchd 側の起動回数 `runs`、状態、終了コード・終了シグナル、spawn/exec エラーも記録する。
`probe-stderr.log` も保存する。プローブは start より前の失敗を stderr と非ゼロ終了で示すが、
exec 前の失敗や stderr の書き込み失敗まで記録できるとは限らない。

**start、PID、起動試行回数、spawn/exec 失敗、終了の証拠が一つでもあれば非起動の成功ではない。
以後のクラッシュやログアウトは行わず、出力を保存して撤去へ進む。**
証拠の欠落・読み取り不能・意味が不明なフィールドは未判定とし、kickstart に進まない。
`observe` はこの条件を保守的に検査し、`unexpected-start` または `inconclusive` で止める。
`no-start-candidate` も成功ではない。後述の出力形式・意味の確認と観測窓の記録が必要である。

同梱の `/usr/share/man/man1/launchctl.1` は print が安定 API ではないと明記している。
`runs` がすべての起動試行を含むか、終了・spawn/exec 情報が取得できるかは実機で未確認である。
ヘルパーは明示的な `runs = 0`、`last exit code = (never exited)`、
`last spawn error = 0`、`state = not running` を候補の必要条件とする。
対象 OS でフィールドの意味と完全性を一次資料で確認できなければ未判定として PM に渡す。
エラー欄が表示されないことを「エラーなし」と読み替えない。

## 5. 手動起動、正常終了、再手動起動を分けて観測する

```sh
/bin/launchctl kickstart @@TARGET@@
/bin/sleep 5
/bin/cat @@LOG@@
/bin/launchctl print @@TARGET@@
```

期待は一つの `start` と動作中 PID である。5 秒で記録がなければ最大 120 秒まで待つ。
それでも起動しない場合は未判定として撤去する。
成功はこの時点で起動可能だった証拠であり、前の観測窓の欠落や起動失敗を帳消しにしない。
次は数値 PID を使わず、最後の start の instance に正常終了を要求する。

```sh
@@CONTROL@@ exit
/bin/sleep 120
/bin/cat @@LOG@@
/bin/launchctl print @@TARGET@@
```

期待は同じ instance の `normal-exit` と、その後に新しい start がないことである。
print の起動回数が増えた、spawn/exec 失敗や別の終了がある場合も中止する。
正常終了しない、または再起動したら結果を記録して中止・撤去する。
次に同じ kickstart を再実行し、別 instance の start と PID を記録する。

```sh
/bin/launchctl kickstart @@TARGET@@
/bin/sleep 5
/bin/cat @@LOG@@
/bin/launchctl print @@TARGET@@
```

## 6. 一度の自己クラッシュから別 instance が起動するかを観測する

プローブ自身が `SIGABRT` を発生させる。OS の診断通知が出る場合がある。
次の制御は作業領域ごとに一度だけで、二度目を試すために印を消してはならない。

```sh
@@CONTROL@@ crash
/bin/sleep 120
/bin/cat @@LOG@@
/bin/launchctl print @@TARGET@@
```

期待は前の instance の `self-crash` と、別 instance の `start` 一件、動作中 PID である。
新しい start がない、複数の再起動、`crash-refused`、承認エラーがあれば記録して中止・撤去する。
成功したら次で正常終了し、120 秒の間に新しい start がないことを記録する。

```sh
@@CONTROL@@ exit
/bin/sleep 120
/bin/cat @@LOG@@
/bin/launchctl print @@TARGET@@
```

## 7. baseline を保存してログアウト・ログインを別に観測する

動作中 PID がなく最後が `normal-exit` であることを確認する。
次の出力を「ログイン前 baseline」として実験記録に保存する。
ジョブと plist は登録したままにする。bootstrap や kickstart を繰り返さない。

```sh
/bin/date -u
/usr/bin/wc -l @@LOG@@
/bin/cat @@LOG@@
/bin/launchctl print @@TARGET@@
```

次でログの baseline を排他的に保存する。既存 baseline は上書きしない。

```sh
(set -C; /bin/cat @@LOG@@ > @@WORKSPACE@@/baseline.log)
```

baseline の作成・内容照合に失敗したらログアウトしない。

**ログアウトで未保存の作業が失われる。全アプリの作業と実験記録を保存してから、
利用者が Apple メニューでログアウトし、同じユーザーにログインする。**
再ログイン後、プローブを手動起動せず 120 秒観測する。

```sh
/bin/date -u
/bin/launchctl print @@TARGET@@
@@MANUAL@@ observe @@MANIFEST@@ --relogin
/bin/cat @@WORKSPACE@@/probe-stderr.log
/bin/sleep 120
/bin/date -u
/usr/bin/wc -l @@LOG@@
/bin/cat @@LOG@@
/bin/launchctl print @@TARGET@@
@@MANUAL@@ observe @@MANIFEST@@ --relogin
```

期待は baseline からログが増えず、指定ジョブが存在し動作中 PID がないことである。
さらに第 4 節と同じ起動回数・終了・spawn/exec 証拠を、再ログイン直後と 120 秒後で保存する。
最初の observe が未判定・起動試行ありなら待機を打ち切って撤去する。
新しい GUI セッションの回数は前セッションの値と差し引かず、ゼロからの起動試行を確認する。
start や起動試行・実行失敗があれば、以後の起動をせず撤去する。
ジョブ不在・証拠欠落・承認や無効化の問題は未判定とする。
必要な証拠が揃った観測候補だけ、次で再ログイン後も起動可能なことを確認する。

```sh
/bin/launchctl kickstart @@TARGET@@
/bin/sleep 5
/bin/cat @@LOG@@
/bin/launchctl print @@TARGET@@
```

120 秒以内に新しい start と動作中 PID が確認できなければ未判定。
後の kickstart は以前の非起動を証明しない。有限の 120 秒窓の外の非起動も保証しない。
成功時も保証はこの実行形式と観測窓に限る。正常終了を要求し、ログを保存する。

```sh
@@CONTROL@@ exit
/bin/sleep 5
/bin/cat @@LOG@@
```

最後に第 2 節の専用ジョブの bootout と撤去を行う。
結果・未判定の理由・残存対象を PM に渡し、仮説やチケットの状態は変更しない。
