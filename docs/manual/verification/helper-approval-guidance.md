# 承認待ちで設定を選んだときの案内

ヘルパーの承認待ちに設定を選ぶと許可を案内するアラートが出て、取り消すと保存値に戻り、許可すると行の注意が消えることを確かめる。確かめる仕様は `SPEC-HLP-001`、`SPEC-HLP-006`、`SPEC-SET-003`、`SPEC-SET-005` である。設置と承認自体は `EVID-HLP-006` で確認済みなので、このファイルでは案内と表示・保存値を判定する。

最初の1回の準備は [`prepare.md`](prepare.md)、最後の片付けは [`cleanup.md`](cleanup.md) で行う。それ以外の検証ファイルの操作には依存しない。所要時間は未実測である。

## 始める前に

- オーナーが、ヘルパーの登録とシステム設定の Capsaicin の許可の変更を承認している。許可を外すとヘルパーが使えなくなる。未保存の作業を保存する。
- `prepare.md` を終え、`B` の絶対パスを控えている。署名・公証済みの PR Debug ビルド（`S-Preview`）を `/Applications` に置いている。ad-hoc 署名の `just build` では行わない。
- `SleepDisabled = 0` で、抑止は開始しない。Release は起動しない。

リポジトリのルートで devShell に入り、退避先と対象を確かめる。`OK` が出なければ止める。

```sh
cd <リポジトリのルート>
nix develop
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
APP="$(cat "$B/app-path.txt")"
printf 'APP=%s\n' "$APP"
/usr/bin/open "$APP"
sleep 5
/usr/bin/pmset -g
/usr/bin/sfltool dumpbtm
```

「スリープ」の設定、「フィードバック」の「スリープ防止中にCaps LockのLEDを点灯」、ヘルパーの状態、システム設定の許可を `"$B/result-helper-approval-guidance.txt"` に控える。LED はオフにし、「ディスプレイを閉じたとき」を「Macをスリープ（標準）」、MacBook 以外の Mac では「Appleメニューからのスリープも防ぐ」をオフにする。

ヘルパーが「未インストール」なら、設定の「ヘルパー」で「インストール…」を選び、確認の「インストール」を押す。「許可待ち」か「有効」になったら、今回登録したことを結果に控える。許可待ちなら「システム設定を開く」から Capsaicin の項目を許可して「有効」にする。ヘルパーからの設置なのでスリープの保存値は変えない。「このビルドでは使用不可」やエラーなら始めない。

システム設定の「一般 > ログイン項目と機能拡張」とバックグラウンドの一覧の項目名は実装にないため、検証時の画面で照合する。BTM の Debug の識別子と `$APP` のパスで対象を見分け、Release や別アプリと区別できなければ変更しない。

保存値の開始点を読む。`capsaicin.settings` は JSON を入れた Data なので、plist をバイト列から読み、その中の JSON を開く。`{}` はまだ保存がなく、既定値を使う状態である。コマンドは読むだけで、設定を書き換えない。

```sh
/usr/bin/defaults export io.github.koutyuke.capsaicin.debug - | python3 -c 'import json, plistlib, sys; print(json.dumps(json.loads(plistlib.loads(sys.stdin.buffer.read()).get("capsaicin.settings", b"{}")), ensure_ascii=False, indent=2))'
```

`blocksManualSleep` が `false` であることを確認し、`lidCloseDisplay` とともに結果に控える。

## 操作と期待

1. システム設定の「一般 > ログイン項目と機能拡張」で、識別済みの Capsaicin のバックグラウンドの項目をオフにする。アプリが終了したら、想定外の結果として中止し、記録する。

   ```sh
   /usr/bin/open "$APP"
   sleep 3
   /usr/bin/sfltool dumpbtm
   /usr/bin/pmset -g
   ```

   設定の「ヘルパー」が「許可待ち」であることを確かめる。抑止は開始しない。システム設定のウインドウを閉じてから、アプリの「スリープ」を開く。

2. 「ディスプレイを閉じたとき」で「オンのまま」を選ぶ。MacBook 以外の Mac では「Appleメニューからのスリープも防ぐ」をオンにする。

   期待: 設定ウインドウのシートに次の内容が出る。アプリアイコンを使い、注意の記号は使わない。

   | 部分 | 表示 |
   | --- | --- |
   | タイトル | この設定を使うには、システム設定でヘルパーの許可が必要です |
   | 本文 | システム設定の「一般 > ログイン項目と機能拡張」でCapsaicinの項目を許可すると、選んだ設定が有効になります。 |
   | 既定のボタン | システム設定を開く |
   | もう一方のボタン | キャンセル |

