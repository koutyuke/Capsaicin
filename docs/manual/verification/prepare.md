# 準備: 開始前の状態を保存する

ほかの検証ファイルを始める前に、最初の1回だけ行う。開始前の状態を退避先 `B` に保存し、起動前ゲートを通る。ここを通せない環境では、ほかの検証ファイルを実施しない。`SPEC-LCY-006`、`SPEC-LCY-009`、`SPEC-BLK-013`、`SPEC-HLP-005`、`SPEC-SET-002`、`SPEC-LED-001` の確認で既存の環境を失わないようにする。

`resume-record.json` は、アプリが暗くする前の輝度を `savedBrightness` に保存する記録である。開始前に存在すればファイルごと退避し、最後に戻す。起動時の扱いは `SPEC-LCY-006` と `SPEC-BLK-013` に従う。

操作1〜3で状態を読んで退避し、操作4で検証対象のアプリを用意して起動前の準備を終える。全体の所要時間は未実測である。

## 始める前に

- 実行者はオーナーである（`DEC-SYS-027`）。Apple Silicon、macOS 26 以上、Xcode 27.2、flakes が有効な Nix を用意する。`sudo pmset` を使う検証では、その操作の承認と管理者認証も用意する。
- 未保存の作業を保存する。
- `command -v trash` で `trash` が使えることを確かめる。なければ始めず PM に相談する。

## 操作と期待

### 1. 実行者と検証環境を固定する

1. Release と Debug の Capsaicin が両方とも停止している検証用 Mac を使う。既存のアプリが動作中なら終了させず中止する。検証中に Release を起動しない。
2. ターミナルでリポジトリのルートを開き、devShell に入る。以後のコマンドはこのシェルで実行する。

   ```sh
   cd <リポジトリのルート>
   nix develop
   ```

3. 環境を読む。

   ```sh
   /usr/bin/xcode-select -p
   /usr/bin/sw_vers
   /usr/bin/uname -m
   /usr/bin/pgrep -x Capsaicin
   ```

   期待: Developer ディレクトリが Xcode 内を指し、CPU は `arm64` である。最後の検索でアプリが見つからない。Xcode の選択は変更しない。

### 2. 退避先を作り、読み取り結果を残す

1. 所有者だけが読める退避先を作り、チェックアウトのパスを記録する。

   ```sh
   umask 077
   B="$(/usr/bin/mktemp -d "$HOME/Capsaicin-verification.XXXXXX")"
   printf '%s\n' "$B"
   printf '%s\n' "$PWD" > "$B/repository-path.txt"
   ```

