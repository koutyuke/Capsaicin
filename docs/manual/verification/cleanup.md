# 片付け: 開始前の状態へ戻す

検証を終えたら、どこまで進めたかにかかわらず必ず行う。今回の変更を取り除き、`prepare.md` で保存した開始前の状態へ戻し、結果を PM に渡す。確かめる仕様は `SPEC-BLK-007`、`SPEC-HLP-004`、`SPEC-HLP-005`、`SPEC-LCY-002`、`SPEC-LCY-005`、`SPEC-LCY-007`、`SPEC-SET-002` である。

動的確認（アプリの起動）を一度も始めていなければ、操作1の1で抜けて操作4へ進む。始めていれば、操作1から順に行う。

## 始める前に

- `prepare.md` で作った退避先 `B` と開始前の記録が読める。
- 既存のヘルパーがある環境では、動的確認を始めていない。

リポジトリのルートで devShell に入る。

```sh
cd <リポジトリのルート>
nix develop
```

devShell の中で退避先を入れ、足場を確かめる。`OK` が出なければ、退避先かチェックアウトが違うので止める。

```sh
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
just status
```

## 操作と期待

### 1. 抑止と今回設置したヘルパーを解除する

1. 動的確認を始めなかった場合は、変更した OS 設定だけを開始前の写真に合わせて戻し、操作4へ進む。以降の削除コマンドを実行しない。
2. アプリが動作中ならメニューの「スリープ防止をオフにする」で解除する。今回設置したヘルパーが残る場合は、設定の「ヘルパー」で「削除…」を選び、確認と管理者認証を承認する。残っていないことを確かめる。

   ```sh
   /bin/ls -l /Library/PrivilegedHelperTools/io.github.koutyuke.capsaicin.helper.debug /etc/sudoers.d/capsaicin_debug /Library/LaunchDaemons/io.github.koutyuke.capsaicin.helper.debug.plist
   ```

3. メニューの「Capsaicinを終了」で終了し、状態を読む。Capsaicin のアサーションがなく、LED が通常の Caps Lock 連動に戻ったことを目で確かめる。

   ```sh
   just status
   ```

4. `SleepDisabled` が開始値と違う場合だけ、開始値を読み直して戻す。

   ```sh
   case "$(cat "${B:?}/sleep-disabled.before.txt")" in
     0) /usr/bin/sudo /usr/bin/pmset -a disablesleep 0 ;;
     1) /usr/bin/sudo /usr/bin/pmset -a disablesleep 1 ;;
     *) printf '%s\n' '中止: 開始値が不明。pmset を変更しない' ;;
   esac
   just status
   ```

   期待: `SleepDisabled` が開始値と一致し、ヘルパー3ファイルがない。開始値が `1` の環境では動的確認を始めていないので、本来ここで変更は不要である。

   ヘルパー3ファイルが残る、`SleepDisabled` が戻らない、LED が通常連動に戻らない場合は止める。LED は `B` にある承認済みの LED 復旧手順で戻す。ヘルパーの削除に失敗したとき、システムファイルを手で削除しない。記録と設定を消さず、構成・エラー・残った値を PM に渡す。

### 2. 今回の LaunchAgent と設定・記録を取り除く

開始時はジョブが未読込だったことと、アプリが停止し、ヘルパー・LED・抑止を戻せていることが前提である。

1. 読み込み済みなら、今回の Debug ジョブだけを外す。最初の照会でサービスが見つからない場合は `bootout` を省く。別のエラーなら止める。

   ```sh
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   /bin/launchctl bootout "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   ```

2. 照会がサービスなしを示し、`just status` に Debug プロセスがないことを確かめてから、試験後のデータを保存する。照会が別のエラーなら先へ進まない。

   ```sh
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
   just status
   if [ -f "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/resume-record.after.json"; fi
   /usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.after.plist"
   ```

