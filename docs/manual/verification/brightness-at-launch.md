# 開き直す直前の輝度で、記録をどう使うか確かめる

MacBook の「ディスプレイを閉じたとき」が「明るさを0」のとき、暗くなった状態でアプリを強制終了させる。手で起動する直前の輝度が `0` の場合と、記録と異なる `0` より大きい値の場合を分けて確かめる（`SPEC-BLK-013`、`SPEC-LCY-006`）。所要時間は未実測である。

```text
[閉じて輝度 0・記録あり] → [アプリを強制終了] → [手動起動]
                                             ├─ 起動直前 0: 元の輝度に戻し、記録を消す
                                             └─ 起動直前 0 以外: 輝度を変えず、記録だけ消す
```

## 始める前に

- オーナーが `prepare.md` の起動前ゲートを通し、接続保持と単一インスタンスを含む、Developer ID で署名し直した手元のビルドか署名・公証済みの PR Debug ビルドを `APP` に選んでいる。
- ヘルパーの登録と許可、対象アプリの強制終了、復旧時の `sudo pmset` を承認している。未保存の作業は保存する。
- MacBook を電源につなぎ、外部ディスプレイを外して机上に置く。閉じた状態でかばんに入れない。画面が暗くなっても使える、輝度を上げるキーを確認しておく。
- システム設定の「ディスプレイ」で輝度と「輝度を自動調節」の開始値を控える。macOS の項目名は検証時の画面で照合する。キーと輝度のスライダーの両方を操作できない場合は始めない。

リポジトリのルートで `nix develop` を実行する。devShell の中で退避先と対象を読む。

```sh
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
APP="$(cat "$B/app-path.txt")"
printf 'APP=%s\n' "$APP"
/usr/bin/pmset -g
/usr/bin/pgrep -x Capsaicin
/bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
```

`OK`、準備で選んだ `APP`、`SleepDisabled 0`、アプリの PID なし、デーモンのサービスなしを確かめる。違えば起動しない。

開始前の Debug の設定を退避する。退避に失敗したら起動しない。

```sh
/usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.brightness.before.plist" &&
/usr/bin/plutil -lint "$B/defaults.brightness.before.plist"
```

システム設定の「輝度を自動調節」をオフにする。輝度が実際に `0` かどうかは目視や記録だけでは決められない。アプリと同じ `DisplayServicesGetBrightness` で内蔵ディスプレイを読む計測プログラムを `B` に作る。このプログラムは輝度を書き換えない。

```sh
cat > "$B/read-brightness.swift" <<'SWIFT'
import CoreGraphics
import Darwin

typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
var count: UInt32 = 0
guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { exit(1) }
var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
guard CGGetOnlineDisplayList(count, &displays, &count) == .success,
      let display = displays.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 }),
      let library = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
      let symbol = dlsym(library, "DisplayServicesGetBrightness") else { exit(1) }
let get = unsafeBitCast(symbol, to: GetBrightness.self)
var value: Float = 0
guard get(display, &value) == 0, (0...1).contains(value) else { exit(1) }
print(value == 0 ? 0 : value)
SWIFT
/usr/bin/xcrun swiftc "$B/read-brightness.swift" -o "$B/read-brightness"
"$B/read-brightness" | /usr/bin/tee "$B/brightness.preparation.txt"
```

`0` から `1` の間の値が1行出ることを確認する。値を読めなければ判定不能とし、強制終了は行わず、自動調節を開始値へ戻す。

```sh
/usr/bin/open "$APP"
just status
```

`$APP/Contents/MacOS/Capsaicin` のプロセスだけが動いていることを確かめ、メニューの「設定…」を開く。アイコンが見えない場合は `/usr/bin/open "$APP"` でもう一度開き、「一般」の「メニューバーにアイコンを表示」をオンにする。

- 「一般」の「ログイン時に起動」をオフにする。
- 「スリープ」の「タイマー」「指定時刻」「残量が少なくなったらオフにする」をオフ、「ディスプレイを自動でオフにしない」をオンにする。「LED」の「スリープ防止中にCaps LockのLEDを点灯」はオフにする。
- 「ヘルパー」の「状態」が「未インストール」であることを確かめ、「インストール…」と確認の「インストール」を押す。許可待ちなら「システム設定を開く」から「一般 > ログイン項目と機能拡張」を開く。

