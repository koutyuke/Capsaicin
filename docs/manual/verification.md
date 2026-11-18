# 実機で Capsaicin を確認して元に戻す手順

オーナーが承認済みの検証用 Mac で、Debug アプリの起動、抑止、復旧、画面を確認する手順である。ヘルパーとログイン時の起動は、`S-Preview` のラベルで作る署名・公証済みの PR Debug ビルド（`DEC-SYS-023`）を `/Applications` に置いて確認する。システム設定の許可を変更し、一部の試験では `sudo pmset` でスリープの設定を変える。ログアウト・再起動で作業を中断する。全項目の所要時間は未実測である。

本文のコマンドはまだ実行しておらず、ソースとの静的照合だけを行っている。実際に走らせた記録が残るまでは、ここに書いた期待値を「確かめた事実」として扱わない。独立した LED 復旧手段がない場合は1.4で止める。

実行するのはオーナーだけである。justfile の `app` グループ（`start`、`stop`、`restart`、`status`）は、エージェントもオーナーの承認を得て実行できる（`DEC-SYS-024`）が、この手順書の操作はオーナーが行う。

## この手順の読み方

各小節は「目的 → 前提 → 操作 → 期待 → 中止 → 復元 → 記録」の順に並ぶ。操作の番号と期待の番号は対応する。上から順に実行し、前提がそろわない項目は飛ばして判定不能とする。飛ばした項目を成功に数えない。

失敗を無視して次へ進む一括実行はしない。異常が出たら後続の試験を止め、9節へ進む。

記録は、生の出力を貼るのではなく「期待と照らした結論」で書く。たとえば `2.2-3: ログイン後 state=not running、pid なし` のように、どの操作の、何が、期待どおりだったかを残す。生の出力、画面写真、録画は `B` に置き、結果欄にはその絶対パスを書く。

確認に使うコマンドは操作ごとに示す。メニュー、システム設定、ディスプレイの開閉、目視だけの項目にはコマンドがなく、本文でその旨を書く。

### 用語

| 言葉 | この手順での意味 |
| --- | --- |
| agent のジョブ | バンドル内の定義を `SMAppService.agent` で登録したもの。Debug のラベルは `io.github.koutyuke.capsaicin.debug`。クラッシュ時にアプリを起動し直す |
| 引き渡し | 直接起動したアプリが agent を登録して `kickstart` で起動を求め、成功したら終了する仕組み。動き続けるのは agent から起動した個体である |
| mainApp | `SMAppService.mainApp` によるログイン時の起動の登録。「ログイン時に起動する」で切り替える。agent の登録とは別である |
| デーモン | バンドル内の定義を `SMAppService.daemon` で登録したヘルパー。Debug のラベルと Mach サービス名は `io.github.koutyuke.capsaicin.debug.helper` |
| `APP` | 今回確認するアプリの絶対パス。署名付きの PR Debug ビルドでは `/Applications/Capsaicin.app` を使う |
| BTM の記録 | `sfltool dumpbtm` が示す、ログイン項目とバックグラウンドの登録の記録 |
| `SleepDisabled` | `pmset -g` に出るシステム全体の値。`1` ならスリープしない。この手順では開始時は `0` を前提にする |
| `B` | 1.2 で作る退避先。設定、再開用の記録、登録状態の読み取り結果、画面写真、結果をここに置く。最後まで消さない |

「期待」と実測が違ったら、まず実測をそのまま残す。そのうえで、期待の書き方が悪いのか、製品が期待と違うのかを切り分ける。判断がつかなければ、その項目を判定不能として PM に渡す。

### 判定不能と中止の使い分け

- **判定不能**: 前提がそろわない、測る手段がない、結果が他の要因と区別できない。試験そのものは安全に続けられる。
- **中止**: 状態が期待から外れ、このまま進むと復元できなくなるおそれがある。後続を止め、9節で戻す。

中止したときは、どの操作の直後に、何が、どう違ったかを書く。中止した試験を「失敗」と混ぜない。製品の不具合が疑われる場合だけ失敗とし、根拠になる出力を添える。

## 全体の流れ

```text
[1. 記録・退避] ──復旧手段なし／既存の常駐処理あり──▶ [中止・保存物を保管]
│
▼
[2〜4. 起動・抑止・ヘルパー] ──異常──▶ [9. 復元・PMへ報告]
│
▼
[5〜8. LED・再開・CLI・画面] ──異常──▶ [9. 復元・PMへ報告]
│
▼
[9. 開始前の状態へ復元・結果をPMへ渡す]
```

## 0. 毎回の始め方

1節は最初の1回だけ行う。1節を終えていれば、リポジトリのルートで devShell に入り、メモした退避先の絶対パスを `B` に入れる。`APP` も保存したパスから戻す。ログアウトや再起動の後も同じ手順で戻す。

```sh
cd <リポジトリのルート>
nix develop
B='メモした退避先の絶対パスに置き換える'
test -f "$B/repository-path.txt"
test "$(cat "$B/repository-path.txt")" = "$PWD"
APP="$(cat "$B/app-path.txt")"
```

どちらかの `test` が失敗したら、退避先かチェックアウトが違うので止める。各小節を始める前に、次で足場を確かめる。アプリを起動するかどうかは各小節の前提に従う。2.2、4.4、4.6など、起動していないことが条件の試験では起動しない。

```sh
printf 'B=%s\n' "$B"
printf 'APP=%s\n' "$APP"
/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
/bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
/usr/bin/pmset -g
/usr/bin/pmset -g assertions | /usr/bin/grep -i capsaicin
```

- 起動中なら、agent が `state = running` で、`program` が `$APP/Contents/MacOS/Capsaicin` を指し、プロセスが1つだけで、その PID がジョブの `pid` と一致することを確かめる。検索で行が出ないことと、照会自体の失敗を区別する。
- PR Debug ビルドの起動には `/usr/bin/open "$APP"`、終了にはメニューを使う。ログアウトや再起動の試験では、メニューから先に終了せず、各節の操作に従う。
- justfile の `app` グループはチェックアウト内の手元のビルド用で、`/Applications` のビルドには使わない。`just status` は agent の `program` とチェックアウトのパスを比較するが、プロセスの一覧はビルド先のパスだけが対象である。PR Debug ビルドの不在を判断する用途には使わない。
- 手元のビルドで `just start` を使うと、読み込み済みの Debug ジョブを外してからアプリを開き、SMAppService の登録と引き渡しはアプリに任せる。`just restart` はビルド後に `stop`、`start` の順に実行する。`just stop` の `SIGTERM` では後片付けが行われないので、残留は上のスリープ状態の照会で確認する。

## 1. 準備し、開始前の状態を保存する

この節で「元に戻せる状態」を作る。前提を満たせない環境では2節以降を実施しない。1.1〜1.3 で状態を読み取って退避し、1.4 でビルドと署名を確認して起動前の準備を終える。

### 1.1 実行者と検証環境を固定する

- **目的**: `SPEC-LCY-005`、`SPEC-LCY-007`、`SPEC-HLP-005` の確認で既存環境を失わない。
- **前提**: 実行者はオーナーである。エージェントは本文のコマンドを実行しない。Apple Silicon、macOS 26 以上、Xcode 27.2、Nix の flakes を用意する。`sudo pmset` を使う試験では、その操作の承認と認証手段も用意する。未保存の作業を保存する。
- **操作**:
  1. Release と Debug の Capsaicin が両方停止している検証用 Mac を使う。既存のアプリが動作中なら、本手順では終了させず中止する。Release を検証中に起動しない。
  2. ターミナルでリポジトリのルートを開き、`nix develop` で devShell の Bash に入る。以後のコマンドはこのシェルで実行する。

     ```sh
     nix develop
     /usr/bin/xcode-select -p
     /usr/bin/sw_vers
     /usr/bin/uname -m
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     ```

- **期待**: Developer ディレクトリが Xcode 内を指し、CPU は `arm64` である。最後の検索でアプリが見つからない。
- **中止**: アプリが動作中、環境が非対応、承認がない場合。Xcode の選択は変更しない。
- **復元**: まだ状態を変更していないので不要である。
- **記録**: macOS の版とビルド番号、機種、`xcode-select -p` の出力を `B` の結果用メモに写す。

### 1.2 読み取り結果と退避先を残す

- **目的**: `SPEC-HLP-005`、`SPEC-LCY-007` の開始前の状態を後から比較できるようにする。
- **前提**: 1.1 が完了している。`trash` が使えることを `command -v trash` で確かめる。なければ削除操作を始めず PM に相談する。
- **操作**:
  1. 所有者だけが読める退避先を作り、チェックアウトのパスを記録する。

     ```sh
     umask 077
     B="$(/usr/bin/mktemp -d "$HOME/Capsaicin-verification.XXXXXX")"
     printf '%s\n' "$B"
     printf '%s\n' "$PWD" > "$B/repository-path.txt"
     ```

  2. 表示した `B` の絶対パスを、別のメモにも保存する。再ログイン後は0節で同じ退避先を入れ直す。`mktemp` を再実行しない。
  3. 開始前の状態を保存する。

     ```sh
     /usr/bin/pmset -g > "$B/pmset.before.txt"
     /usr/bin/pmset -g custom > "$B/pmset-custom.before.txt"
     /usr/bin/pmset -g assertions > "$B/assertions.before.txt"
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" > "$B/agent.before.txt" 2>&1
     printf '%s\n' "$?" > "$B/agent-print.exit.txt"
     /bin/launchctl print-disabled "gui/$(id -u)" > "$B/disabled.before.txt"
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin" > "$B/release-agent.before.txt" 2>&1
     printf '%s\n' "$?" > "$B/release-agent-print.exit.txt"
     /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper > "$B/helper.before.txt" 2>&1
     /bin/launchctl print system/io.github.koutyuke.capsaicin.helper > "$B/release-helper.before.txt" 2>&1
     /usr/bin/sfltool dumpbtm > "$B/btm.before.txt"
     /usr/sbin/sysctl kern.boottime > "$B/boottime.before.txt"
     /bin/date '+%Y-%m-%dT%H:%M:%S%z' > "$B/date.before.txt"
     /usr/bin/awk '$1 == "SleepDisabled" {print $2}' "$B/pmset.before.txt" > "$B/sleep-disabled.before.txt"
     cat "$B/sleep-disabled.before.txt" "$B/agent-print.exit.txt" "$B/agent.before.txt"
     ```

- **期待**: `SleepDisabled` は1行の `0` または `1`。agent とデーモンの照会は「サービスが見つからない」旨で失敗する。システム設定の「一般 > ログイン項目と機能拡張」と `btm.before.txt` の Capsaicin の項目に、使用中の登録がない。
- **中止**: `SleepDisabled` が欠落・重複・不明の場合。Debug・Release いずれかのジョブが読み込み済み、ログイン時に開く登録がある、バックグラウンドの登録を既存のものと区別できない場合も止める。既存の登録はこの手順で外さず、別の検証用 Mac を PM と選ぶ。権限不足を「存在しない」とみなさない。`sfltool dumpbtm` の `[disabled, allowed, …]` は過去の OS の記録として残りうるので、それだけで現在の登録や稼働を判断しない（`EVID-LCY-003`）。
- **復元**: 読み取りと退避先の作成だけなので、システムの復元は不要である。開始値が `1` の場合も、この時点では下ろさない。
- **記録**: `SleepDisabled` の開始値、agent の照会の終了値と本文、デーモンの照会結果、`boottime`、`date`、Capsaicin の BTM の項目を写す。システム設定の「ログイン時に開く」とバックグラウンドの一覧を画面写真で保存する。文言は macOS のバージョンで変わるので、終了値と本文の両方を残す。

### 1.3 設定と再開用の記録を退避する

- **目的**: `SPEC-SET-002`、`SPEC-LCY-007` の既存データを保存する。
- **前提**: アプリとジョブが停止している。次の対象がシンボリックリンクなら止める。
- **操作**:
  1. 既存の Debug 設定をドメイン全体で保存する。ホットキーの値もこの退避に含める。

     ```sh
     /usr/bin/defaults read io.github.koutyuke.capsaicin.debug > "$B/defaults.before.txt" 2> "$B/defaults-read.error.txt"
     printf '%s\n' "$?" > "$B/defaults-read.exit.txt"
     cat "$B/defaults-read.exit.txt" "$B/defaults-read.error.txt"
     ```

     終了コードが `0` なら、次を実行する。

     ```sh
     /usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.before.plist"
     /usr/bin/plutil -lint "$B/defaults.before.plist"
     ```

     ドメインが存在しない旨だけが出た場合は、次を実行する。他のエラーなら止める。

     ```sh
     touch "$B/defaults.absent"
     ```

  2. 再開用の記録を、存在しなかったことも含めて保存する。

     ```sh
     if [ -L "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then
       printf '%s\n' '中止: シンボリックリンクがある'
     else
       if [ -f "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/resume-record.before.json"; else touch "$B/record.absent"; fi
     fi
     ```

  3. 既存の記録があれば、`cat "$B/resume-record.before.json"` で `session`、`ownsSleepDisabled`、`isRunning`、`misalignments` を読む。抑止・所有・実行中・未復元の制御が残っていたら、そのまま保管して止める。壊れた記録も消さない。
  4. v0.1.0 の方式のファイルが残っていないか、Finder の「フォルダへ移動」で次の配置先を読む。見つかっても、この手順では移動・削除しない。

     対象は `/etc/sudoers.d/capsaicin` と `capsaicin_debug`、`/Library/PrivilegedHelperTools/io.github.koutyuke.capsaicin.helper` と同名末尾に `.debug` が付くファイル、`/Library/LaunchDaemons/` のそれぞれに対応する `.plist`、`~/Library/LaunchAgents/io.github.koutyuke.capsaicin.plist` と `io.github.koutyuke.capsaicin.debug.plist` である。

- **期待**: 設定と記録の退避に成功し、v0.1.0 の方式のファイルがない。
- **中止**: 旧方式のファイルが1つでも存在する、アクセス拒否、退避失敗、既存記録の意味を判断できない場合。旧方式の片付けは Git の外の専用手順書で済ませてから最初からやり直すか、残っていない別の検証用 Mac を PM と選ぶ。
- **復元**: 元ファイルは変更していない。`B` を残す。以降で消すのは今回の検証で作ったデータだけとする。
- **記録**: `defaults` の終了値、`record.absent`／`defaults.absent` のどちらができたか、旧方式のファイルの有無。既存データがあった場合は、その中身を要約して写す（認証情報は写さない）。

### 1.4 ビルドと署名を確認し、起動前の準備を終える