3. **次は今回の設定と再開用の記録を消す。退避物が読めることを先に確かめ、失敗したら実行しない。**

   ```sh
   if [ -f "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist" ]; then trash "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist"; fi
   if [ -f "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then trash "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
   /usr/bin/defaults delete io.github.koutyuke.capsaicin.debug
   ```

   期待: ジョブは未読込で、今回の plist・再開用の記録・Debug の設定が消える。ドメインが既にない旨だけなら、`defaults delete` の失敗は削除済みとして記録する。

   プロセスが残る、ヘルパーが残る、退避が失敗する、パスが想定と違う場合は止める。Release のドメインや IPC の共有ディレクトリには触れない。ゴミ箱を空にしない。再開用の記録を含む Application Support のディレクトリ全体は削除しない。

### 3. 既存のデータと OS 設定を戻す

復元後はアプリを起動しない。古い抑止セッションを再開させないため、開始時に停止済み・所有なしと確認した記録だけを戻す。

1. 開始前に存在したデータだけを戻す。

   ```sh
   if [ -f "$B/defaults.before.plist" ]; then /usr/bin/defaults import io.github.koutyuke.capsaicin.debug "$B/defaults.before.plist"; fi
   if [ -f "$B/resume-record.before.json" ]; then cp -p "$B/resume-record.before.json" "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
   if [ -f "$B/agent.before.plist" ]; then cp -p "$B/agent.before.plist" "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist"; fi
   ```

2. 戻したファイルを比較する。

   ```sh
   if [ -f "$B/resume-record.before.json" ]; then cmp "$B/resume-record.before.json" "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
   if [ -f "$B/agent.before.plist" ]; then cmp "$B/agent.before.plist" "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist"; fi
   /usr/bin/defaults read io.github.koutyuke.capsaicin.debug
   ```

3. 初めから存在しなかった対象は、`B` の `record.absent`、`agent.absent`、`defaults.absent` に照らし、存在しないことを確かめる。設定があった場合は `"$B/defaults.before.txt"` と読み戻しを比較する。
4. OS の外観、アクセントカラー、文字、VoiceOver、アクセシビリティ、バックグラウンド項目、機器の接続を開始前の写真と一致させる。変更していない項目には触れない。
   期待: `cmp` は何も出さず終了コード `0` で終わる。設定の内容が開始前と一致する。開始時はジョブが未読込なので、戻した plist を `bootstrap` しない。

   退避物が壊れている、ファイルが作り直される、OS の開始値が分からない場合は止める。データを足したり消したりせず、開始前と試験後の両方を PM に渡す。

### 4. 残っていないことを確かめ、結果を PM に渡す

1. 次の結果を `B` の開始前の記録と比べる。開始前からある他のアプリのアサーションは消さない。

   ```sh
   /usr/bin/pmset -g
   /usr/bin/pmset -g assertions
   /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/grep -E '^\s*(state|pid|runs) ='
   ```

2. 実施した各検証ファイルの結果（`"$B/result-*.txt"`）に、実行日、環境、成功／失敗／判定不能、観測値、画像やログの絶対パス、復元結果がそろっているかを確かめる。
3. PM に結果と `B` の所在を渡す。新しい根拠の ID の採番と仮説の更新は PM が行う。この手順の実行だけで仮説を確認済みにしない。

   期待: 状態が開始前に戻り、未実施を成功扱いしていない。起動前ゲートで止めた場合は「動的確認は未実施」と分かる。

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

- ヘルパー3ファイルの有無、`SleepDisabled` の開始値と現在値、アサーションの有無、LED の戻り
- ジョブを外す前後の `launchctl print`、`just status` の結果、`trash` した3つのパス、`defaults delete` の終了コード
- `cmp` の結果、`defaults` の読み戻し、`absent` マーカーとの照合、OS 設定を戻した項目
- 実施しなかった検証ファイルとその理由、戻した対象、残った対象、`B` の絶対パス
