# 片付け: 開始前の状態へ戻す

検証を終えたら、どこまで進めたかにかかわらず必ず行う。今回の変更を取り除き、`prepare.md` で保存した開始前の状態へ戻し、結果を PM に渡す。確かめる仕様は `SPEC-BLK-007`、`SPEC-BLK-013`、`SPEC-HLP-004`、`SPEC-HLP-005`、`SPEC-LCY-002`、`SPEC-SET-002` である。

`resume-record.json` と agent の片付けは、試作とその検証用ビルドの実データを保護するための手順である。製品が抑止のセッションや所有を保存する前提にはしない（`DEC-LCY-010`）。

動的確認（アプリの起動）を一度も始めていなければ、操作1の1に従う。始めていれば、操作1から順に行う。

## 始める前に

- `prepare.md` で作った退避先 `B` と開始前の記録が読める。
- 既存の登録や旧方式のファイルがある環境では、動的確認を始めていない。

リポジトリのルートで devShell に入る。

```sh
cd <リポジトリのルート>
nix develop
```

devShell の中で退避先を入れ、足場を確かめる。`OK` が出なければ、退避先かチェックアウトが違うので止める。

```sh
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
if [ -f "$B/app-path.txt" ]; then APP="$(cat "$B/app-path.txt")"; printf 'APP=%s\n' "$APP"; fi
```

## 操作と期待

### 1. 抑止と今回設置したヘルパーを解除する