- **目的**: `SPEC-LCY-005`、`SPEC-LED-001` の確認を、復旧可能な状態で始める。
- **前提**: 1.3 が完了している。外観、アクセントカラー、アクセシビリティ、VoiceOver、バックグラウンド項目の開始値を画面写真で `B` に保存する。外付け機器の製品名と接続方式も記録する。
- **操作**:
  1. ヘルパーとログイン時の起動を確認する場合は、オーナーが `S-Preview` 付き PR のコメントから対象コミットの Debug ビルドを取得し、展開して `/Applications/Capsaicin.app` に置く。既存のアプリに上書きしない。パスと署名を確認する。

     ```sh
     APP='/Applications/Capsaicin.app'
     printf '%s\n' "$APP" > "$B/app-path.txt"
     /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
     /usr/bin/codesign -dv --verbose=4 "$APP" 2>&1
     /usr/bin/codesign --verify --deep --strict "$APP"
     /bin/ls -l "$APP/Contents/Helpers/"
     ```

     手元の `nix develop --command just build` は ad-hoc 署名で、ヘルパーには使えない。このビルドの確認だけを行う場合は `APP="$PWD/.build/xcode/Build/Products/Debug/Capsaicin.app"` を `app-path.txt` に保存し、1.4 の準備後に起動して「ヘルパー」が「このビルドでは使用不可」、管理ボタンなしになることを確認する。ヘルパーが要る選択肢を選んでも登録されず、エラー後に保存値の表示へ戻ることを確認したら終了し、9節へ進む。2節と4節の成功には数えない。

  2. 結果用メモを `B` に置き、実行日、macOS のビルド番号、Mac の機種、承認者、各手順の実測値を書く。認証情報や全プロセスの環境変数は保存しない。
  3. PM に、独立したプロセスから各対象キーボードへ `"Auto"` を書ける復旧用実行ファイルと、その実行・成功判定の手順を用意してもらう。承認済みの手順を `B` に保管する。

- **期待**: bundle ID が `io.github.koutyuke.capsaicin.debug`、埋め込み実行ファイルが `capsaicin` と `capsaicin-helper` である。PR Debug ビルドでは署名検査に成功し、`TeamIdentifier` がある。独立した LED 復旧手段と実行者が決まっている。
- **中止**: PR Debug ビルドの署名や取得元を確認できない、既存のアプリを上書きする必要がある、復旧手段がない場合はここで止め、2〜8節を実施しない。リポジトリには独立した復旧 CLI がない。LED 設定をオフにするだけでは起動時の `"Auto"` 書き込みを防げない。既存の LED 上書きモードを保つ必要がある環境でも止める。
- **復元**: ビルドだけならシステムの復元は不要である。動的確認を始めなかったことを結果に書く。
- **記録**: PR とコミット、アプリの絶対パス、ビルド番号、bundle ID、署名の Team ID、埋め込み実行ファイル2つ、承認済み復旧手順の置き場所。

ここから先は、各節の前提がそろった項目だけを上から順に実行する。飛ばした項目は判定不能にする。

**結果欄**: 成功／失敗／判定不能: ____。環境・承認・退避先: ____。未実施項目と理由・気づいたこと: ____。

## 2. 起動と LaunchAgent を確認する

この節では、Finder から開いても agent の管理下で動くこと（2.1）、mainApp によるログイン時の起動とクラッシュ後の再起動（2.2）、バックグラウンド項目を無効にしたときの表示（2.3）を見る。

ログイン時の起動は mainApp の登録で切り替える。agent は常に登録し、バンドル内の定義の `RunAtLoad = false` と `KeepAlive.Crashed = true` は切り替えない。システム設定の変更は2.3の後で戻す。

### 2.1 Finder 起動から引き渡しを確認する

- **目的**: `HYP-LCY-003`、`SPEC-LCY-005`。
- **前提**: 1.4 の準備を終え、`APP` は署名付きの PR Debug ビルドを指す。`SleepDisabled` の開始値が `0` である。開始値が `1` なら変更せず、動的確認を中止する。
- **操作**:
  1. 次を実行する。`open` は Finder のダブルクリックと同じ経路でアプリを起動する。バンドル内の定義も読む。

     ```sh
     /usr/bin/open "$APP"
     sleep 5
     ```

  2. 出力された状態を読む。

     ```sh
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     /usr/bin/plutil -p "$APP/Contents/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist"
     ```

  3. メニューから終了し、ジョブとプロセスを別々に見る。ジョブは読み込まれたままで、実行だけが止まるのが正しい。

     ```sh
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     ```

  4. もう一度起動し、5秒待ってから2と同じ照会を行う。終了した後にもう一度開けることも、この手順で確かめる。

     ```sh
     /usr/bin/open "$APP"
     sleep 5
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     /usr/bin/sfltool dumpbtm
     ```

  5. 設定の「ヘルパー」の状態と、システム設定の「ログイン時に開く」「アプリのバックグラウンドでのアクティビティ」の Capsaicin の項目を撮る。期待から外れたら、もう一度だけ2の照会で読み直す。それでも外れていれば中止する。

- **期待**: Debug の agent が実行中で、その `pid` のアプリだけが残り、`program` が `$APP/Contents/MacOS/Capsaicin` を指す。定義は `BundleProgram = Contents/MacOS/Capsaicin`、`RunAtLoad = false`、`KeepAlive.Crashed = true` である。3のあとは `pid` がなく、プロセスも残らない。ヘルパーは未インストールである。設定の既定値なら mainApp の登録もあり、ログイン時の一覧に出る。
- **中止**: 複数起動、引き渡しの繰り返し、Release の起動、登録失敗の場合。
- **復元**: メニューの終了操作で止める。登録とアプリの片付けは9節で行う。
- **記録**: 起動経路、各段階の `state` と `pid`、プロセスの本数、`program` と `BundleProgram`、`KeepAlive`、`RunAtLoad`、BTM の Capsaicin の項目、ヘルパーの状態とシステム設定の画面。

起動した直後の一瞬だけ2プロセスが見えることがある。手で開いた個体が引き渡してから終了するまでの間であり、数秒後に1本へ戻れば正常である。5秒たっても2本残るときは、引き渡しの失敗として扱う。

これは引き渡しの結果の確認である。`XPC_SERVICE_NAME` 自体を起動経路別に記録する機能はないので、`HYP-LCY-003` の直接測定は判定不能とする。`ps e` で他の秘密情報を含む環境を採取しない。

### 2.2 ログイン設定とクラッシュ後の再起動を確認する

- **目的**: `HYP-LCY-002`、`SPEC-LCY-001`、`SPEC-LCY-003`。
- **前提**: 停止中で、「一般」の再開設定は「再開しない」である。以後、画面の項目は機能名で指す。文言は `Sources/Capsaicin/Settings/` の String Catalog を正本とする。
- **操作**:
  1. 「一般」のログイン起動をオフにする。動作中のアプリが終了しないことと、システム設定の「ログイン時に開く」から Capsaicin が外れることを見る。BTM の Capsaicin の mainApp と agent の項目を読む。

     ```sh
     /usr/bin/sfltool dumpbtm
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
     ```

  2. メニューから終了し、プロセスが消えたことを確かめる。agent は登録したままにし、手作業で外したり読み込み直したりしない。

     ```sh
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     ```

  3. ジョブに実行中の `pid` がないことを、次のコマンドで確かめる。

     ```sh
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/grep -E '^[[:space:]]*(state|pid|runs|last exit code) ='
     ```

     Apple メニューからログアウトするときに「再ログイン時にウインドウを再度開く」のチェックを外し、再ログインする。以後のログアウト・再起動でも同じ条件にする。0節で退避先を入れ直し、同じ照会を行う。アプリは起動しない。

     ```sh
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/grep -E '^[[:space:]]*(state|pid|runs|last exit code) ='
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     ```

  4. Finder 経由で手動起動し、引き渡し後の agent の PID を得る。`PID` はこの照合とクラッシュの間だけ使う。

     ```sh
     /usr/bin/open "$APP"
     sleep 5
     PID="$(/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/awk '$1 == "pid" && $2 == "=" {print $3}')"
     /bin/ps -p "$PID" -ww -o pid=,comm=
     ```

     出力が Debug アプリの絶対パスと一致した場合だけ、クラッシュさせる。

     ```sh
     /bin/kill -SEGV "$PID"
     ```

  5. 30秒を観測の上限として待ち、次の照会で別の PID になったことを記録する。

     ```sh
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/grep -E '^[[:space:]]*(state|pid|runs|last exit code) ='
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     ```

  6. ログイン起動をオンにし、システム設定の「ログイン時に開く」に Capsaicin が出ることと、BTM の mainApp の登録を見る。ログアウトして再ログインする。

     ```sh
     /usr/bin/sfltool dumpbtm
     ```

     再ログイン後は0節で退避先を入れ直し、次でジョブが実行中でプロセスが1本だけであることを確かめる。

     ```sh
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     ```

- **期待**: 1の登録解除ではアプリも agent も止まらない。2・3ではアプリは停止し、再ログインしても起動しない。agent は読み込み済みで `pid` がない。4のクラッシュ後には別の PID で起動する。6では mainApp によりログイン時に起動し、agent へ引き渡され、メニューバーに表示される。
- **中止**: PID が空・複数・別アプリの場合はシグナルを送らない。再起動しない場合も連続して送らない。3でジョブ自体が見つからない場合も、起動しなかったと混ぜずに中止する。
- **復元**: ログイン起動を次の試験に必要な値へ戻す。最終的な開始値の復元は9節で行う。
- **記録**: mainApp の登録とシステム設定の前後、2・3での `state` と `pid` の有無、4でシグナルを送った PID と5で戻った PID、`runs`、`last exit code`、ウインドウを再度開くチェックを外したこと。

3のあと、agent は「読み込まれているが実行されていない」が期待である。`launchctl print` が「見つからない」と答えるのは別の異常であり、アプリが起動しなかったこととは区別する。5の30秒はこの手順の中止基準であり、製品の保証時間ではない。

`KeepAlive` は `Crashed` だけなので、メニューからの終了や `SIGTERM` では再起動しない。これも 2.1 の3と合わせて確認できる。

### 2.3 バックグラウンド項目が無効の表示を確認する

- **目的**: `SPEC-LCY-005`。
- **前提**: システム設定の「一般」→「ログイン項目と機能拡張」で Debug の項目を識別できる。
- **操作**:
  1. 抑止を解除し、メニューから終了してプロセスがないことを確かめる。

     ```sh
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     ```

  2. 該当項目を無効にする。アプリの終了を求められたら従う。
  3. Finder から起動する。

     ```sh
     /usr/bin/open "$APP"
     sleep 3
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
     ```

  4. アプリの設定ウィンドウで「一般」を開いて表示を撮る。警告の行が出ていたら、その文言をそのまま写す。システム設定の「一般」には警告は出ない。
  5. 確認後は該当項目を元の許可状態に戻し、アプリを終了して次の `open` で起動し直す。agent が実行中に戻り、アプリの「一般」で警告の行が消えたことを確かめる。

     ```sh
     /usr/bin/open "$APP"
     sleep 3
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
     /usr/bin/sfltool dumpbtm
     ```

- **期待**: アプリは動作し、「一般」にバックグラウンド項目が無効、またはクラッシュ時の自動再起動が使えない旨の警告が出る。無効な間はクラッシュ時の自動再起動を期待しない。許可を戻して起動し直すと、agent が実行中になり警告が消える。
- **中止**: Release や別アプリの項目と区別できない場合は無効にしない。5で警告が消えない場合は、再起動試験へ進まない。
- **復元**: 開始前の写真と `disabled.before.txt` を参照し、同じ項目だけを戻す。
- **記録**: 無効にした項目の表示名、アプリが動いたこと、`launchctl print` の結果、アプリの設定ウィンドウの「一般」に出た警告の行の文言、戻したあとに警告が消えたこと。

項目の見分けがつかないときは無効にしないで止める。Debug と Release は表示名が同じ "Capsaicin" になりうる。`sfltool dumpbtm` の識別子とパスを開始前の記録と比較し、名前だけで決めない。ヘルパーと agent は、バックグラウンドの一覧では1つの Capsaicin の項目にまとまる（`EVID-LCY-003`）。

agent の許可状態が `requiresApproval` なら「バックグラウンド項目が無効です」、登録や起動の失敗なら自動再起動が使えない旨の警告になる。`launchctl print-disabled` だけでは SMAppService の許可状態を判断せず、システム設定、アプリの表示、BTM の記録を照合する。

**結果欄**: 成功／失敗／判定不能: ____。起動経路・agent と mainApp の登録・PID の前後: ____。未実施項目と理由・気づいたこと: ____。

## 3. 抑止の基本とハードウェア検出を確認する

この節では、自動スリープを常に止めるアサーションと画面の追加抑止（3.1）、画面消灯・スクリーンセーバーと、MacBook かどうかの判定・バッテリーの検出（3.2）、「ディスプレイを閉じたとき」の設定（3.3）を見る。

### 3.1 設定ごとのアサーションを比較する

- **目的**: `SPEC-BLK-001`。
- **前提**: 「ディスプレイを閉じたとき」は「スリープ」（MacBook 以外の Mac では「メニューから選んでもスリープさせない」はオフ）である。「スリープ」の自動解除のグループにあるタイマー・指定時刻と、「バッテリー」の残量の条件をオフにする。電源アダプターを接続する。試験後はバッテリー条件を戻す。
- **操作**:
  1. 「スリープ」で「ディスプレイを自動でオフにしない」をオフにし、メニューから開始する。
  2. アサーションを読み、Capsaicin の行を写す。

     ```sh
     /usr/bin/pmset -g assertions | /usr/bin/grep -i -A2 capsaicin
     ```

  3. 解除後、「ディスプレイを自動でオフにしない」をオンにして開始し、同じコマンドを実行する。
  4. 解除してもう一度同じコマンドを実行し、Capsaicin の行が消えたことを確かめる。
- **期待**: どちらでも `Capsaicin` の `PreventUserIdleSystemSleep` があり、「ディスプレイを自動でオフにしない」がオンのときだけ `PreventUserIdleDisplaySleep` もある。解除後は Capsaicin のアサーションがない。別アプリのアサーションは消さない。
- **中止**: 開始拒否や解除後の残留がある場合。
- **復元**: メニューで解除する。「ディスプレイを自動でオフにしない」を開始前の値に戻す。残留があれば9節で復旧する。
- **記録**: 各段階の Capsaicin の行を丸ごと写す（アサーションの種類と数を後から比較する）。他のアプリの行は数だけ数える。

他のアプリの行を数えるときは、`/usr/bin/pmset -g assertions` で全体を読む。

アサーションの存在だけでは実際のスリープ抑止の合格にしない。システム設定の画面消灯までの既存の時間を `/usr/bin/pmset -g custom | /usr/bin/grep -i displaysleep` で記録し、その時間を超えて操作せずに待つ。「ディスプレイを自動でオフにしない」がオフなら画面は消灯でき、オンなら消灯しないことを比較する。OS 側の自動スリープ条件を特定できない場合、実際の自動スリープは判定不能とし、`pmset` のタイマー設定を変更しない。

### 3.2 画面消灯、MacBook かどうかの判定、バッテリーの検出を確認する

- **目的**: `HYP-BLK-001`、`HYP-BLK-008`、`HYP-BLK-009`、`HYP-SET-001`、`HYP-SET-002`、`SPEC-SET-006`。
- **前提**: 抑止を解除している。画面が消えてもキーボード・トラックパッドで復帰できる。
- **操作**:
  1. 管理者ユーザーと一般ユーザーのそれぞれで、`sudo` なしで実行する。

     ```sh
     /usr/bin/pmset displaysleepnow
     printf 'exit=%s\n' "$?"
     ```

  2. MacBook と MacBook 以外の Mac で次を実行し、設定のディスプレイの開閉に関する行の有無と照合する。

     ```sh
     /usr/sbin/ioreg -r -c IOPMrootDomain -d1 -w0 | /usr/bin/grep AppleClamshellState
     /usr/bin/pmset -g batt
     ```

  3. 各 Mac で「スリープ」の「バッテリー」のグループ全体の有無を記録する。メニューも開き、クイック設定の中のバッテリー残量の項目の有無を見る。UPS がある場合はその有無と製品名も書く。
  4. 「システム設定 > ロック画面」でスクリーンセーバの自動起動までの時間を最短にし、ディスプレイを自動でオフにするまでの時間をそれより長くする。変更前の値を控える。「ディスプレイを自動でオフにしない」をオンにして抑止を開始し、スクリーンセーバの時間より長く操作せずに待つ。解除して同じだけ待ち、対照の結果を記録する。