2. 表示した `B` の絶対パスを、別のメモに保存する。各検証ファイルとログアウト・再起動の後は、このパスを `B='…'` で入れ直す。`mktemp` を再実行しない。
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
   printf '%s\n' "$?" > "$B/helper-print.exit.txt"
   /bin/launchctl print system/io.github.koutyuke.capsaicin.helper > "$B/release-helper.before.txt" 2>&1
   printf '%s\n' "$?" > "$B/release-helper-print.exit.txt"
   /usr/bin/sfltool dumpbtm > "$B/btm.before.txt"
   /bin/date '+%Y-%m-%dT%H:%M:%S%z' > "$B/date.before.txt"
   /usr/bin/awk '$1 == "SleepDisabled" {print $2}' "$B/pmset.before.txt" > "$B/sleep-disabled.before.txt"
   cat "$B/sleep-disabled.before.txt" "$B/agent-print.exit.txt" "$B/agent.before.txt"
   ```

   期待: `SleepDisabled` は1行の `0` または `1` である。Release・Debug の agent とデーモンの照会は、どれも「サービスが見つからない」旨で失敗する。システム設定の「一般 > ログイン項目と機能拡張」の「ログイン時に開く」とバックグラウンドの一覧、`btm.before.txt` に、使用中の Capsaicin の登録がない。macOS の項目名は実装にないため、検証時の画面で照合して表示名を記録する。

   `SleepDisabled` が欠落・重複・不明、いずれかのジョブが読み込み済み、ログイン時に開く登録がある場合は止める。バックグラウンドの登録を既存のものと区別できない場合も止め、既存の登録は外さない。権限不足を「存在しない」とみなさず、各照会の終了コードと本文の両方で判断する。BTM の `[disabled, allowed, …]` は過去の OS の記録として残ることがあるため、それだけで現在の登録や稼働を判断しない（`EVID-LCY-003`）。

   agent の照会は古い版の登録を見つけるために行う。Debug・Release のどちらかが見つかったら、起動も登録解除もせず、照会結果を添えて PM に相談する。

   開始値が `1` でも、ここでは下ろさない。その場合、`SleepDisabled = 0` を前提にする検証ファイルは実施しない。

### 3. 設定と輝度の記録を退避し、旧方式の残留を調べる

1. Debug の設定をドメイン全体で保存する。ホットキーの値もこの退避に含まれる。

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

   ドメインが存在しない旨だけが出た場合は、次を実行する。ほかのエラーなら止める。

   ```sh
   touch "$B/defaults.absent"
   ```

2. Debug の輝度の記録を、存在しなかったことも含めて保存する。

   ```sh
   if [ -L "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then
     printf '%s\n' '中止: 輝度の記録がシンボリックリンクである'
   elif [ -f "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then
     cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/resume-record.before.json"
   elif [ -e "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" ]; then
     printf '%s\n' '中止: 輝度の記録が通常のファイルではない'
   else
     touch "$B/record.absent"
   fi
   ```

3. 既存の記録があれば、元のファイルと一致することを確かめ、退避したファイルから `savedBrightness` だけを読む。

   ```sh
   cmp "$B/resume-record.before.json" "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"
   python3 - "$B/resume-record.before.json" <<'PY'
   import json
   import sys

   with open(sys.argv[1]) as file:
       value = json.load(file).get("savedBrightness")
   if value is not None and (type(value) not in (int, float) or not 0 <= value <= 1):
       sys.exit("中止: savedBrightness が不正")
   print(f"savedBrightness: {value}")
   PY
   ```

   `None` は輝度の値がないことを示す。`cmp` や読み取りが失敗したら、記録は消さず中止する。値がある場合は、起動で輝度を上書きしないよう、内蔵ディスプレイの輝度が 0 より上にあることを確かめる。下限にあるか確認できない場合は、輝度を変更せず PM に相談する。製品が起動時に記録を消しても、退避分は残る。

4. v0.1.0 の方式のファイルが残っていないか、Release・Debug 両方の名前を読む。見つかっても、この手順では移動・削除しない。

   ```sh
   /bin/ls -ld /Library/PrivilegedHelperTools/io.github.koutyuke.capsaicin.helper{,.debug}
   /bin/ls -ld /etc/sudoers.d/capsaicin{,_debug}
   /bin/ls -ld /Library/LaunchDaemons/io.github.koutyuke.capsaicin.helper{,.debug}.plist
   /bin/ls -ld "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.plist" "$HOME/Library/LaunchAgents/io.github.koutyuke.capsaicin.debug.plist"
   ```

   期待: 退避に成功し、旧方式の8ファイルはすべて存在しない。バンドル内の定義とは別の対象である。

   旧方式のファイルが1つでも存在する、アクセスが拒否される、退避に失敗する、既存の記録の意味を判断できない場合は止める。旧方式の片付けはリポジトリの外の専用手順書で済ませてから最初からやり直すか、残っていない別の検証用 Mac を PM と選ぶ。

### 4. アプリと署名を確かめ、起動前の準備を終える

1. 外観、アクセントカラー、アクセシビリティ、VoiceOver、バックグラウンド項目の開始値を画面写真で `B` に保存する。外付け機器の製品名と接続方式も記録する。
2. `/Applications` の PR ビルドを使うファイルでは、オーナーが `S-Preview` 付き PR のコメントから、対象コミットの署名・公証済み Debug ビルドを取得する（`DEC-SYS-023`）。展開して `/Applications/Capsaicin.app` に置く。既存のアプリには上書きしない。

   ```sh
   APP='/Applications/Capsaicin.app'
   printf '%s\n' "$APP" > "$B/app-path.txt"
   /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
   /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist"
   /usr/bin/codesign -dv --verbose=4 "$APP" 2>&1
   /usr/bin/codesign --verify --deep --strict "$APP"
   /bin/ls -l "$APP/Contents/Helpers/"
   /usr/bin/plutil -p "$APP/Contents/Library/LaunchDaemons/io.github.koutyuke.capsaicin.debug.helper.plist"
   ```

   期待: bundle ID が `io.github.koutyuke.capsaicin.debug`、埋め込んだ実行ファイルが `capsaicin` と `capsaicin-helper` である。署名検査に成功し、`TeamIdentifier` がある。デーモンは `BundleProgram = Contents/Helpers/capsaicin-helper`、`RunAtLoad = true`、`MachServices` のキーが `io.github.koutyuke.capsaicin.debug.helper` である。定義は `project.yml` のビルドフェーズが作る。

   手元のビルドを使う場合は、代わりに次を実行する。`just build` の後、`just sign-debug` で署名し直す（`DEC-SYS-027`）。オーナーのキーチェーンに Developer ID Application の証明書と鍵が必要である。

   `/Applications` の PR Debug ビルドと手元のビルドは bundle ID が同じで、どちらも `just status` と `just stop` の対象である。どちらかが動いていれば `just start` は起動しない。この手順の開始時に動作中のアプリがあった場合は、`just stop` で終了させず、操作1の条件どおり中止する。

   ```sh
   just build
   just sign-debug
   APP="$PWD/.build/xcode/Build/Products/Debug/Capsaicin.app"
   printf '%s\n' "$APP" > "$B/app-path.txt"
   /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
   /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist"
   /usr/bin/codesign -dv --verbose=4 "$APP" 2>&1
   /usr/bin/codesign --verify --strict --deep "$APP"
   /bin/ls -l "$APP/Contents/Helpers/"
   /usr/bin/plutil -p "$APP/Contents/Library/LaunchDaemons/io.github.koutyuke.capsaicin.debug.helper.plist"
   ```

   bundle ID が `io.github.koutyuke.capsaicin.debug`、実行ファイルが `capsaicin` と `capsaicin-helper` で、署名検査に成功し、最初の `Authority` が `Developer ID Application:` で始まり、`TeamIdentifier` が配布物と同じことを確かめる。デーモンの `BundleProgram` は `Contents/Helpers/capsaicin-helper`、`RunAtLoad` は `true`、`MachServices` のキーは `io.github.koutyuke.capsaicin.debug.helper` である。PR ビルドの取得元・署名を確かめられない、手元で同じ Team ID の署名を用意できない、既存アプリの上書きが要る場合は止める。

3. 結果用のメモ `"$B/result-prepare.txt"` を作り、実行日、macOS のビルド番号、Mac の機種、承認者を書く。認証情報や全プロセスの環境変数は保存しない。
4. LED が点いたまま残ったときの戻し方を確かめる。オーナーは 2026-11-18 に、次の順で戻すことを承認した。

   1. アプリを起動する。起動時の処理が、停止中のあるべき状態（`"Auto"`）に合わせる。
   2. 戻らなければ、アプリを終了してから `/usr/bin/hidutil property --matching keyboard --set '{"HIDCapsLockLED":"Auto"}'` で書く。
   3. それでも戻らなければ、Mac を再起動する。

   期待: オーナーがこの順を承認したことを `"$B/result-prepare.txt"` に書いた。

   設定の「LED」の「スリープ防止中にCaps LockのLEDを点灯」をオフにするだけでは、起動時の `"Auto"` 書き込みを防げない。既存の LED 上書きモードを保つ必要がある環境では止める。

準備ではアプリを起動しない。起動前ゲートを通り、操作4の結果を記録してから、選んだ確認へ進む。

## 中止するとき

アプリを起動せず、既存の登録とファイルは変えない。止めた操作と理由を `"$B/result-prepare.txt"` に書き、`B` と照会結果を PM に渡す。今回 `/Applications` に置いたアプリがあれば、その絶対パスも記録する。

## 元に戻す

準備では既存の登録とデータは変えていない。今回置いたアプリの片付けを含め、最後に `cleanup.md` を行う。`B` は片付けを終えるまで残す。

## 記録

`"$B/result-prepare.txt"` に次を書く。

- macOS の版とビルド番号、機種、`xcode-select -p` の出力
- `SleepDisabled` の開始値、4つの `launchctl print` の終了コードと本文、BTM とシステム設定の Capsaicin の項目、`date`
- `defaults` の終了コード、記録の有無と `savedBrightness`、`record.absent`・`defaults.absent` の有無、旧方式の8ファイルの有無
- PR とコミット、アプリの絶対パス、ビルド番号、bundle ID、署名の Team ID、埋め込んだ実行ファイルと定義、LED の戻し方の承認
- 成功／失敗／判定不能、未実施の操作と理由