1. 動的確認を始めなかった場合は、変更した OS 設定だけを開始前の写真に合わせて戻す。今回 `/Applications` に置いただけのアプリがあれば Finder でそのアプリだけをゴミ箱に移す。既存アプリと区別できなければ移動せず、所在を PM に渡す。設定・記録・既存の登録には触れず、操作4へ進む。
2. 動的確認を始めた場合は、動作中のアプリでメニューの「スリープ防止をオフにする」を選ぶ。アプリが止まっていれば、検証対象を確かめて起動する。

   ```sh
   printf '%s\n' "$APP"
   /usr/bin/open "$APP"
   ```

   今回登録したヘルパーが「有効」か「システム設定での許可待ち」なら、設定の「ヘルパー」で「削除…」を選び、確認の「削除」を押す。「状態」が「未インストール」になることを確かめる。登録を外すときに管理者のパスワードは求められない。スリープ設定を戻せず削除に失敗したときは、登録を残して手順4で値を戻し、戻せた後で「削除…」と確認の「削除」を選び直す。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/sfltool dumpbtm
   ```

3. 「一般」の「ログイン時に起動」をオフにし、システム設定の「ログイン時に開く」から外れたことを確かめる。メニューの「Capsaicinを終了」で終了し、状態を読む。Capsaicin のアサーションがなく、LED が通常の Caps Lock 連動に戻ったことを目で確かめる。

   ```sh
   just status
   ```

   `No Debug processes.` が出ることを確かめる。`just status` は PR Debug ビルドも表示するが、Release のプロセスは表示しない。想定外のコピーが動いていたら、`just stop` で一括終了せず、パスを記録して中止する。

4. `SleepDisabled` が開始値と違う場合だけ、開始値を読み直して戻す。

   ```sh
   case "$(cat "${B:?}/sleep-disabled.before.txt")" in
     0) /usr/bin/sudo /usr/bin/pmset -a disablesleep 0 ;;
     1) /usr/bin/sudo /usr/bin/pmset -a disablesleep 1 ;;
     *) printf '%s\n' '中止: 開始値が不明。pmset を変更しない' ;;
   esac
   /usr/bin/pmset -g
   ```

   設定変更のコマンドは成功しても何も出力しないので、直後の `pmset -g` で値を確かめる。

   期待: `SleepDisabled` が開始値と一致し、ヘルパーが「未インストール」、ログイン時の起動がオフである。ad-hoc 署名のビルドだけを使った場合は「このビルドでは使用不可」で登録なしの状態でよい。バックグラウンドの一覧の項目はこの段階で残ることがある。開始値が `1` の環境では動的確認を始めていないので、本来ここで変更は不要である。

   登録を外せない、`SleepDisabled` が戻らない、LED が通常連動に戻らない場合は止める。LED は `B` にある承認済みの LED 復旧手順で戻す。ヘルパーの登録を手作業で消さず、値を戻す手段を残すためアプリの削除へ進まない。記録と設定も消さず、状態・エラー・残った値を PM に渡す。

### 2. 今回のアプリと設定・記録を取り除く

開始時に既存の登録がなく、アプリが停止し、ヘルパー・LED・抑止を戻せていることが前提である。mainApp の登録も外している。`APP` と検証中に使ったほかの worktree のビルドを、今回のものと識別できる。

1. プロセスがないことを確かめ、試験後の設定と試作の状態記録を保存する。

   ```sh
   just status
   if [ -f "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/resume-record.after.json"; fi
   /usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.after.plist"
   ```

2. Finder で `APP` の今回のアプリをゴミ箱に移す。worktree 切り替えで使ったビルドも、記録した絶対パスで今回のものと確認してからゴミ箱に移す。agent の登録はアプリの削除で片付け、定義ファイルを手で消したり、手作業で登録を外したりしない。ゴミ箱に今回の古いアプリが残っていると、システム設定の項目が消えないことがある（`EVID-LCY-003`）。

   **ゴミ箱を空にすると、中身は元に戻せない。** 既存のゴミ箱の中身を保存し、オーナーが空にしてよいと判断した場合だけ Finder から空にする。空にできなければ削除の確認は未完了とし、残したアプリの所在を PM に渡す。

3. **次は今回の設定と試作の状態記録を消す。退避物が読めることを先に確かめ、失敗したら実行しない。**

   ```sh
   if [ -f "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then trash "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
   /usr/bin/defaults delete io.github.koutyuke.capsaicin.debug
   ```

   期待: 今回のアプリと、検証用ビルドが登録した agent のジョブ、システム設定の Capsaicin の項目、今回の試作の状態記録・Debug の設定が消える。ドメインが既にない旨だけなら、`defaults delete` の失敗は削除済みとして記録する。

   プロセスやヘルパーの登録が残る、退避が失敗する、パスが想定と違う場合は止める。Release のドメインや IPC の共有ディレクトリには触れない。試作の状態記録を含むユーザーの Application Support ディレクトリ全体も削除しない。デーモンの起動の記録 `/Library/Application Support/io.github.koutyuke.capsaicin.debug/boot-session-uuid` とそのディレクトリは削除後も残る。Release も `/Library/Application Support/io.github.koutyuke.capsaicin/` に記録を持つが、どちらにも触れない。`sfltool resetbtm` はほかのアプリの登録も消すので使わない。

### 3. 既存のデータと OS 設定を戻す

復元後はアプリを起動しない。試作の状態記録を読む検証用ビルドで意図しない制御を行わないため、開始時に停止済み・所有なしと確認した記録だけを戻す。

1. 開始前に存在したデータだけを戻す。

   ```sh
   if [ -f "$B/defaults.before.plist" ]; then /usr/bin/defaults import io.github.koutyuke.capsaicin.debug "$B/defaults.before.plist"; fi
   if [ -f "$B/resume-record.before.json" ]; then cp -p "$B/resume-record.before.json" "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
   ```

2. 戻したファイルを比較する。

   ```sh
   if [ -f "$B/resume-record.before.json" ]; then cmp "$B/resume-record.before.json" "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
   /usr/bin/defaults read io.github.koutyuke.capsaicin.debug
   ```

3. 初めから存在しなかった対象は、`B` の `record.absent`、`defaults.absent` に照らし、存在しないことを確かめる。設定があった場合は `"$B/defaults.before.txt"` と読み戻しを比較する。
4. OS の外観、アクセントカラー、文字、VoiceOver、アクセシビリティ、バックグラウンド項目、機器の接続を開始前の写真と一致させる。変更していない項目には触れない。
   期待: `cmp` は何も出さず終了コード `0` で終わる。設定の内容が開始前と一致する。開始時に登録はなかったので、SMAppService の登録を作り直さない。

   退避物が壊れている、ファイルが作り直される、OS の開始値が分からない場合は止める。データを足したり消したりせず、開始前と試験後の両方を PM に渡す。

### 4. 残っていないことを確かめ、結果を PM に渡す

1. 次の結果を `B` の開始前の記録と比べる。開始前からある他のアプリのアサーションは消さない。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/pmset -g assertions
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
   /usr/bin/sfltool dumpbtm
   ```

2. 実施した各検証ファイルの結果（`"$B/result-*.txt"`）に、実行日、環境、成功／失敗／判定不能、観測値、画像やログの絶対パス、復元結果がそろっているかを確かめる。
3. PM に結果と `B` の所在を渡す。新しい根拠の ID の採番と仮説の更新は PM が行う。この手順の実行だけで仮説を確認済みにしない。

   システム設定の「一般 > ログイン項目と機能拡張」も開始前の写真と比較する。項目名は実装にないため、検証時の画面で照合する。

   期待: 状態が開始前に戻り、今回の agent とデーモンの照会はサービスなしになる。BTM の過去の記録だけが残る場合は、使用中の登録と区別して記録する。起動の記録のディレクトリは仕様どおり残るので削除の失敗に数えない。起動前に止めた場合は既存の登録が変わっておらず、「動的確認は未実施」と分かる。

   戻せていないものが1つでもあれば「検証完了」とせず、残った対象・開始値・現在値を PM に報告する。

## 中止するとき

止めた操作より後へ進まない。`B`、記録、設定を消さず、止めた操作、残った対象、開始値、現在値を `"$B/result-cleanup.txt"` に書いて PM に渡す。

## 元に戻す

この手順そのものが復元である。`B` は結果と復元材料なので、PM の受領と復元の確認が済むまで残す。受領後、オーナーが保存不要と判断した場合だけ、絶対パスを確かめてから次を実行する。`rm`、Git の変更、Release のデータの削除は行わない。

```sh
printf '%s\n' "$B"
trash "${B:?}"
```

## 記録

`"$B/result-cleanup.txt"` に次を書く。

- ヘルパーの状態、ログイン時の起動の登録、`SleepDisabled` の開始値と現在値、アサーションの有無、LED の戻り
- 削除前後の `launchctl print` と BTM、システム設定の項目、ゴミ箱へ移したアプリの絶対パス、ゴミ箱を空にしたか、残した起動の記録、`defaults delete` の終了コード
- `cmp` の結果、`defaults` の読み戻し、`absent` マーカーとの照合、OS 設定を戻した項目
- 実施しなかった検証ファイルとその理由、戻した対象、残った対象、`B` の絶対パス