- **期待**: 1は終了コード `0` で消灯する。MacBook だけで `AppleClamshellState` があり、「ディスプレイを閉じたとき」のポップアップが表示され、アイコンが `laptopcomputer` になる。MacBook 以外の Mac では「メニューから選んでもスリープさせない」のスイッチが表示され、アイコンが `powersleep` になる。バッテリーのグループと、クイック設定内のバッテリー残量の項目は、内蔵バッテリーのある Mac だけにある。4では抑止中にスクリーンセーバが自動起動せず、解除後には起動する。
- **中止**: 消灯から復帰できない、想定外の権限要求がある場合。1台の結果を他機種の合格にしない。
- **復元**: メニューで抑止を解除し、手動操作で画面を復帰させる。接続機器と「システム設定 > ロック画面」の変更した値を開始前に戻す。
- **記録**: 実行したユーザーの種類（管理者・一般）、終了値、`AppleClamshellState` の有無、設定画面のバッテリーのグループとメニューのバッテリー残量の項目の有無、機種名。スクリーンセーバーと画面の時間の開始値、抑止中と解除後の自動起動の有無、復元した値。

`pmset -g batt` は IOPS の型の直接測定ではない。`HYP-SET-002` の UPS と内蔵バッテリーの型の区別は、型を出す試作プログラムがないので判定不能とする。`HYP-BLK-008` の通知時刻もアプリが記録しないので、4節の画面消灯は間接確認にとどめる。

### 3.3 ディスプレイを閉じたときの設定を確認する

- **目的**: `SPEC-SET-002`、`SPEC-SET-005`、`SPEC-SET-006`。
- **前提**: 抑止を解除している。MacBook を使い、ヘルパーの状態を確認してある。ヘルパーの設置やディスプレイを閉じる試験は4節で行う。
- **操作**: 「スリープ」を開き、「ディスプレイを閉じたとき」の選択肢と (i) を見る。ヘルパーが有効なら「スリープ（標準）」「ディスプレイをオフ」「明るさを0」「オンのまま」を順に選ぶ。ヘルパーが使えないのに、それを要する設定が保存されている場合は、表示と (i) の先頭を記録する。その状態は4.3で確認し、安全に用意できなければ注意の表示だけ判定不能にする。
- **期待**: 独立した子の行がなく、1つのポップアップに4つの選択肢がある。ヘルパーが使えなくてもポップアップは操作でき、保存した選択肢を表示する。ヘルパーが要る保存値には注意の記号が付き、(i) の先頭で適用できない理由と、未インストールなら「ヘルパー」から設置すること、許可待ちならシステム設定で許可することを読める。通常の説明は、ディスプレイを閉じる操作とアップルメニューの「スリープ」などを個別に設定できないこと、ヘルパーとシステム設定での許可が要ることを伝える。
- **中止**: 「スリープ」以外を選んで設置確認が出たら、その場では承認せず、取り消して保存値の表示に戻ることを確かめ、4.1へ進む。許可待ちでシステム設定が開いた場合も、ここでは許可せず4.1へ進む。
- **復元**: 試した設定を開始前の値に戻す。ヘルパーの状態は変えない。
- **記録**: ポップアップの表示・選択肢・(i) の内容、注意の記号の有無、ヘルパーの状態、元の設定値。

**結果欄**: 成功／失敗／判定不能: ____。設定とアサーション・機種別の検出値: ____。未実施項目と理由・気づいたこと: ____。

## 4. ヘルパーを設置し、抑止・許可・削除を確認する

この節では、設置確認の取り消しとシステム設定での許可（4.1）、XPC 経由の on・off（4.2）、許可を外したときの表示（4.3）、起動時の後片付け（4.4）、削除と所有の扱い（4.5）、デーモンのない状態での値の永続性（4.6）を見る。ディスプレイの輝度は4.7、更新後の登録し直しは4.8で確認する。

この節は Team ID のある署名付きの PR Debug ビルドでだけ行う。ヘルパーはバンドル内のデーモンを SMAppService に登録し、システム設定で許可して使う。**今回の登録を示す `B/helper-created` は、登録後に「ヘルパー」が許可待ちか有効になったことを確認してから作る。** 登録を外すのは今回のものだけにする。

確認する構成と登録は次のとおり。

| 構成・登録 | 役割 |
| --- | --- |
| `$APP/Contents/Helpers/capsaicin-helper` | XPC で on・off だけを受け付けるデーモン |
| `$APP/Contents/Library/LaunchDaemons/io.github.koutyuke.capsaicin.debug.helper.plist` | `BundleProgram`、Mach サービス、`RunAtLoad = true` を持つバンドル内の定義 |
| システム設定の Capsaicin のバックグラウンド項目 | ヘルパーと agent の両方の許可。片方だけのスイッチではない |

### 4.1 設置確認の取り消しとシステム設定での許可を確認する

- **目的**: `SPEC-HLP-001`、`SPEC-HLP-004`、`SPEC-HLP-005`。
- **前提**: 1節で既存の登録と旧方式のファイルがないことを確認済みで、`SleepDisabled = 0` である。アプリは起動済みで抑止は停止中、ヘルパーは未インストールである。
- **操作**:
  1. 「ディスプレイを閉じたとき」で「ディスプレイをオフ」を選ぶ（MacBook 以外の Mac では「メニューから選んでもスリープさせない」をオンにする）。設置確認を取り消し、ポップアップが「スリープ」（MacBook 以外の Mac ではオフ）に戻り、ヘルパーが未インストールのままであることを確かめる。
  2. 同じ操作で確認の「インストール」を選ぶ。システム設定が開いても、まだ許可しない。アプリの「ヘルパー」が「システム設定での許可待ち」になり、「システム設定を開く」と「削除」が出ることを確かめ、`touch "$B/helper-created"` で今回の登録を記録する。状態と保存値を読む。登録直後に有効になった場合もマーカーを作り、3と4の許可待ちの確認は判定不能として飛ばす。

     ```sh
     /usr/bin/defaults export io.github.koutyuke.capsaicin.debug - | python3 -c 'import json, plistlib, sys; print(json.dumps(json.loads(plistlib.load(sys.stdin.buffer).get("capsaicin.settings", b"{}")), ensure_ascii=False, indent=2))'
     /usr/bin/sfltool dumpbtm
     ```

  3. 許可待ちの間、選んだ値は表示されるが保存値は変わらず、注意の記号と (i) に許可の案内が出ることを見る。設定ウインドウを閉じて開き直し、表示が保存値に戻ってもヘルパーの許可待ちは残ることを確かめる。もう一度同じ値を選ぶと、設置確認なしでシステム設定が開くことを見る。
  4. **この許可でヘルパーと agent の両方を有効にする。** Capsaicin の項目だと識別できた場合だけ許可し、アプリの設定ウインドウに戻る。許可後の状態と保存値、定義を読む。

     ```sh
     /usr/bin/defaults export io.github.koutyuke.capsaicin.debug - | python3 -c 'import json, plistlib, sys; print(json.dumps(json.loads(plistlib.load(sys.stdin.buffer).get("capsaicin.settings", b"{}")), ensure_ascii=False, indent=2))'
     /usr/bin/plutil -p "$APP/Contents/Library/LaunchDaemons/io.github.koutyuke.capsaicin.debug.helper.plist"
     /usr/bin/sfltool dumpbtm
     ```

- **期待**: 1では登録も保存値も変わらない。2・3では許可待ちになり、選択した値は許可が済むまで保留される。4では状態が「有効」になり、保留していた選択肢（MacBook 以外の Mac ではオン）が保存される。保存値の読み取りでは `blocksManualSleep` と `lidCloseDisplay` を見る。`{}` は設定の保存がまだなく、既定値を使う状態である。状態は前面に戻ったときに読み直され、許可待ちで設定ウインドウを開いている間は2秒ごとにも読み直される。定義のラベルと Mach サービスは `io.github.koutyuke.capsaicin.debug.helper`、`BundleProgram` は `Contents/Helpers/capsaicin-helper` である。
- **中止**: 取り消しても登録や保存値が変わる、許可前に保存される、対象を識別できない、登録に失敗する場合。初回登録がそのまま有効になり許可待ちを観測できなかった場合は、その項目だけ判定不能とし、過去の許可記録の有無を残す。
- **復元**: 今回の登録は4.5か9節で「ヘルパー」の削除から外す。許可待ちで中止した場合も登録が残るので片付ける。「ヘルパー」から直接インストールした場合は、ほかの設定を変えないことも確認する。
- **記録**: 確認の取り消し、許可前後とウインドウを開き直した後の表示・保存値、BTM の Capsaicin の項目、定義の内容、マーカーの有無。

### 4.2 on・off と手動・ディスプレイを閉じたときのスリープを確認する

- **目的**: `SPEC-HLP-002`、`HYP-BLK-006`、`SPEC-BLK-001`、`SPEC-BLK-002`、`HYP-BLK-008`。
- **前提**: 今回登録したヘルパーが有効である。アプリは起動済みで抑止は停止中、`SleepDisabled = 0`。MacBook は電源接続、外部ディスプレイなしで机上に置く。閉じた Mac をかばんに入れない。
- **操作**:
  1. 「ディスプレイを閉じたとき」を「オンのまま」にし（MacBook 以外の Mac では「メニューから選んでもスリープさせない」をオンにする）、メニューから開始する。アプリから XPC で `on` が送られ、`SleepDisabled = 1` になることを読む。

     ```sh
     /usr/bin/pmset -g
     ```

  2. メニューで解除し、`off` の後に `SleepDisabled = 0` になることを読む。デーモンは引数付きで直接実行する CLI ではないので、バンドル内の実行ファイルも直接呼ばない。

     ```sh
     /usr/bin/pmset -g
     ```

  3. 「ディスプレイを閉じたとき」を「ディスプレイをオフ」にし（MacBook 以外の Mac では「メニューから選んでもスリープさせない」をオンにする）、メニューで開始する。状態を読んでから、Apple メニューのスリープを選び、MacBook では続けてディスプレイを1分閉じてから開く。

     ```sh
     /usr/bin/pmset -g
     ```

  4. 開く前後の時刻と `pmset -g log` の該当区間を記録する。閉じている間の消灯を安全に目視できなければ、消灯は判定不能とする。「ディスプレイを閉じたとき」を「オンのまま」にした場合とも比較する。

     ```sh
     /bin/date '+%Y-%m-%dT%H:%M:%S%z'
     /usr/bin/pmset -g log | /usr/bin/grep -iE 'sleep|wake'
     ```

  5. メニューで解除し、`SleepDisabled` を読む。もう一度ディスプレイを閉じてスリープし、開くと復帰することを確かめる。

     ```sh
     /usr/bin/pmset -g
     ```

- **期待**: 1・2で `SleepDisabled` が `1`→`0` になる。3は `SleepDisabled = 1` で手動・ディスプレイを閉じたときのスリープを止める。5では `0` に戻る。
- **中止**: 状態が不明、異常発熱、解除後もスリープできない場合。
- **復元**: メニューで解除して `0` を確認する。戻せなければ9.1の緊急復旧を使う。
- **記録**: 各段階の `SleepDisabled`、`pmset -g log` の該当行、ディスプレイを閉じていた時刻、復帰にかかった時間。

不正な XPC の要求（別の値、余分なキー、型違い）の拒否は `CHelperContractTests` の自動テストで確認する。正規でない相手の拒否は任意の確認とし、別途承認済みの接続試験を行った場合だけ、デーモンのログと `SleepDisabled` が変わらないことを照合する。この手順では ad-hoc 署名の試験プログラムを用意しないので、ログがなければ判定不能とする。通常のアプリ操作だけで拒否ログが出ることを期待しない。

```sh
/usr/bin/log show --last 10m --style compact --predicate 'process == "capsaicin-helper" AND eventMessage CONTAINS[c] "code signing requirement"'
/usr/bin/pmset -g
```

ネットワーク応答はスリープの断定に使わない。別端末から ping を使う場合は、ディスプレイを開いているときに疎通する宛先 IP を記録してから `ping -c 3 IP_ADDRESS` を使う。`IP_ADDRESS` は記録した検証 Mac の IP に置き換える。応答だけで、または無応答だけで判定せず、スリープログと突き合わせる。`HYP-BLK-006` の「片方だけは指定できない」という仕組みの主張は、実測とは別のソース調査である。

### 4.3 システム設定で許可を外したときの表示を確認する

- **目的**: `SPEC-HLP-004`、`SPEC-SET-005`、`SPEC-LCY-005`。
- **前提**: 抑止を解除し、`SleepDisabled = 0`。`B/helper-created` があり、ヘルパーは有効である。ヘルパーが要る設定を保存しておき、開始値とシステム設定の項目を記録する。
- **操作**:
  1. 設定の「ヘルパー」を開いたまま、システム設定の「一般 > ログイン項目と機能拡張」で Capsaicin のバックグラウンド項目をオフにし、アプリの設定ウインドウに戻る。
  2. 「ヘルパー」の状態とボタン、「スリープ」の保存値と注意の記号、(i) の先頭、「一般」の自動再起動の警告を読む。ヘルパーと agent の許可が同時に外れることを確認する。この状態では抑止を開始しない。
  3. 「ヘルパー」の「システム設定を開く」から同じ項目をオンに戻し、アプリの設定ウインドウに戻る。状態と注意の記号を再確認する。

     ```sh
     /usr/bin/sfltool dumpbtm
     /usr/bin/pmset -g
     ```

- **期待**: 2では「システム設定での許可待ち」と「システム設定を開く」「削除」が表示される。保存した選択肢（MacBook 以外の Mac ではオン）は残り、注意の記号と (i) で許可が必要と分かる。「一般」には自動再起動できない旨が出る。3ではヘルパーが有効に戻り、ヘルパーに関する注意が消える。いずれも `SleepDisabled = 0` のままである。
- **中止**: 別アプリや Release の項目と区別できない、許可を戻しても有効にならない、保存値が勝手に変わる場合。
- **復元**: 許可を戻し、2.3の5と同じく終了・起動して agent が実行中に戻ることを確かめる。設定を開始値へ戻す。許可を戻せないときは、登録と記録を残して9節へ進む。
- **記録**: 項目の表示名、許可前後の状態・ボタン・警告、保存値と (i)、BTM の Capsaicin の項目、`SleepDisabled`。

### 4.4 起動時の後片付けを確認する