```sh
/usr/bin/sfltool dumpbtm > "$B/btm.brightness.txt"
```

許可するときは、BTM の記録の Debug の識別子と `APP` のパスを照合し、対象のバックグラウンドの項目だけを変更する。対象を識別できなければ変更しない。「状態」が「有効」になったら、「スリープ」の「ディスプレイを閉じたとき」を「明るさを0」にする。「このMacでは画面の明るさを変更できないため、ディスプレイを閉じても画面はオンのままになります。」が表示されたら試行しない。

「Capsaicinを終了」で終了する。ディスプレイを開いた状態で、試行前にアプリが止まり、輝度の記録が存在しないことを確かめる。`ls` の権限エラーは「存在しない」とみなさない。

```sh
just status
/bin/ls -ld "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"
```

保存失敗の警告は実機では扱わない。既存データを保護しながら保存失敗を起こすため、`SPEC-BLK-013` の単体テストでは輝度の記録先をテスト用の実装に差し替えている（`ControllerBrightnessTests.swift`）。

## 操作と期待

次の一連の操作を、利用者が明るくした場合、起動直前を `0` にした場合の順に行う。コマンド中の `TRIAL` は、1 回目は `changed`、2 回目は `zero` にすべて置き換える。各試行で新しい記録を作り、ファイルを共用しない。

1. ディスプレイを開いたまま、内蔵ディスプレイを `0` より大きい普段の輝度にする。値を読み、対象を開く。

   ```sh
   "$B/read-brightness" > "$B/brightness.TRIAL.before-close.txt"
   cat "$B/brightness.TRIAL.before-close.txt"
   /usr/bin/open "$APP"
   just status
   ```

   アプリの PID を控え、メニューの「スリープ防止をオンにする」を選ぶ。

   ```sh
   /usr/bin/pmset -g
   ```

   期待: 対象アプリ1本だけが動き、`SleepDisabled 1` になる。初めの輝度が `0` または不明なら先へ進まない。

2. `APP_PID` を今回控えたアプリの PID に置き換える。次を前景で実行し、20 秒以内にディスプレイを閉じる。途中で止める場合は閉じずに Control-C を押す。このコマンドは、閉じた状態、計測値 `0.0`、退避した `savedBrightness`、アプリの実行ファイルがそろう場合だけアプリを強制終了する。

   ```sh
   (
     /bin/sleep 20 &&
     /usr/sbin/ioreg -r -k AppleClamshellState > "$B/lid.TRIAL.txt" &&
     /usr/bin/grep -q '"AppleClamshellState" = Yes' "$B/lid.TRIAL.txt" &&
     "$B/read-brightness" > "$B/brightness.TRIAL.closed.txt" &&
     /usr/bin/grep -qx '0\.0' "$B/brightness.TRIAL.closed.txt" &&
     test ! -L "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" &&
     cp -p "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" "$B/record.TRIAL.json" &&
     python3 -c 'import json,sys; v=json.load(open(sys.argv[1]))["savedBrightness"]; sys.exit(0 if type(v) in (float,int) and 0 < v <= 1 else 1)' "$B/record.TRIAL.json" &&
     /usr/sbin/lsof -a -p APP_PID -d txt -Fn | /usr/bin/grep -Fx "n$APP/Contents/MacOS/Capsaicin" &&
     /bin/date '+%Y-%m-%dT%H:%M:%S%z' &&
     /bin/kill -9 APP_PID
   ) > "$B/close.TRIAL.txt" 2>&1
   ```

   30 秒たってから開く。画面の暗さ自体と輝度の計測値は区別する。コマンドが終了したことを確かめ、アプリを起動せずに読む。

   ```sh
   cat "$B/close.TRIAL.txt"
   /usr/bin/pgrep -x Capsaicin
   /usr/bin/pmset -g
   "$B/read-brightness" > "$B/brightness.TRIAL.reopened.txt"
   cmp "$B/record.TRIAL.json" "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"
   ```

   期待: アプリは動いておらず、`SleepDisabled 0` で、記録が残っている。コマンドが失敗してアプリが残った場合はやり直さず中止する。内蔵ディスプレイを閉じた状態で輝度を読めなかった場合は、暗くした状態を判定不能とする。