3. 「キャンセル」を押し、保存値を読む。

   ```sh
   /usr/bin/defaults export io.github.koutyuke.capsaicin.debug - | python3 -c 'import json, plistlib, sys; print(json.dumps(json.loads(plistlib.loads(sys.stdin.buffer.read()).get("capsaicin.settings", b"{}")), ensure_ascii=False, indent=2))'
   ```

   期待: システム設定は開かず、選択は「Macをスリープ（標準）」、MacBook 以外の Mac ではオフに戻る。`blocksManualSleep` と `lidCloseDisplay` は開始点のままである。ヘルパーの承認待ちは残るが、設定の行にはヘルパーに関する注意の記号と注意の文はない。

4. 「オンのまま」を選び直す。MacBook 以外の Mac では「Appleメニューからのスリープも防ぐ」をオンにする。アラートで「システム設定を開く」を押す。開いたシステム設定ではまだ許可せず、アプリの設定ウインドウに戻る。設定ウインドウは閉じない。

   ```sh
   /usr/bin/defaults export io.github.koutyuke.capsaicin.debug - | python3 -c 'import json, plistlib, sys; print(json.dumps(json.loads(plistlib.loads(sys.stdin.buffer.read()).get("capsaicin.settings", b"{}")), ensure_ascii=False, indent=2))'
   ```

   期待: シートが閉じてからシステム設定の「ログイン項目と機能拡張」が開く。選んだ「オンのまま」（MacBook 以外の Mac ではオン）が表示され、行のアイコンが注意の記号になる。項目名の下の説明文の先頭に「ヘルパーが有効になっていないため、設定を反映できません。」が出る。保存値は開始点のままである。

5. システム設定で識別済みの Capsaicin の項目を許可し、アプリの設定ウインドウに戻る。前面に戻ったときと、開いている間の2秒ごとの読み直しの結果を観察する。

   ```sh
   /usr/bin/defaults export io.github.koutyuke.capsaicin.debug - | python3 -c 'import json, plistlib, sys; print(json.dumps(json.loads(plistlib.loads(sys.stdin.buffer.read()).get("capsaicin.settings", b"{}")), ensure_ascii=False, indent=2))'
   /usr/bin/pmset -g
   /usr/bin/sfltool dumpbtm
   ```

   期待: ヘルパーは「有効」、設定は「オンのまま」（MacBook 以外の Mac ではオン）で、注意の記号と注意の文が消える。MacBook 以外の Mac では、通常の説明文だけが残る。`blocksManualSleep` は `true`、MacBook では `lidCloseDisplay` が `keepOn` として保存される。抑止を開始していないので `SleepDisabled = 0` のままである。

## 中止するとき

対象を識別できない、アラートが出ない、取り消しても保存値が変わる、許可前に保存される、許可後も注意が消えない場合は止める。開いているアラートは「キャンセル」で閉じる。変更した Capsaicin の許可だけを開始時のオンへ戻し、抑止は開始しない。状態を保存する。

```sh
/usr/bin/pmset -g
/usr/bin/sfltool dumpbtm > "$B/btm.approval-aborted.txt"
/usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.approval-aborted.plist"
```

許可を戻せないときはアプリ・登録・記録を残して PM に渡す。ファイルの削除や手作業の登録で回避しない。

## 元に戻す

変更した Capsaicin の許可を開始時のオンへ戻す。アプリが停止していれば起動する。

```sh
/usr/bin/open "$APP"
```

このファイルでヘルパーを登録した場合は、「ヘルパー」の「削除…」と確認の「削除」を押し、「未インストール」に戻ったことを確かめる。「スリープ」と LED の値を控えた値へ戻し、状態を読む。アプリと登録の片付けは `cleanup.md` で行う。

```sh
/usr/bin/pmset -g
/usr/bin/sfltool dumpbtm
```

## 記録

`"$B/result-helper-approval-guidance.txt"` に次を書く。

- PR・コミット・ビルド番号・アプリの絶対パス、許可を変更した項目の識別子とパス、開始時と復元後の許可
- アラートのタイトル・本文・ボタン、キャンセルでシステム設定が開かなかったこと、開く操作の結果
- キャンセル後・許可前・許可後それぞれの選択肢、`blocksManualSleep`、`lidCloseDisplay`
- 注意の記号と注意の文の前後、許可後に消えるまでの時間、写真の絶対パス
- `SleepDisabled`、今回登録したヘルパーを削除したか、成功／失敗／判定不能、未実施の操作と理由