- **目的**: `SPEC-HLP-003`。
- **前提**: 今回登録したヘルパーが有効で、4.2の on・off に成功している。ログイン起動をオフにしてメニューでアプリを終了し、プロセスがないことを0節の照会で確認する。開始前の `SleepDisabled = 0` を再確認する。外部から値を変える操作もオーナーが承認済みである。
- **操作**:
  1. アプリの終了後に外部から値を立て、`SleepDisabled = 1` を記録する。**再起動後も残りうる設定なので、9.1の復旧コマンドを別のメモに控えてから実行する。**

     ```sh
     /usr/bin/sudo /usr/bin/pmset -a disablesleep 1
     /usr/bin/pmset -g
     ```

  2. Apple メニューから再起動する。再ログイン後、アプリを起動せず0節で退避先を入れ直して次を実行する。

     ```sh
     /usr/bin/pmset -g
     /usr/bin/log show --last boot --style compact --predicate 'process == "capsaicin-helper" OR (process == "launchd" AND eventMessage CONTAINS "io.github.koutyuke.capsaicin.debug.helper")'
     ```

- **期待**: `SleepDisabled = 0` で、ログに今回の起動でのデーモンの起動があり、後片付けの失敗がない。デーモンは使われていなければ終了するため、常駐や `state = running` は要求しない。初回設置では起動の記録だけを書き、別の Mac の起動になったときだけ `off` を行う。同じ起動中の要求で `off` を繰り返さないことは4.2の開始が保たれることと自動テストで確認する。
- **中止**: `1` が残る場合はアプリを起動せず、9.1で戻す。
- **復元**: `0` を確認し、Finder から `APP` のアプリを起動する。ログイン起動は後続の試験に合わせる。
- **記録**: 再起動前後の `SleepDisabled`、デーモンの起動と失敗の有無が分かるログ、再起動の時刻。実装には成功した `off` の回数を出すログがないため、「1回だけ実行」の直接測定は判定不能とし、値とログによる間接確認と区別する。

### 4.5 削除と外部の disablesleep の保持を確認する

- **目的**: `SPEC-HLP-004`、`SPEC-HLP-005`。
- **前提**: ヘルパーは今回設置したものだけで、再開用の記録を保存できる。外部から `disablesleep` を変更する試験と9.1の復旧手順も承認済みである。
- **操作**:
  1. 「ディスプレイを閉じたとき」を「オンのまま」にし（MacBook 以外の Mac では「メニューから選んでもスリープさせない」をオンにする）、開始して `SleepDisabled = 1` を確かめる。「ヘルパー」の削除を承認する。

     ```sh
     /usr/bin/pmset -g
     ```

  2. 状態が未インストール、該当設定が「スリープ」（MacBook 以外の Mac ではオフ）、`SleepDisabled = 0` になり、デーモンの登録が外れることを確かめる。バンドル内の実行ファイルと定義は残る。

     ```sh
     /usr/bin/pmset -g
     /usr/bin/sfltool dumpbtm
     ```

  3. 4.1で再設置する。抑止を解除し、アプリが所有を持たない状態で次を実行する。再起動後も残りうる値を立てるので、9.1の復旧コマンドを別のメモに控えてから実行する。

     ```sh
     /usr/bin/sudo /usr/bin/pmset -a disablesleep 1
     /usr/bin/pmset -g
     ```

  4. 「ディスプレイを閉じたとき」を「オンのまま」にし（MacBook 以外の Mac では「メニューから選んでもスリープさせない」をオンにする）、開始して再開用の記録の `ownsSleepDisabled` が `false` であることを読む。そのままヘルパーを削除する。

     ```sh
     /usr/bin/plutil -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" | /usr/bin/grep ownsSleepDisabled
     ```

  5. 未インストールになっても `SleepDisabled = 1` のままであることを確かめ、直後に戻す。

     ```sh
     /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
     /usr/bin/pmset -g
     ```

- **期待**: 自分の所有は登録を外す前に下ろし、外部の値は削除で下ろさない。削除してもバックグラウンドの一覧に Capsaicin が許可済みで残ることはある。agent と OS の記録が残るため、一覧から消えることをヘルパー削除の成功条件にしない。
- **中止**: 4で所有が `true` なら外部の試験条件を満たさない。削除せず解除し、`0` へ戻して PM に報告する。自分の所有を下ろせない場合はエラーが出て登録・所有・設定が残るのが期待であり、削除を繰り返さず9.1へ進む。
- **復元**: 最後にメニューで解除し、「ディスプレイを閉じたとき」を「スリープ」にする（MacBook 以外の Mac では「メニューから選んでもスリープさせない」をオフにする）。登録が残った場合は9節で今回の分だけを外す。
- **記録**: 1と4の `SleepDisabled`、`ownsSleepDisabled`、削除後の状態と BTM の Capsaicin の項目、5で外部値を戻したこと。削除に失敗した場合はエラーと保存値も残す。

3で `disablesleep` を外部から立てるのは、アプリが「自分の所有ではない値」を見分けられるかを試すためである。4で `ownsSleepDisabled` が `true` になるなら、アプリは外部の値を自分のものと誤認している。その場合は削除の試験を続けず、状態を戻して報告する。

自分の所有を下ろせない条件は、実機の署名や権限を壊して作らない。`AppSettingsTests.liveRemovalOrder` などの偽物を使う自動テストで、`off` または読み取りに失敗すると登録を外さないことを確認し、実機での失敗時の確認とは分けて記録する。

### 4.6 デーモンのない状態で値の永続性を確認する

- **目的**: `HYP-BLK-007`。4.4ではデーモンが値を下ろすため、永続性は別に測る。
- **前提**: 4.5の削除が完了して未インストールになり、ログイン起動をオフにしてメニューでアプリを終了している。Release の登録もないことを開始前の記録で確認済みである。`SleepDisabled = 0` で、9.1の復旧手順が承認済みである。
- **操作**:
  1. **再起動後も残る設定を変更する。9.1の復旧コマンドと退避先を別のメモに残してから実行する。**

     ```sh
     /usr/bin/sudo /usr/bin/pmset -a disablesleep 1
     /usr/bin/pmset -g
     ```

  2. Apple メニューから再起動し、アプリを起動せず0節で退避先を入れ直して `SleepDisabled` を読む。

     ```sh
     /usr/bin/pmset -g
     ```

- **期待**: 再起動前後とも `SleepDisabled = 1` なら仮説を支持し、再起動後 `0` なら支持しない。
- **中止**: 値が欠落する、他の常駐処理が起動する場合は判定不能とし、観測事実を残す。
- **復元**: 判定直後に次を実行する。`0` に戻らなければ後続を止め、9.1へ進む。戻った場合は Finder からアプリを起動し、5節へ進む。

  ```sh
  /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
  /usr/bin/pmset -g
  ```

- **記録**: 再起動前後それぞれの `SleepDisabled`、再起動の時刻、9.1の復旧コマンドを控えた場所。

この項目だけは、終わった直後に必ず戻す。値が `1` のまま次の試験へ進まない。

ヘルパーを削除しても、起動の記録 `/Library/Application Support/io.github.koutyuke.capsaicin.debug/boot-session-uuid` は残る。この試験の後に設置し直すと、記録と Mac の起動が違うため、その場で外部の `disablesleep` も下ろす制約がある（`SPEC-HLP-003`）。必ず上の復元で `0` を確認してから再設置する。起動の記録は手で消さない。

**結果欄**: 成功／失敗／判定不能: ____。許可・登録・所有・SleepDisabled・デーモンのログ: ____。未実施項目と理由・気づいたこと: ____。

### 4.7 「明るさを0」の開閉・解除・利用者の変更を確認する

- **目的**: `SPEC-BLK-013`。閉じた間は暗くして画面収録を続け、閉じている間に上がった輝度は1分以内に0に戻し、開いたときと解除時に閉じる前の輝度へ戻す。
- **前提**: オーナーが操作する。未保存の作業を片付け、ヘルパーを設置済みにする（4.6まで終えていたら4.1で再設置する）。MacBook を電源接続・外部ディスプレイなしで机上に置く。開始前の輝度、自動輝度調節、True Tone、「スリープ」画面と再開の設定を控える。自動輝度調節をオフにし、明るさのキーで画面を十分明るくする。「ディスプレイを閉じたとき」は「明るさを0」、「ディスプレイを自動でオフにしない」はオン、バッテリーと指定時刻の解除条件はオフにする。**暗いだけの画面はロックされないので、席を離れない。** 輝度の判定は目視で行い、`ioreg` の値は使わない（`EVID-BLK-008`）。
- **操作**:
  1. 秒表示の時計を映して画面収録を始め、タイマーをオフにして抑止を開始する。ディスプレイを1分閉じ、隙間から光が漏れるかを見る。開いた直後の明るさ、ロック画面の有無、すぐ操作できるかを確かめる。収録を停止して再生し、閉じた区間も時計が進んでいることを見る。再開用の記録を `plutil -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"` で読み、`savedBrightness` が残っていないことを確かめる。
  2. 一度解除し、タイマーを1分にして開始する。ディスプレイを閉じたまま期限が過ぎるのを待ち、開いて明るさと停止中の表示を確かめる。記録に `savedBrightness` が残っていないことと、`/usr/bin/pmset -g` の `SleepDisabled` が `0` に戻ったことを読む。
  3. タイマーをオフにして開始し、ディスプレイを閉じる。閉じている間に、接続した外付けキーボードの明るさのキーで画面を明るくする。隙間の光で変化を確認し、1分以内に光が消えるかを見る。明るくしてから1分以上待ってディスプレイを開き、閉じる前の明るさに戻るかを見る。記録に `savedBrightness` が残っていないことを読む。閉じたまま明るさを変える手段がなければ、この操作は未実施として理由を残す。
- **期待**: 1は閉じている間に光が漏れず、開けると元と同じくらいの明るさになり、ロックされずすぐ操作できる。収録の描画は続く。2は閉じたまま解除され、開けても暗い画面が残らない。3は明るくしてから1分以内に輝度が0に戻って隙間の光が消え、開けると閉じる前と同じくらいの明るさになる。いずれも復元後に輝度の記録は残らない。`disablesleep` より先に戻す呼び出し順は自動テストで確かめ、目視だけで順序を断定しない。
- **中止**: 異常発熱、解除後も暗いまま、収録停止、予期しないロックがある場合。安全に隙間を見られなければ光漏れは判定不能とする。
- **復元**: ディスプレイを開いて抑止を解除する。暗いままなら明るさのキーで戻す。収録中なら停止し、輝度・自動輝度調節・True Tone・「スリープ」画面と再開の設定を控えた値へ戻す。この節のために再設置したヘルパーは4.5で削除する。戻らなければ後続を止め、記録を保管して PM に渡す。
- **記録**: Mac と macOS の版、各回の設定、閉じた時刻と開いた時刻、目視の明るさと光漏れ、ロックの有無、収録ファイルと該当区間、復元後の記録と `SleepDisabled`、未実施・判定不能の項目と理由。

### 4.8 更新後の登録し直しを確認する

- **目的**: `SPEC-HLP-007`、`SPEC-LCY-005`。
- **前提**: 署名付きの PR Debug ビルドを2つ用意し、後のビルドの `CFBundleVersion` が大きいことを確認してある。PR Debug ビルドの `CFBundleVersion` はビルドした UTC の時刻（`YYYYMMDDhhmmss`）なので、同じ PR に push し直すか `S-Preview` を付け直して作った後のビルドが大きくなる。同じ Team ID と bundle ID を持ち、同じ `APP` のパスで入れ替える。ヘルパーは今回登録したものが有効で、抑止は解除済み、`SleepDisabled = 0` である。4.7の復元で削除した場合は、4.1で再設置してから行う。
- **操作**:
  1. 入れ替える前の版と登録時の版を記録し、メニューから終了してプロセスがないことを0節の照会で確かめる。

     ```sh
     /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist"
     /usr/bin/defaults read io.github.koutyuke.capsaicin.debug helperRegisteredBundleVersion
     /usr/bin/defaults read io.github.koutyuke.capsaicin.debug agentRegisteredBundleVersion
     ```

  2. Finder で今回の古いアプリだけをゴミ箱に移し、署名付きの新しいビルドを同じパスに置く。バンドルを手で書き換えて版を上げない。1.4と同じ署名検査を行ってから `/usr/bin/open "$APP"` で起動し、引き渡しを待つ。
  3. 「ヘルパー」の状態を読み、1と同じ3つの値を記録する。ヘルパーが要る設定で開始・解除し、各段階の `SleepDisabled` を読む。agent の `program` と PID も2.1の照会で確認する。

     ```sh
     /usr/bin/pmset -g
     /usr/bin/log show --last 10m --style compact --predicate 'subsystem == "io.github.koutyuke.capsaicin.debug" AND (category == "Helper" OR category == "LaunchAgent")'
     ```

- **期待**: 許可を求められず、ヘルパーは有効のまま、開始・解除で `SleepDisabled` が `1`→`0` になる。ヘルパーと agent の登録時の版が新しい `CFBundleVersion` になる。登録解除の完了を待ってから登録し、`EPERM` の場合は3秒おきに最大3回試し直す。同じ Mac の起動の中では起動時の後片付けを繰り返さない。
- **中止**: 署名・bundle ID が違う、別のアプリを置き換えるおそれがある、許可を再度求められる、登録時の版が更新されない、抑止できない場合。再登録の失敗はダイアログではなくログと状態で判断し、入れ替えを繰り返さない。
- **復元**: 抑止を解除し、今回の新旧ビルドと登録は9節で片付ける。ゴミ箱の古いアプリも OS の項目が残る原因になるため、所在を記録しておく。
- **記録**: 新旧ビルドの PR・コミット・版、登録時の版の前後、許可要求の有無、ヘルパーと agent の状態、`SleepDisabled`、再登録に関するログ。`off` の実行回数は成功ログがないので自動テストによる確認と区別する。

**結果欄**: 成功／失敗／判定不能: ____。更新前後の版・登録時の版・許可・抑止: ____。未実施項目と理由・気づいたこと: ____。

## 5. LED と Caps Lock の入力状態を確認する

この節では、LED が点灯すること（5.1）、入力状態が変わらないこと（5.1）、機器の抜き差しと復帰で点灯が戻ること（5.1）、キー配列を変更するアプリの案内と入力への影響（5.2）を見る。

この節は目視が主になる。判定は「LED と入力の両方」で行い、読み戻した値や画面の表示だけで合格にしない。

### 5.1 点灯、入力、接続変更、復帰を確認する

- **目的**: `HYP-LED-001`、`HYP-LED-003`、`HYP-LCY-001`、`SPEC-LED-001`、`SPEC-LED-002`、`SPEC-LED-003`。
- **前提**: 1.4の独立復旧手順が承認済みである。入力監視を新たに許可しない。「ディスプレイを自動でオフにしない」と時間・バッテリーの解除条件をオフにし、「ディスプレイを閉じたとき」を「スリープ」にする（MacBook 以外の Mac では「メニューから選んでもスリープさせない」をオフにする）。自動スリープの抑止は常に働く。Caps Lock は利用者が手動でオフにする。
- **操作**:
  1. LED の通知をオンにしてメニューで開始する。内蔵キーボードと、USB・Bluetooth・2.4 GHz レシーバーの各外付けキーボードで `abc` を入力する。
  2. 利用者が Caps Lock をオン・オフする。抑止を解除し、同じ操作を繰り返す。
  3. 再び開始し、外付けキーボードを接続・切断・再接続する。
  4. Apple メニューでスリープし、復帰する。LED を見る。続けて `pmset displaysleepnow` で画面だけをスリープさせ、10秒後に Shift キーで復帰させて LED を見る。`open -a ScreenSaverEngine` でスクリーンセーバーを起動して戻ったときと、Control + Command + Q でロックして解除したときも LED を見る。ロックでは、ロック画面の間と解除の後の両方を見る。
  5. 抑止中に LED の通知をオフにする。通常の Caps Lock 連動を確かめ、解除する。