3. 起動直前の輝度を作る。`zero` では、開いたときに OS が輝度を上げていたら輝度を下げるキーで `0` にする。`changed` では、上げるキーで記録した値と見分けられる `0` より大きい値にする。目視ではなく、次の出力を確認する。

   ```sh
   "$B/read-brightness" > "$B/brightness.TRIAL.before-open.txt"
   cat "$B/brightness.TRIAL.before-open.txt"
   /usr/bin/plutil -p "$B/record.TRIAL.json"
   ```

   試行の条件がそろったら、輝度を動かさず手でアプリを開く。`0` にできない、暗くて起動操作ができない、または開く操作で輝度が変わる場合は `zero` を判定不能とする。その場合はキーで明るくして復元へ進み、復元のための起動を試行に数えない。

   ```sh
   /usr/bin/open "$APP"
   /bin/sleep 5
   "$B/read-brightness" > "$B/brightness.TRIAL.after-open.txt"
   cat "$B/brightness.TRIAL.after-open.txt"
   /bin/ls -ld "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"
   just status
   ```

   期待: `zero` の起動後は `savedBrightness` の値になり、`changed` の起動後は起動直前の値のままである。両方とも `resume-record.json` がなく、メニューに「スリープ防止をオンにする」が出る。ファイルが消えただけで合格にしない。比較には `B` の計測値と退避した `savedBrightness` を使う。

4. 「Capsaicinを終了」で終了する。

   ```sh
   just status
   /usr/bin/pmset -g
   /bin/ls -ld "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json"
   ```

   `No Debug processes.`、`SleepDisabled 0`、輝度の記録なしの場合だけ次の試行に進む。前の試行の記録は流用しない。

## 中止するとき

対象・PID・輝度を識別できない場合や、想定外にアプリが起動した場合は止める。強制終了コマンドが前景で待機中なら Control-C で止め、完了を確かめてから画面を開く。画面が暗ければキーかシステム設定の輝度のスライダーで戻す。

対象アプリが動いていて「スリープ防止をオフにする」が出ていれば選び、`/usr/bin/pmset -g` で値を読む。今回立てた `1` が残っていると確かめた場合だけ、承認済みの復旧操作を行う。値が不明なときは変更しない。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g
```

`0` に戻らない、または輝度を操作できないときは、アプリ・記録・登録を残して PM に渡す。輝度の診断には次のログを残す。

```sh
/usr/bin/log show --last 15m --style compact --predicate 'subsystem == "io.github.koutyuke.capsaicin" AND (category == "Brightness" OR category == "BrightnessRecordStore")' > "$B/log.brightness.txt"
```

## 元に戻す

ディスプレイを開いて画面を読める状態にし、`SleepDisabled 0` と、別のコピーが動いていないことを確かめる。対象アプリが停止していれば開く。再試行のための起動とは区別する。

```sh
/usr/bin/pmset -g
/usr/bin/open "$APP"
just status
```

「ヘルパー」で今回登録したものだけを「削除…」と確認の「削除」で外す。「状態」が「未インストール」になったら「Capsaicinを終了」で終了する。システム設定の輝度と「輝度を自動調節」、外部ディスプレイの接続を開始前に戻す。

```sh
just status
/usr/bin/pmset -g
/bin/launchctl print system/io.github.koutyuke.capsaicin.debug.helper
```

`No Debug processes.`、`SleepDisabled 0`、デーモンのサービスなしを確かめる。そろった場合だけ停止したまま設定を戻す。

```sh
/usr/bin/defaults import io.github.koutyuke.capsaicin.debug "$B/defaults.brightness.before.plist"
```

準備で退避した記録とアプリの片付けは最後の `cleanup.md` で行う。値・登録・輝度を戻せない場合は、アプリを捨てずに PM に相談する。

## 記録

`"$B/result-brightness-at-launch.txt"` に、ビルド・署名・環境、MacBook と電源・ディスプレイの構成、試行別の PID と時刻、閉じる前・閉じている間・開けた直後・起動直前と直後の輝度、`savedBrightness`、記録が消えたか、抑止と復元の結果を書く。判定不能の場合は測れなかった区間を区別し、生の計測ファイルとログの絶対パスを残す。