- **期待**: 1は LED だけが点灯し、入力は小文字である。2は抑止中は点灯を保ち、解除後は通常連動に戻る。3・4は対象へ再適用する。5は通常連動に戻る。
- **中止**: 入力状態が勝手に変わる、入力監視の許可要求、復旧失敗の場合。
- **復元**: まずメニューで解除する。各対象の `"Auto"` 書き込みと目視確認ができなければ、承認済みの独立復旧手順を実行する。読み戻し値だけを合格条件にしない。
- **記録**: キーボードごとに、接続方式、LED の点灯、入力した文字の大小、解除後の戻り。スリープ復帰の所要時間も書く。

1.4 で控えた機器名と、3の抜き差しで反応した機器が同じかを照合する。名前が同じ機器が2台ある環境では、3の結果を機器ごとに分けて書く。

`HYP-LCY-001` の「書いたプロセスの終了後も残る」は、自動再起動する製品では復元と競合して測れない。独立した試作プロセスがないため判定不能とする。利用者が Caps Lock を操作する場合も、ソフトウェアから入力状態を変更する操作は使わない。

### 5.2 キー配列を変更するアプリの案内と入力への影響を確認する

- **目的**: `SPEC-LED-002`、`SPEC-LED-005`。
- **前提**: Karabiner-Elements を既に使える検証環境である。新たなインストールや設定変更はこの手順に含めない。修飾キーを厳密に照合する Karabiner-Elements のルール（`from.modifiers` に `optional` がないもの）を1つ用意している。
- **操作**: Karabiner-Elements が動作中に設定の「LED」を開き、案内を撮る。LED の通知をオンにして開始し、用意したルールを試す。解除してから Karabiner-Elements をメニューバーから終了し（「Quit Karabiner-Elements」）、案内が消えるか見る。
- **期待**: 動作中だけ設定の「LED」に案内がある。抑止中もルールが成立する。Karabiner-Elements が既定の設定で占有するキーボードでは、抑止中に Caps Lock をオンにしてオフにすると LED が消える（`DEC-LED-006` で受け入れた振る舞い、`EVID-LED-012`）。Caps Lock に触れない間は点いていてよい。終了後、10秒以内に案内が消える。
- **中止**: ルールが抑止中だけ成立しない、通常連動へ復元できない場合。
- **復元**: 抑止を解除し、承認済みの LED 復旧手順を実行する。Karabiner-Elements の稼働状態を開始前へ戻す。
- **記録**: 設定の「LED」の案内、ルールの成否、LED の目視、案内が消えるまでの秒数、Karabiner-Elements の稼働状態。

`HYP-LED-004` は製品が使わない `IOHIDDeviceSetValue` の試験である。専用試作と復旧手順がないので実施しない。`SPEC-LED-006` の関数欠落も通常ビルドでは模擬できないため判定不能とする。チケットの LED 番号範囲のうち、仕様に存在しない番号は割り当てない。

**結果欄**: 成功／失敗／判定不能: ____。機器・接続方式・実機／仮想・入力・LED 復元結果: ____。未実施項目と理由・気づいたこと: ____。

## 6. 終了と再開用の記録を確認する

この節では、利用者の終了とクラッシュを区別すること（6.1）、終了のしかたと再開設定の組み合わせ（6.2）、連続クラッシュの上限（6.2）を見る。

記録ファイル `$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json` は読むだけで、手で編集しない。判定に使う値は `session`、`ownsSleepDisabled`、`isRunning`、`exitReason`、`misalignments`、`lastUpdated`、`crashLaunches` である。

### 6.1 利用者の終了とクラッシュを区別する

- **目的**: `SPEC-LCY-002`、`SPEC-LCY-004`、`SPEC-LCY-006`、`SPEC-LCY-007`。
- **前提**: LED とヘルパーを使わず、自動スリープだけを止める。バッテリー・指定時刻の解除条件はオフにする。記録を直接編集しない。
- **操作**:
  1. 再開を「アプリと Mac の再起動時」にし、タイマーを10分にして開始する。メニューから終了する。
  2. 次を実行して記録を保存する。

     ```sh
     cat "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"
     cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/record.user-quit.json"
     /usr/bin/pmset -g assertions
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     ```

  3. Finder から起動する。停止中を確かめる。

     ```sh
     /usr/bin/open "$APP"
     sleep 3
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
     ```

  4. 再開を「アプリの再起動時だけ」にし、タイマーを10分にして開始する。開始前後の記録を保存する。

     ```sh
     /usr/bin/plutil -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" | /usr/bin/grep -E 'isRunning|exitReason|session|lastUpdated'
     ```

     2.2の4と同じく PID を照合し、Debug アプリの絶対パスと一致した場合だけクラッシュさせる。`kill -SEGV` は1回だけ行う。

     ```sh
     PID="$(/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/awk '$1 == "pid" && $2 == "=" {print $3}')"
     /bin/ps -p "$PID" -ww -o pid=,comm=
     /bin/kill -SEGV "$PID"
     ```

  5. 再起動後に記録を読み、元の解除時刻を過ぎるまで待つ。

     ```sh
     /usr/bin/plutil -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" | /usr/bin/grep -E 'isRunning|lastUpdated|misalignments'
     /bin/date '+%Y-%m-%dT%H:%M:%S%z'
     ```

- **期待**: 2は `isRunning = false`、`exitReason = userQuit`、`session` がない。アサーションは解放済みである。3は再開しない。4は再開し、5は元の期限で解除し、タイマーを数え直さない。
- **中止**: 記録保存失敗の警告、解除時刻の延長、PID の不一致の場合。
- **復元**: 解除し、再開を「再開しない」に戻す。記録を消して不具合を隠さず、9節まで保管する。
- **記録**: 2と5で読んだ記録の中身、アサーションの有無、解除した時刻、再開までにかかった時間。

クラッシュさせる前に、2.2の4と同じく PID が Debug アプリの絶対パスと一致することを確かめる。`kill -SEGV` は1回だけ行い、再起動しないときに撃ち直さない。

輝度のクラッシュ復旧は別の回で4.7の前提を整え、「アプリの再起動時だけ」で暗くした後、この節の4の PID 照合とクラッシュを行う。ディスプレイを閉じたまま再起動を待ってから開き、元と同じくらいの明るさ、抑止の再開、`savedBrightness` の消去を確認し、4.7の復元を行う（`SPEC-BLK-013`）。

### 6.2 ログアウト・再起動・連続クラッシュを確認する

- **目的**: `HYP-LCY-004`、`HYP-LCY-005`、`SPEC-LCY-004`、`SPEC-LCY-006`、`SPEC-LCY-007`。
- **前提**: 6.1が成功し、ログイン起動をオンにしている。LED とヘルパーを使わない。ログアウト・再起動の確認では「再ログイン時にウインドウを再度開く」のチェックを外す。
- **操作**:
  1. 次の表の各行で新しく抑止を開始し、記載の終了操作を行う。再ログイン後、状態と再開用の記録を保存する。各行の間に解除する。

     | 再開設定 | 終了操作 | 期待する状態 |
     | --- | --- | --- |
     | 再開しない | Apple メニューの再起動 | 停止中 |
     | アプリの再起動時だけ | ログアウト、続けて別の試行で再起動 | 両方とも停止中 |
     | アプリと Mac の再起動時 | ログアウト、続けて別の試行で再起動 | 両方とも抑止中 |
     | アプリと Mac の再起動時、タイマー1分 | システム終了して2分以上待って起動 | 期限切れなので停止中 |

     再ログイン後は0節で退避先を入れ直し、次で状態と記録を保存する。

     ```sh
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
     /usr/bin/plutil -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" | /usr/bin/grep -E 'isRunning|exitReason|lastUpdated|crashLaunches'
     ```

  2. 再起動直前と直後に `sysctl kern.boottime` と `date '+%Y-%m-%dT%H:%M:%S%z'` を保存する。`lastUpdated` は Swift の `Date` の標準 JSON 表現で、2001-01-01 UTC からの秒数である。UNIX 秒と直接比較しない。

     ```sh
     /usr/sbin/sysctl kern.boottime
     /bin/date '+%Y-%m-%dT%H:%M:%S%z'
     ```

  3. 再開を「アプリの再起動時だけ」にして開始する。10分以内に、2.2の PID 照合→クラッシュ→別 PID の起動確認を3回、1回ずつ行う。途中で手動の解除や開始をしない。1回分は次のとおりで、これを3回繰り返す。`ps` の出力が Debug アプリの絶対パスでなければシグナルを送らない。

     ```sh
     PID="$(/bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/awk '$1 == "pid" && $2 == "=" {print $3}')"
     /bin/ps -p "$PID" -ww -o pid=,comm=
     /bin/kill -SEGV "$PID"
     sleep 5
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug" | /usr/bin/grep -E '^[[:space:]]*(state|pid|runs|last exit code) ='
     ```

- **期待**: 表のとおりである。同じ Mac 起動中の `kern.boottime` は変わらず、Mac 再起動後は保存した更新時刻より後になる。連続クラッシュは1・2回目だけ再開し、3回目は停止中となる。`crashLaunches` に3件が残る。
- **中止**: ログインしても起動しない、再開条件と結果が違う、3回目でも再開する場合。追加のシグナルを送らない。
- **復元**: 起動していれば解除し、再開を「再開しない」に戻す。再起動・ログアウトで失われる他アプリの未保存データは戻せないので事前保存を必須とする。
- **記録**: 表の行ごとの再開設定と結果、`kern.boottime`、`lastUpdated`、`crashLaunches` の件数、3回のクラッシュで撃った PID と再起動後の PID。

表の各行は独立した試行である。行をまたいで抑止を続けない。行の途中で期待と違う結果が出たら、その行だけを止めて記録し、次の行へ進んでよいかは PM が決める。

`HYP-LCY-005` の Apple Event の生値、終了処理の意図的な引き延ばし、ログアウト取り消し後の内部判定は通常ビルドで採取・注入できない。表による間接確認と区別して判定不能とする。`HYP-LCY-004` の時計を戻す試験は、他サービスにも影響するため実施しない。起動処理途中の中断、起動時刻の取得不能、記録保存失敗、ヘルパーの期限超過は専用の偽物を使う自動テストに任せ、実機の権限や時計を壊して模擬しない。

**結果欄**: 成功／失敗／判定不能: ____。再開設定・終了理由・期限・起動時刻・クラッシュ回数: ____。未実施項目と理由・気づいたこと: ____。

## 7. CLI の起動・書式・終了コードを確認する

この節では、停止したアプリを CLI が起こせること、出力と終了コード、ソケットの所有者（7.1）、受け付けない入力と設定を拒むこと（7.2）、ヘルプ、時間の条件なしの指定、色を付けない出力（7.3）を見る。

この節で使う試験対象のパスだけを定義する。7節の外では使わない。

```sh
CLI="$APP/Contents/Helpers/capsaicin"
```

終了コードの意味は次のとおり。数字だけを覚えるより、どの状態を表すかで読む。

| 終了コード | 意味 |
| --- | --- |
| `0` | 成功。開始、解除、状態の取得ができた |
| `1` | `status` で停止中 |
| `64` | 使い方の誤り（引数の形が違う） |
| `69` | 要求を完了できなかった。アプリに接続できないときもこれ |

### 7.1 停止したアプリを CLI から起動する

- **目的**: `SPEC-CLI-001`、`SPEC-CLI-002`、`SPEC-CLI-003`、`SPEC-CLI-004`、`SPEC-CLI-006`、`SPEC-CLI-007`。
- **前提**: CLI を受け付ける設定がオンで、「ディスプレイを閉じたとき」は「スリープ」（MacBook 以外の Mac では「メニューから選んでもスリープさせない」はオフ）、LED はオフである。バッテリーの解除条件もオフにする。メニューからアプリを終了する。
- **操作**: 1コマンドずつ出力を記録する。`set -e` は使わない。

  ```sh
  "$CLI" on --for 1m
  printf 'exit=%s\n' "$?"
  "$CLI" status
  printf 'exit=%s\n' "$?"
  "$CLI" on --for 2m
  printf 'exit=%s\n' "$?"
  "$CLI" off
  printf 'exit=%s\n' "$?"
  "$CLI" status
  printf 'exit=%s\n' "$?"
  ```

  設定の「操作」で CLI パスをコピーし、`$CLI` と同じ絶対パスか比較する。ソケットも読む。

  ```sh
  /bin/ls -ld "/private/tmp/io.github.koutyuke.capsaicin-$(id -u)"
  /bin/ls -l "/private/tmp/io.github.koutyuke.capsaicin-$(id -u)/ipc.debug.sock"
  ```

- **期待**: 最初の `on` でその CLI を含む Debug アプリが起動する。終了コードは順に `0, 0, 0, 0, 1`。出力は英語で、抑止中は結果・状態の行に続けて解除の条件が出る。解除の時刻はローカルの24時間制で、残り時間を伴う（`SPEC-CLI-003`）。2回目の `on` は、その要求を受けた時点から2分後に解除の時刻を置き換え、置き換えたことと新しい解除の条件を伝える。停止中には解除の条件の行が出ない。CLI 操作では HUD が出ない。ソケットの親は当該ユーザー所有で700、Debug ソケットは `ipc.debug.sock` である。
- **中止**: Release の起動、接続失敗、所有者違いの場合。ソケットの権限を変えて回避しない。
- **復元**: CLI の `off`、またはメニューで解除する。ソケットは共有ディレクトリごと消さない。
- **記録**: 各コマンドの標準出力・標準エラー・終了コード、アプリが起動したか、コピーした CLI パスと `$CLI` の一致、ソケットの所有者と権限。

### 7.2 不正な書式と受け付けない設定を確認する

- **目的**: `SPEC-CLI-001`、`SPEC-CLI-005`、`SPEC-CLI-007`。
- **前提**: 停止中で CLI を受け付けている。
- **操作**:
  1. 次を1つずつ実行する。

     ```sh
     "$CLI" on --for 0m
     printf 'exit=%s\n' "$?"
     "$CLI" on --until 24:00
     printf 'exit=%s\n' "$?"
     "$CLI" on --for 1m --until 4:00
     printf 'exit=%s\n' "$?"
     "$CLI" on --for 1m --for 2m
     printf 'exit=%s\n' "$?"
     "$CLI" on --for 1m --no-time-limit
     printf 'exit=%s\n' "$?"
     "$CLI" on --no-time-limit 1h
     printf 'exit=%s\n' "$?"
     ```

  2. メニューで開始し、設定の「操作」で CLI を受け付けない設定にする。

     ```sh
     "$CLI" off
     printf 'exit=%s\n' "$?"
     ```

  3. メニューを開いて状態を見る。CLI の許可をオンに戻し、`"$CLI" off` を実行する。
- **期待**: 1はすべて標準エラーに `error:` で始まる英語の理由と、続く行に `--help` の案内を出し、終了値 `64` で開始しない。2は標準エラーにエラーを出し、終了値 `69` で抑止中を保つ。3で解除できる。
- **中止**: 不正入力で開始した、拒否したはずの `off` が状態を変えた場合。
- **復元**: CLI をオンに戻し、メニューで解除する。リンクやエイリアスは作らない。
- **記録**: 6つの不正入力それぞれの標準エラーと終了コード、拒否後の抑止状態、3で解除できたこと。

### 7.3 ヘルプ・時間の条件なし・色を付けない出力を確認する

- **目的**: `SPEC-CLI-001`、`SPEC-CLI-003`、`SPEC-CLI-007`、`SPEC-CLI-008`。
- **前提**: CLI を受け付ける設定がオンで、スリープと LED の設定は7.1と同じである。バッテリー残量の条件はオフにする。設定のタイマーと指定時刻のオン・オフと値を記録する。メニューで抑止を解除してからアプリを終了する。
- **操作**:
  1. 次を1つずつ実行する。プロセスの検索は、ヘルプの実行前後でアプリが停止したままかを見るために行う。

     ```sh
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     "$CLI" --help
     printf 'exit=%s\n' "$?"
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     "$CLI" -h
     printf 'exit=%s\n' "$?"
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     ```

  2. 検証中の Debug アプリを Finder から起動する。設定のタイマーを1分、指定時刻を2分後にして両方をオンにする。次を実行し、2分待ってから `status` をもう一度実行する。

     ```sh
     "$CLI" on --no-time-limit
     printf 'exit=%s\n' "$?"
     "$CLI" status
     printf 'exit=%s\n' "$?"
     ```

  3. 次を実行し、1分待ってから `status` をもう一度実行する。

     ```sh
     "$CLI" on --for 1m
     printf 'exit=%s\n' "$?"
     "$CLI" status
     printf 'exit=%s\n' "$?"
     "$CLI" on --no-time-limit
     printf 'exit=%s\n' "$?"
     "$CLI" status
     printf 'exit=%s\n' "$?"
     ```

  4. 抑止中に次を実行し、エスケープシーケンスを表す `^[` が出力に混ざらないかを見る。`cat -v` による記号の変換と、エスケープシーケンスを区別する。

     ```sh
     "$CLI" status | cat -v
     NO_COLOR=1 "$CLI" status
     NO_COLOR=1 "$CLI" status | cat -v
     ```

- **期待**: 1は説明、書式、サブコマンド、`on` のオプション、終了コードが英語で標準出力に出て、終了値はどちらも `0` になる。プロセスの検索ではアプリが見つからない。2は終了値 `0` で時間の条件なしの抑止を開始し、2分後も抑止中である。3は最初の `status` に解除の時刻と残り時間が出て、`--no-time-limit` の後は解除の時刻がなくなる。いずれも終了値は `0` で、1分後も抑止中である。時間の条件がないときに何を伝えるかは `SPEC-CLI-003` に従う。4はパイプと `NO_COLOR=1` のどちらでも色が付かず、`cat -v` を通した出力に `^[` が出ない。
- **中止**: ヘルプでアプリが起動した、Release が起動した、時間の条件なしの指定でも解除の時刻が残る、待機中に解除された場合。色の出力が期待と違う場合も後続を止め、出力を残す。
- **復元**: `"$CLI" off` またはメニューで解除する。タイマーと指定時刻を記録した値とオン・オフに戻す。`NO_COLOR=1` はそのコマンドだけに指定し、シェルの設定やリンク・エイリアスは変えない。
- **記録**: ヘルプの標準出力・標準エラー・終了コードと前後のプロセス、2と3の出力・終了コード・待機後の状態、4の端末と `cat -v` の出力、戻した設定を `B` に残す。

**結果欄**: 成功／失敗／判定不能: ____。CLI の絶対パス・出力・終了コード・ソケット: ____。未実施項目と理由・気づいたこと: ____。

## 8. メニュー・設定・HUD・キーボード操作を確認する

この節では、メニューと入力パネル（8.1）、設定画面の構成と外観（8.2）、HUD・複数画面・ホットキー・アクセシビリティ（8.3）、設定画面を開く位置と前面（8.4）、抑止中の時間の変更（8.5）、スリープとディスプレイの設定の項目（8.6）、バッテリー残量の項目（8.7）を見る。目視と計測が中心になる。計測できない寸法を「だいたい合っている」で合格にしない。

### 8.1 メニューと入力パネルを確認する

- **目的**: `SPEC-MENU-001`、`SPEC-MENU-002`、`SPEC-MENU-003`、`SPEC-MENU-004`、`SPEC-MENU-005`、`SPEC-UI-005`。
- **前提**: 停止中で、ヘルパーを使う設定と LED はオフである。設定の開始値を控え、時間・バッテリーの解除条件はオフにする。内蔵バッテリーのある Mac では電源アダプターをつなぐ。この節はコマンドを使わず、目視と画面の操作で確かめる。
- **操作**:
   1. メニューを開き、停止中の並びを `SPEC-MENU-001` と比較する。指定のない開始と区切りの後に、時間の条件なしの項目と時間・時刻のサブメニューがあり、さらに区切りとクイック設定のサブメニューがあることを見る。時間・時刻のサブメニューは `SPEC-MENU-002` と比較し、起点が今と分かる見出し、プリセット、任意の時間の入力、区切り、時刻の指定が並び、チェックと時間の条件なしの項目がないことを見る。パネルを開く項目は末尾に省略記号があり、さらにサブメニューを開く矢印がないことを見る。トップレベルにチェックの付く項目がなく、左にチェック用の余白がないことを確かめる。クイック設定の中は `SPEC-MENU-008` と比べる。
   2. 時間・時刻のサブメニューから任意時間のパネルを開き、0時間0分、24時間1分、数字でない文字を入力する。続けて0時間58分を入力して分の `Stepper` を上げ、分の数値欄で ↓ を押す。23時間30分から時間の `Stepper` を上げ、時間の数値欄で ↑ を押す。0時間3分から分を下げる。Esc で閉じ、再度開いて1分を入力し、入力欄の下のオフになる時刻を控えて Return で開始する。
   3. メニューを開いて解除時刻と分単位の残り時間を見る。1分後の自動解除を待つ。
   4. 停止中の時間・時刻のサブメニューから時刻のパネルを開き、その日に過ぎた時刻を入力する。時間のパネルのオフになる時刻と同じ位置に翌日の表示があることを見る。開始せず Esc で閉じる。
   5. タイマーを3分にして開始し、メニューを2分開いたままにする。解除後、タイマーをオフに戻す。
   6. 内蔵バッテリーのある Mac では、電源アダプター接続中に残量で解除しない設定をオンにして、バッテリー残量の条件をオンにする。停止中の指定のない開始の副題を見る。タイマーを1時間でオンにしてもう一度見てから、タイマーをオフ、指定時刻をその日に過ぎた時刻でオンにして見る。最後に指定時刻もオフにし、開始して状態の行を見る。各段階で、時間の条件なしで開始する項目がトップレベルにあることも確かめる。内蔵バッテリーのない Mac では、この操作は判定不能として飛ばす。
- **期待**: 1の並びが仕様と一致する。不正な入力は別の値に直らず開始できない。分を上げると1時間3分、↓ で0時間58分に戻り、時間を上げると24時間0分で止まり、0時間3分から分を下げると0時間1分で止まる。1分では開始し、控えた時刻に自動解除する。翌日表示があり、残り時間が分単位で更新される。アイコンの見た目は状態で動かない。6の副題は順に、自分で解除するまで続くこと、1時間後に解除すること、翌日の指定時刻に解除することを示し、バッテリー残量の条件を含まない。時間の条件なしで開始した後は、自分で解除するまで続くことの下に、バッテリーの条件の行がある。
- **中止**: 入力拒否、パネル多重表示、期限どおりに解除されない場合。
- **復元**: パネルを Esc で閉じ、メニューで解除する。試した設定と電源アダプターの接続を開始前に戻す。
- **記録**: メニューの並び順とパネルを開いた項目、入力した値と反応、開始の副題、状態の行、残り時間の表示、自動解除した時刻、アイコンの見た目、設定と電源接続を戻したこと。

### 8.2 設定と外観を確認する

- **目的**: `SPEC-SET-001`、`SPEC-SET-002`、`SPEC-SET-003`、`SPEC-SET-004`、`SPEC-SET-005`、`SPEC-SET-006`、`SPEC-UI-001`、`SPEC-UI-002`、`SPEC-UI-003`、`SPEC-UI-004`、`SPEC-UI-005`、`SPEC-UI-006`。
- **前提**: 1.4で OS の開始値を写真に保存済みである。設定の既定値の判定は、既存設定のない環境でだけ行う。既存設定を削除して既定値試験を追加しない。
- **操作**:
  1. 設定を開き、6セクションを順に選ぶ。幅720 pt・高さ500 pt、サイドバー200 pt、固定サイズ、最小化・ズーム無効を仕様と比較する。計測できない寸法は目視合格にしない。上端を横切るタイトルバーの帯がなく、サイドバーが上端まで伸び、右側の最上段にセクション名が出るか見る。「ヘルパー」と「このアプリについて」がサイドバーの下端に寄っているかを、システム設定の「外観」の「サイドバーのアイコンのサイズ」を小・中・大に変えて見る（変更前の値を記録し、終わったら戻す）。↑↓ で6項目を通して移動し、上下の境目でも選択が続くか見る。
  2. (i) をポインタ、Tab と Space の両方で開く。ツールチップと同じ説明か読む。「スリープ」では「ディスプレイを自動でオフにしない」、ヘルパーが要る行、「指定時刻」にだけ (i) があるか、説明の内容が `SPEC-SET-002` の表と一致するかを見る。LED セクションで閉じて開き直し、選択が保たれるか見る。⌘W で閉じる。開き直して各セクションのカード・見出し・アイコンを `SPEC-SET-002` の表と比較する。「スリープ」が「スリープとディスプレイ」「スリープ防止の自動解除」「バッテリー」の3グループに分かれ、タイマーと指定時刻が自動解除、残量の条件とその子の行がバッテリーにあることを見る。内蔵バッテリーがない Mac では、バッテリーのグループ全体がないことを見る。子の行の項目名が親とそろうかを見る。「スリープ」は下端までスクロールして、すべての行を操作できるか見る。「一般」は案内を含めてスクロールせずに収まるか記録する（`HYP-UI-004`）。案内を表示する安全な条件を用意できなければ、その項目だけ判定不能とする。
  3. 「ディスプレイを閉じたとき」に4つの選択肢があり、独立した子の行がないことを確かめる。4.3で許可を外した場合は、保存した選択肢（MacBook 以外の Mac ではオンのスイッチ）が表示されたまま、行のアイコンが注意の記号に替わり、(i) の先頭で適用できない理由とシステム設定での許可の案内を読めることを見る。安全に用意できなければ注意の表示だけ判定不能にする。バッテリー残量の条件のスイッチは、オンにすると残量が少なくなったらスリープ防止をオフにすると項目名だけで分かるか読む。タイマー・指定時刻・バッテリー残量をオフ・オンし、継続時間、時刻、しきい値、電源アダプタの子の行が、オフの間は字下げとグレーで無効と分かり、(i) がなく、オンに戻すと値を保持しているかを見る。
  4. 「このアプリについて」でバージョンとビルド番号をコピーする。
  5. システム設定でライト、ダーク、アクセントカラーを切り替え、各画面を撮る。変更のたびに値を記録する。文字の大きさを変更できる環境では変更前を記録してから比較する。
   6. 抑止を解除し、アプリの「メニューバーにアイコンを表示する」をオフにする。設定画面を閉じて Finder から開き直し、「このアプリについて」の「Capsaicin を終了」ボタンを押す。試験後は `/usr/bin/open "$APP"` でアプリを起動し直し、アイコンの設定を開始値に戻す。
   7. 「スリープ」でタイマーをオンにし、継続時間の時間・分それぞれに `Stepper` があることを見る。8.1の2と同じ増減とキー操作、不正な入力を試し、保存値の前後を記録する。試した値とタイマーのオン・オフを開始前に戻す。
- **期待**: ウインドウは幅720 pt × 高さ500 pt、サイドバー200 pt の固定で、最小化とズームが無効である。上端を横切るタイトルバーの帯がなく、サイドバーが上端まで伸び、右側の最上段に選んだセクション名が出る。サイドバーの上の4項目と下端の2項目が並び、「ヘルパー」と「このアプリについて」は下端からシステム既定の余白だけ離れている。カード・見出し・アイコンは [設定仕様](../specs/settings.md) の表と一致し、子の行にはアイコンがなく、項目名が親とそろう。「スリープ」はスクロールで全項目を操作できる。設定の切り替えで行が動かず、親がオフの子の行は字下げとグレーで無効と分かり、(i) はない。情報はコピーでき、外観に追従して読める。既定値は設定仕様の表と一致する。終了ボタンは標準の枠付きで色が付かず、押すとアプリが終了する。7の継続時間の増減は8.1と同じ結果になり、不正な入力は別の値に直らず、確定もできず、最後の有効な保存値が変わらない。
- **中止**: 元の OS 設定が分からない、他アプリへ影響する変更を避けられない場合。
- **復元**: 試験したアプリ設定を元の試験値に戻す。OS の外観・文字・アクセントカラーを写真の開始値へ戻す。設定全体は9節で退避から戻す。
- **記録**: 6セクションそれぞれの表示、寸法の実測値、タイトルバーとサイドバーの状態、下端寄せの見え方（アイコンのサイズ3段階）、カードと項目アイコン、スクロールの有無、「一般」の案内を含む表示が収まるか、「このアプリについて」からの終了、撮った画面写真の絶対パス。

寸法は、画面写真に定規を当てるのではなく、Accessibility Inspector か画面撮影の解像度から換算して確かめる。換算できない場合は「目視のみ」と明記して判定不能に寄せる。サイドバーのアイコンのサイズは行の高さを変えるので、小・中・大の3段階で下端寄せが崩れないかを見る。変更前の値に戻したことも結果に書く。

### 8.3 HUD、複数画面、ホットキー、アクセシビリティを確認する

- **目的**: `SPEC-HUD-001`、`SPEC-HUD-002`、`SPEC-HUD-003`、`SPEC-HUD-004`、`SPEC-HUD-005`、`SPEC-HUD-006`、`SPEC-HUD-007`、`SPEC-HUD-008`、`SPEC-KEY-001`、`SPEC-KEY-002`、`SPEC-UI-007`、`SPEC-UI-008`。
- **前提**: LED とヘルパーを使わず、自動スリープだけを止める。試験中にバッテリーの条件が成り立たない状態にする。
- **操作**:
  1. 「操作」でホットキー記録欄に ⌃⌥⌘C を割り当てる。別アプリの入力中に2回押し、開始・解除と HUD を見る。記録の Esc、Delete、重複による登録失敗も試す。実際に重複する安全な組み合わせを用意できなければ、その項目だけ判定不能とする。
  2. HUD の位置に別ウインドウを置き、表示中に入力とクリックを続ける。3秒間に10回切り替える。1枚の表示、フォーカス、最後の状態を記録する。
  3. 外部画面にカーソルを置いて表示し、表示中に内蔵画面へ移して切り替える。消えた後にも切り替える。表示中に外部画面を外す。
  4. システム設定で「視差効果を減らす」「透明度を下げる」「コントラストを上げる」を1つずつオンにし、HUD を録画・撮影する。各項目を開始値に戻してから次へ進む。
  5. VoiceOver とフルキーボードアクセスをオンにし、マウスを使わずメニュー、設定、(i)、入力パネルを操作する。HUD をオフにした状態でも、ホットキーによる切り替えの読み上げを聞く。CLI では読み上げないことも比較する。
  6. 抑止中に10分作業し、アイコンの点滅や不用な通知がないか記録する。60 Hz・120 Hz の画面があれば録画し、HUD のコマ落ちを比較する。Accessibility Inspector が使える場合、明暗の壁紙で文字のコントラストを測る。
- **期待**: HUD は高さ48 pt、横は内容に合わせて最大420 pt、下端から64 pt の位置で、約2.1秒で消える。表示中の更新は同じ画面にとどまり、次の新規表示でカーソルの画面へ移る。画面切断では消える。視差効果低減では移動・拡大をしない。VoiceOver は HUD オフでも内容を読み、中黒を読まない。コントラストは4.5:1以上である。
- **中止**: 操作不能、フォーカスを奪う、読み上げの重複、開始値へ戻せない場合。
- **復元**: メニューで解除する。試験用ホットキーを消す。VoiceOver、フルキーボードアクセス、3つの表示設定、外部画面の接続を開始前に戻す。
- **記録**: HUD の寸法と位置（測った方法も）、消えるまでの時間、画面ごとの表示と移動、読み上げの内容、コントラストの測定値、録画・撮影の絶対パス。

高さと位置は画面録画から測る。録画のフレームレートが分かっていれば、消えるまでの時間も同じ録画から数えられる。目分量しかできない場合は、その旨を書いて判定不能に寄せる。

ヘルパーの削除を含む VoiceOver 試験は、4節を同じ安全条件で再実施できる場合だけ行う。正式アイコンの `SPEC-UI-009`・`SPEC-UI-010` は正式素材が用意された後の検査であり、代替シンボルで合格にしない。`SPEC-UI-011` の表示言語は8.8で確認する。

**結果欄**: 成功／失敗／判定不能: ____。外観・表示設定・画面構成・VoiceOver・動画／画像の所在: ____。未実施項目と理由・気づいたこと: ____。

### 8.4 設定画面を開く位置と前面を確認する

- **目的**: `SPEC-SET-001` の「ほかのデスクトップとフルスクリーン」と、`HYP-SET-003`。
- **前提**: デスクトップ（Space）が2つ以上ある。システム設定の「デスクトップと Dock」にある「アプリケーションの切り替えで、アプリケーションのウインドウが開いているスペースに移動」の開始値を記録し、オンにする。Capsaicin の「Dockにアイコンを表示」はオフから始める。Safari など、フルスクリーンにできるアプリを1つ用意する。この節はコマンドを使わず、目視で確かめる。
- **操作**:
  1. 設定画面を閉じた状態で、Safari を前面にし、ステータスアイコンのメニューから設定を開く。
  2. デスクトップ1で設定画面を開いたまま、デスクトップ2に移って Safari を前面にし、メニューから設定を開く。
  3. 設定画面を ⌘W で閉じ、デスクトップ2で Safari を前面にしてから、メニューから設定を開く。
  4. 設定画面を閉じ、Safari をフルスクリーンにしてから、メニューから設定を開く。終わったら Safari のフルスクリーンを解除する。
  5. 「Dockにアイコンを表示」をオンにして、1〜4を繰り返す。2 と 3 は、メニューの代わりに Dock のアイコンのクリックでも試す。
  6. 「アプリケーションの切り替えで…」をオフにして、2 を繰り返す。
- **期待**:
  1. 設定画面が Safari の前に、前面のキーウインドウとして開く。
  2. デスクトップ1へ移り、設定画面が前面のキーウインドウになる。
  3. デスクトップ2に、前面のキーウインドウとして開く。デスクトップ1へは移らない。
  4. フルスクリーンの Safari の上に、前面のキーウインドウとして開く。デスクトップは切り替わらない。
  5. 1〜4 と同じ結果になる。
  6. デスクトップ2にとどまる。設定画面がデスクトップ2へ引っ越してくることもない。
- **中止**: 設定画面がどのデスクトップにも見つからない、操作を受け付けなくなった場合。
- **復元**: Safari のフルスクリーンを解除する。「アプリケーションの切り替えで…」と「Dockにアイコンを表示」を開始値に戻す。
- **記録**: 操作ごとに、前面になったアプリ、移ったデスクトップ、設定画面が出たデスクトップ、キーウインドウになったか（タイトルの色と閉じるボタンの色で見る）。期待と違った操作は、画面録画の絶対パスも残す。

**結果欄**: 成功／失敗／判定不能: ____。Dock の表示ごとの各操作の結果: ____。未実施項目と理由・気づいたこと: ____。

### 8.5 抑止を続けたまま時間を変更する

この小節で使う試験対象のパスを定義する。7節で定義した値には依存しない。

```sh
CLI="$APP/Contents/Helpers/capsaicin"
```

- **目的**: `SPEC-BLK-003`、`SPEC-BLK-011`、`SPEC-MENU-002`、`SPEC-MENU-003`、`SPEC-HUD-001`、`SPEC-HUD-002`。
- **前提**: 停止中で、ヘルパーを使う設定と LED はオフにする。時間・バッテリーの解除条件はオフ、HUD と CLI はオンにする。設定の開始値を控える。
- **操作**:
   1. 停止中の時間・時刻のサブメニューを開き、並びを記録して30分を選んで開始する。1分以上待ち、抑止中の並びを `SPEC-MENU-001` と比較する。トップレベルにチェックの付く項目と左のチェック用の余白がないことを見る。解除の時刻を変更するサブメニューを `SPEC-MENU-002` と比較し、停止中と同じ並びの末尾に、抑止中だけ区切りと時間の条件なしの項目があることを見る。起点が今と分かる見出しがあり、チェックがないことも確かめる。30分を選び直し、操作した時刻を控える。前後のアサーションは3.1の読み取りコマンドで比較する。
   2. 解除の時刻を変更するサブメニューから時間と時刻のパネルを順に開き、初期値を `SPEC-MENU-003` と比較する。タイトルと確定のボタンが変更であることを示すか見る。時間は2分に変え、オフになる時刻を控えて確定する。
   3. 自動解除を待たずに、メニューで時間の条件なしを選ぶ。2で控えた時刻を過ぎるまで待つ。時間・時刻のパネルを開き、初期値が停止中と同じ規則になるかを確かめて取り消す。
   4. 時刻のパネルを開いたまま `"$CLI" off` で解除する。停止中にも時間のパネルを開き、`"$CLI" on --for 1m` で開始してパネルが閉じるか見る。解除して設定のタイマーをオンにしてから、トップレベルの時間の条件なしの項目を選んで開始し、設定の既定値を使わないことをメニューの表示で確かめる。
- **期待**: 1は選び直した時点から30分後が解除の時刻になり、アサーションは同じ ID のままである。2は新しい時刻に置き換わる。どちらも抑止は続き、開始と同じ形の HUD に新しい条件が出る。3は解除の時刻がなくなり、HUD は時間では自動解除しないことを示し、2の期限を過ぎても抑止が続く。時間を選ぶ操作で設定の既定値は変わらない。4はどちらの状態変化でもパネルが閉じ、時間の条件なしの開始は設定のタイマーを使わない。
- **中止**: 置き換えで抑止が停止中になる、期限や初期値が仕様と違う、パネルが閉じず古い状態で確定できる場合。
- **復元**: パネルを Esc で閉じ、メニューで解除する。試した設定を開始値に戻す。
- **記録**: 選び直した時刻と解除の時刻、アサーションの ID、パネルの初期値・タイトル・ボタン・予告、HUD の内容、時間の条件をなくした後の状態、設定の保存値の前後、状態変化でパネルが閉じたこと。

### 8.6 メニューからスリープとディスプレイの設定を切り替える

- **目的**: `SPEC-MENU-008`、`SPEC-SET-005`、`SPEC-SET-006`、`SPEC-BLK-009`。
- **前提**: 停止中である。対象の設定の開始値、ヘルパーの状態、VoiceOver の開始値を控える。時間・バッテリーの解除条件はオフにする。ヘルパーの登録やシステム設定での許可の変更は4節の安全条件で承認できる場合だけ行い、バンドルやシステムのファイルを壊して注意を作らない。
- **操作**:
   1. メニューを開き、トップレベルにクイック設定のサブメニューが1つだけあり、チェックの付く項目と左のチェック用の余白がないことを見る。クイック設定を1回開き、項目・選択肢・区切りを `SPEC-MENU-008` と比べる。見出しは「ディスプレイを閉じたとき」だけで、閉じたときの選択肢の前後が区切りで囲まれ、どの項目も字下げされていないかを見る。項目名・選択肢・順序が設定画面と同じで、さらにサブメニューを開かずに選べ、チェックが保存値で有効な項目・選択肢を示すか見る。MacBook と MacBook 以外の Mac の出し分けは、用意できる機種でそれぞれ確認する。
   2. 停止中にメニューでディスプレイスリープの項目を切り替え、設定画面とメニューを開き直す。続けて抑止を開始し、同じ項目を切り替える。3.1のアサーションの読み取りで、その場で反映されたか比較する。
   3. 未インストールの環境でヘルパーが要る選択肢を選び、設置の確認を取り消す。保存値とチェックが元のままか見る。登録とシステム設定での許可の前後も、安全に確認できる場合は4.1と同じ条件でメニューから試す。用意できなければ該当する確認を判定不能にする。
   4. ヘルパーが要る保存値のまま、4.3でシステム設定の許可を外せる場合だけ、クイック設定の行の注意アイコンを見る。サブメニューを開き、MacBook では保存値の選択肢、MacBook 以外の Mac ではオン・オフの項目に注意の記号と副題があり、チェックを保ったまま操作できることを見る。
   5. MacBook で VoiceOver をオンにし、クイック設定を開いて、ディスプレイを閉じたときの各選択肢へ順に移る。読み上げだけで何の動作の選択肢か分かるか確かめ、VoiceOver を開始値に戻す。
- **期待**: 1はサブメニュー1回で設定を選べ、トップレベルにチェック用の余白がない。停止中と抑止中で同じ形で、設定画面と同じ保存値を示す。2の抑止中の変更はその場で反映され、ほかの設定値は変わらない。3の確認・エラー・巻き戻しは設定画面と同じである。4はクイック設定の行にも注意の記号があり、保存値の項目・選択肢の副題から、適用できない理由とシステム設定での許可の案内が読める。5はディスプレイを閉じたときの動作の選択だと読み上げで分かる。
- **中止**: 保存値とチェックが食い違う、取り消しても変更が残る、反映に失敗しても巻き戻らない場合。承認範囲を超える登録・許可の変更は進めない。
- **復元**: メニューで解除し、試した設定と VoiceOver を開始値へ戻す。ヘルパーに触れた場合は4節の対応する復元手順に従う。
- **記録**: 機種別の項目と選択肢、サブメニューを開いた回数、トップレベルの左の余白、チェックと保存値の前後、アサーションの前後、設置確認の取り消しと登録・許可の結果、注意の位置と副題、閉じたときの選択肢の読み上げ、安全に用意できず判定不能にした項目。

### 8.7 メニューからバッテリー残量の条件を切り替える

- **目的**: `SPEC-MENU-008`、`SPEC-SET-002`、`SPEC-SET-006`、`SPEC-BLK-006`、`SPEC-BLK-009`。
- **前提**: 開始前に、設定の値と電源アダプターの接続状態を控える。停止中に、ヘルパーを使う設定・LED・タイマー・指定時刻をオフにする。内蔵バッテリーがあり、残量が30%以上90%以下で、電源アダプターをすぐにつなぎ直せる Mac を使う。残量の範囲外なら充放電して合わせず、この小節を判定不能とする。電池を消耗させて条件を作らない。この節はコマンドを使わず、画面と電源アダプターの操作で確かめる。
- **操作**:
   1. 電源アダプターをつなぎ、設定画面でバッテリー残量の条件をオンにする。しきい値を5%、10%、100%と動かし、5%刻みで選べて0%は選べないことを確かめる。電源アダプター接続中に残量で解除しない設定をオンにして、設定画面を閉じる。
   2. メニューを開き、トップレベルにチェックの付く項目と左のチェック用の余白がないことを見る。クイック設定を1回開き、さらにサブメニューを開かずバッテリー残量の項目を選べることと、項目の並びを `SPEC-MENU-008` と比べる。残量の項目をオフにし、サブメニュー内のチェックと設定画面でもオフになっていることを見る。停止中にオンに戻し、設定画面を閉じてメニューを開き直す。
   3. 指定のない開始の項目を選んで抑止を開始し、クイック設定でバッテリー残量の条件をオフにする。メニューを開き直し、状態の行とサブメニュー内のチェックを見る。電源アダプターを外しても抑止が続くことを見たら、同じ項目をオンに戻す。自動解除を確認した直後に電源アダプターをつなぎ直し、設定画面とメニューを開いて保存値とチェックも見る。
   4. 停止中の設定画面で、電源アダプター接続中に残量で解除しない設定をオフにし、クイック設定を開く。バッテリー残量の項目の副題を確認してから、その設定をオンに戻す。メニューからはしきい値と電源アダプターの設定を変更できず、タイマーと指定時刻の設定も出ていないことを見る。
- **期待**:
   1. しきい値の選べる範囲と刻みが `SPEC-SET-002` と一致する。
   2. サブメニュー1回で項目を選べ、トップレベルにチェック用の余白がない。項目名はバッテリー残量の条件であることと、オンでもオフでも保存した100%のしきい値を示す。チェックと設定画面は同じオン・オフを示し、電源アダプター接続中は残量で解除しないことがバッテリー残量の項目の副題に出る。
   3. オフにすると保存値とチェックがオフになり、状態のバッテリーの行がなくなる。自分で解除するまで続くことの表示は残る。電源アダプターを外しても抑止が続き、オンに戻すと保存値とチェックがオンになって、その場で解除される。残量を減らすために待つ必要はない。
   4. 電源アダプターの設定がオフならバッテリー残量の項目の副題がなく、オンに戻すと表示される。メニューで切り替えられる範囲は `SPEC-MENU-008` と一致する。
- **中止**: 設定とチェックが食い違う、オフでも解除される、オンに戻しても解除されない場合。電源を外す直前に残量が前提の範囲外になっていたら外さず中止する。想定外の権限要求や発熱、電源をつなぎ直せない場合も止める。
- **復元**: 電源アダプターをつなぎ、抑止が残っていればメニューで解除する。停止中に、バッテリー残量の条件・しきい値・電源アダプターの設定を控えた開始値に戻す。タイマー・指定時刻・LED・ヘルパーを使う設定と電源接続も開始前に戻す。
- **記録**: 残量と電源接続の前後、しきい値の範囲と刻み、サブメニューを開いた回数、トップレベルの左の余白、項目名・副題・チェック、設定画面との一致、状態のバッテリーの行、オンに戻した直後の解除、復元した値。

**結果欄**: 成功／失敗／判定不能: ____。時間の置き換え・設定の保存値・ヘルパーの確認・バッテリー残量の項目: ____。未実施項目と理由・気づいたこと: ____。

### 8.8 英語と日本語の表示と時刻の表記を確認する

- **目的**: `SPEC-UI-011`、`SPEC-UI-012`。
- **前提**: オーナーがシステム設定を操作する。停止中で、ヘルパーを使う設定・LED・時間とバッテリーの解除条件はオフ、HUD はオンにする。アプリ設定の開始値を `B` の結果用メモに控える。起動には `/usr/bin/open "$APP"`、終了にはメニューを使い、表示は画面の操作と目視で確かめる。
- **操作**:
   1. システム設定の「一般」→「言語と地域」で地域の開始値を、「一般」→「日付と時刻」で「24時間表示」の開始値を `B` に記録する。「アプリケーション」に Capsaicin の言語の指定があればその値を、なければ指定がないことを記録する。
   2. メニューで Capsaicin を終了する。「アプリケーション」で Capsaicin の項目を編集し、言語を English にする。項目がなければ「＋」から検証中の Debug アプリを選んで追加する。「一般」→「日付と時刻」で「24時間表示」をオフにし、Finder からそのアプリを起動する。
   3. メニューとサブメニュー、設定の6セクションと (i) を開いて読む。時間の入力パネルで1時間30分を入力し、確定したらオフになる時刻を控えて開始し、HUD とメニューの残り時間を見る。解除して時刻の入力パネルを開き、午後の時刻を指定して開始し、HUD とメニューの解除の時刻を見る。見終わったら解除する。設置確認のアラートは8.6の3と同じ条件で開き、必ず取り消す。安全に開けなければ、アラートだけ判定不能として記録する。
   4. メニューで Capsaicin を終了し、「日付と時刻」で「24時間表示」をオンにする。English のまま `/usr/bin/open "$APP"` でアプリを起動し直し、3を繰り返す。
   5. メニューで Capsaicin を終了し、「アプリケーション」の Capsaicin の言語を日本語にする。時刻の24時間表示はオンのまま `/usr/bin/open "$APP"` で起動し直し、3を繰り返す。
- **期待**:
   1. 言語の指定の有無、地域、時刻の24時間表示の開始値が記録される。
   2. アプリが英語で表示される。
   3. メニュー、入力パネル、HUD、設定画面、開けたアラートが英語で表示される。入力する時刻と、確定したらオフになる時刻、メニューと HUD の解除の時刻が OS の地域に合った12時間制で表示され、午前・午後を区別できる。期間は英語の時間と分の単位で表示される。アプリ名とコマンドの書式は変わらない。
   4. 画面と期間は英語のまま、入力パネル、メニュー、HUD の時刻が OS の地域に合った24時間制になる。
   5. 画面と期間が日本語になり、時刻は OS の地域に合った24時間制になる。
- **中止**: Debug アプリを識別できない、開始前の設定が分からない、言語や時刻の設定を元に戻せない場合。ヘルパーの登録やシステム設定での許可には進まない。
- **復元**: パネルを Esc で閉じ、メニューで解除してアプリを終了する。「一般」→「言語と地域」→「アプリケーション」で Capsaicin の言語を記録した開始値に戻す。開始時に指定がなかった場合は、今回追加した Capsaicin の項目だけを「−」で削除する。「日付と時刻」の「24時間表示」を開始値に戻し、地域が開始値のままであることを確かめる。`/usr/bin/open "$APP"` でアプリを起動し直し、試したアプリ設定も開始値に戻す。
- **記録**: 3つの組み合わせでの表示言語、入力パネル・メニュー・HUD の時刻、期間の単位、アラートの確認の可否、画面写真の絶対パス、言語と時刻の設定を戻したこと。

**結果欄**: 成功／失敗／判定不能: ____。英語・12時間制、英語・24時間制、日本語・24時間制の結果: ____。未実施項目と理由・復元した値: ____。

## 9. 今回の変更を片付け、開始前の状態へ戻す

この節は、2〜8節をどこまで進めたかにかかわらず必ず通る。動的確認を始めていなければ 9.1 の1で抜け、9.4 へ進む。始めていれば、9.1 から順に戻す。

### 9.1 抑止と今回設置したヘルパーを解除する

- **目的**: `SPEC-BLK-007`、`SPEC-HLP-004`、`SPEC-HLP-005`、`SPEC-LCY-002`。
- **前提**: `B` と開始前の記録が読める。既存ヘルパーのある環境では動的確認を開始していない。
- **操作**:
  1. 動的確認を始めなかった場合は、変更した OS 設定だけを写真に合わせて戻し、9.4へ進む。以降の削除コマンドを実行しない。
  2. 4.4などでアプリを起動せず復旧するよう指定された場合は、先に4の緊急復旧を行う。アプリが停止していれば `/usr/bin/open "$APP"` で起動し、メニューで抑止を解除する。起動できなければ片付けを止め、PM に渡す。`B/helper-created` があり、今回のヘルパーが有効または許可待ちなら「ヘルパー」の削除を承認する。未インストールになったことと BTM の Capsaicin の項目を確認する。自分の `disablesleep` を戻せず削除に失敗したときは、登録を残したまま4の復旧を行い、戻せた後で削除をやり直す。

     ```sh
     /usr/bin/sfltool dumpbtm
     ```

  3. 「一般」でログイン起動をオフにし、システム設定の「ログイン時に開く」から外れたことを見る。アプリのメニューから終了し、Capsaicin のアサーションとプロセスがなく、LED が通常連動に戻ったことを確かめる。

     ```sh
     /usr/bin/pmset -g assertions
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     ```

  4. 緊急復旧: 外部値の試験や失敗で `SleepDisabled` が残った場合、開始値を読み直して戻す。

     ```sh
     case "$(cat "${B:?}/sleep-disabled.before.txt")" in
       0) /usr/bin/sudo /usr/bin/pmset -a disablesleep 0 ;;
       1) /usr/bin/sudo /usr/bin/pmset -a disablesleep 1 ;;
       *) printf '%s\n' '中止: 開始値が不明。pmset を変更しない' ;;
     esac
     /usr/bin/pmset -g
     ```

- **期待**: 開始時の `SleepDisabled` と一致し、今回のヘルパーが未インストールで、ログイン時の起動もオフである。ad-hoc 署名の確認だけを行った場合は、「このビルドでは使用不可」で登録していない状態でよい。バックグラウンドの一覧の項目が残っていても、この段階では失敗としない。開始値が `1` の場合には動的確認を始めていないため、本来ここで変更は不要である。
- **中止**: 登録を外せない、`SleepDisabled` が戻らない、LED が通常連動に戻らない場合。登録・アプリ・記録・設定を残して PM へ渡す。値を戻す手段が残るように、アプリの削除へ進まない。
- **復元**: LED は承認済みの独立復旧手順を使う。ヘルパーの登録を手作業で消す操作は本手順に含めない。今回の状態・エラー・残留値を PM に渡し、個別の復旧手順を決める。
- **記録**: ヘルパーの状態、ログイン起動と BTM の項目、`SleepDisabled` の開始値と現在値、アサーションの有無、LED の戻り。

### 9.2 今回のアプリと設定・記録を取り除く

- **目的**: `SPEC-LCY-005`、`SPEC-LCY-007`、`SPEC-SET-002`。
- **前提**: アプリが停止し、ヘルパー・LED・抑止を戻せている。mainApp の登録を外している。開始時に既存の登録はなく、`APP` と4.8でゴミ箱に移したアプリを今回のものと識別できる。`trash` が使える。
- **操作**:
  1. 試験後の設定と再開用の記録を保存する。

     ```sh
     if [ -f "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/resume-record.after.json"; fi
     /usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.after.plist"
     ```

  2. Finder で `APP` の今回のアプリをゴミ箱に移す。agent の登録はアプリの削除により片付ける。4.8の古いビルドも含め、今回使ったアプリがゴミ箱に残っているとシステム設定の項目が消えないことがある（`EVID-LCY-003`）。**ゴミ箱を空にすると、中身は元に戻せない。** 既存のゴミ箱の中身を保存し、オーナーが空にしてよいと判断した場合だけ Finder から空にする。空にできなければ削除の確認は未完了として、残っているアプリの所在を PM に渡す。
  3. **以下は今回の設定と再開用の記録を消す。退避物が読めることを先に確かめ、失敗したら実行しない。**

     ```sh
     if [ -f "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then trash "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
     /usr/bin/defaults delete io.github.koutyuke.capsaicin.debug
     ```

- **期待**: 今回のアプリがなくなり、agent のジョブとシステム設定の Capsaicin の項目が消える。今回の再開記録・Debug 設定が消える。ドメインが既にない旨だけなら `defaults delete` の失敗は削除済みとして記録する。
- **中止**: プロセスやヘルパーの登録が残る、退避が失敗する、パスが想定と違う場合。Release のアプリ・ドメインや IPC の共有ディレクトリには触れない。
- **復元**: 開始前のデータは9.3で戻す。再開記録を含む Application Support ディレクトリ全体や、デーモンの起動の記録は削除しない。システム設定の項目を消すための `sfltool resetbtm` は、ほかのアプリの登録も消すので使わない。
- **記録**: 削除したアプリの絶対パス、ゴミ箱を空にしたかと残したもの、設定・記録の退避先、`defaults delete` の終了値、9.4での登録の読み取り結果。

### 9.3 既存のデータと OS 設定を戻す

- **目的**: `SPEC-SET-002`、`SPEC-LCY-007` の開始前のデータを失わず復元する。
- **前提**: 9.2が完了している。復元後はアプリを起動しない。古い抑止セッションを再開させないため、開始時に停止済み・所有なしと確認した記録だけを戻す。
- **操作**:
  1. 開始前に存在したデータだけを戻す。

     ```sh
     if [ -f "$B/defaults.before.plist" ]; then /usr/bin/defaults import io.github.koutyuke.capsaicin.debug "$B/defaults.before.plist"; fi
     if [ -f "$B/resume-record.before.json" ]; then cp -p "$B/resume-record.before.json" "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
     ```

  2. 復元したファイルを `cmp` で比較する。

     ```sh
     if [ -f "$B/resume-record.before.json" ]; then cmp "$B/resume-record.before.json" "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"; fi
     /usr/bin/defaults read io.github.koutyuke.capsaicin.debug
     ```

  3. 初めから存在しなかった対象は、`record.absent`、`defaults.absent` に照らし、存在しないことを確かめる。設定があった場合は `defaults.before.txt` と読み戻しを比較する。
  4. OS の外観、アクセントカラー、文字、VoiceOver、アクセシビリティ、バックグラウンド項目、機器接続を開始前の写真と一致させる。変更していない項目は触れない。
- **期待**: `cmp` は出力なしで終了値 `0`。設定の内容が開始前と一致する。開始時に登録はなかったので、SMAppService の登録を作り直さない。
- **中止**: 退避物が壊れている、ファイルが再作成される、OS の開始値が不明な場合。
- **復元**: データを追加削除せず、開始前・試験後の両方を PM に渡す。
- **記録**: `cmp` の結果、`defaults` の読み戻し、`absent` マーカーとの照合、OS 設定を戻した項目。

### 9.4 残留と結果を確認して PM に渡す

- **目的**: `SPEC-HLP-005`、`SPEC-LCY-002` の復元と、全節の判定を完了する。
- **前提**: 1.4で起動前に止めたか、9.1〜9.3を完了した。
- **操作**:
  1. 次の結果とシステム設定の一覧を開始前と比較する。開始前からある他アプリのアサーションを消さない。起動前に止めた場合は、1節で判明した既存の登録が変わっていないことを確認する。

     ```sh
     /usr/bin/pmset -g
     /usr/bin/pmset -g assertions
     /bin/launchctl print "gui/$(id -u)/io.github.koutyuke.capsaicin.debug"
     /bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
     /usr/bin/sfltool dumpbtm
     ```

  2. 節末の結果欄ごとに、実行日・環境・成功／失敗／判定不能・観測値・画像やログの絶対パス・復元結果を記入する。
  3. PM に結果と `B` の所在を渡す。新しい根拠 ID の採番と仮説の更新は PM に任せ、この手順の実行だけで仮説を確認済みにしない。
- **期待**: スリープ・設定・登録が開始前に戻り、未実施を成功扱いしていない。今回の agent とデーモンの照会はサービスなしになる。1.4で止めた場合は「動的確認は未実施」と分かる。デーモンの起動の記録は仕様どおり残るため、残留として記録するが、削除の失敗には数えない。
- **中止**: 復元が1つでも未完了なら「検証完了」とせず、残留対象・開始値・現在値を PM に報告する。
- **復元**: `B` は結果と復元材料なので PM の受領・復元確認まで残す。受領後、オーナーが保存不要と判断した場合だけ、その絶対パスを確かめて `trash "${B:?}"` を実行する。`rm`、Git の変更、Release データの削除は行わない。
- **記録**: 全節の結果欄を埋め、未実施の項目とその理由を一覧にする。復元した対象、残留した対象、`B` の絶対パスを1か所にまとめる。

**結果欄**: 成功／失敗／判定不能: ____。復元した対象・残留対象・PMへの受け渡し: ____。未実施項目と理由・気づいたこと: ____。

## 付録 A. つまずいたときの切り分け

状態が期待から外れたときは、次の順で見る。当てはまらないときは、そのまま中止して記録する。

| 症状 | まず確かめること |
| --- | --- |
| プロセスが0本、または2本以上 | 0節の `launchctl print` と `ps` で agent の PID とアプリのパスを読み直す。5秒待って再確認 |
| agent の登録や起動が失敗する | 「一般」の警告、システム設定の許可、BTM の Capsaicin の項目、LaunchAgent のログ。手作業の登録で回避しない |
| ログイン時に起動しない | 「ログイン時に起動する」、mainApp の登録と「ログイン時に開く」の一覧、バックグラウンドの許可 |
| ヘルパーが許可待ちになる | システム設定で Capsaicin の項目を許可する。agent も同じ項目なので両方の状態を確認 |
| ヘルパーがこのビルドでは使用不可になる | ad-hoc 署名では使えない。1.4の署名付きの PR Debug ビルドを使う |
| `SleepDisabled` が戻らない | 9.1の緊急復旧。戻らなければ 9.4 で報告 |
| LED が通常連動に戻らない | 承認済みの独立復旧手順。読み戻し値で合格にしない |
| 設定画面の警告行が消えない | アプリを終了して `open` で起動し直す。それでも消えなければ 2.3 で止める |

## 付録 B. 結果のまとめ方

節末の結果欄は、次の形で埋めると読み手が追いやすい。空欄を残したまま次へ進まない。

```text
成功／失敗／判定不能: 成功（2.2-4のクラッシュ再起動まで）
観測値: kickstart→pid 2345、SEGV→pid 2456（runs 2、last exit code -11）
      再ログイン後 state=not running、pid なし
復元: SleepDisabled 0、ヘルパー未インストール、ログイン起動オフ、アプリと登録の削除を確認、LED 通常連動
未実施と理由: HYP-LCY-003 は経路別の環境記録機能がないため判定不能
気づいたこと: 2.2-3 のログイン後は loaded/not running で期待どおり
写真・ログ: /Users/<user>/Capsaicin-verification.ab12cd/general-warning.png
```

この手順自体を直すときは、実測と食い違った箇所を先に記録する。期待値を実測に合わせて書き換えるのではなく、製品が違うのか手順が違うのかを PM が判断してから直す。
