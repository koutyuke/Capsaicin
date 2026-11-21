# ヘルパーの設置と許可の入口

設定の「ヘルパー」から設置し、登録とシステム設定を開く操作が分かれていることを確かめる。「スリープ」の選択肢と案内を、登録前、許可前、許可後で比べる。確かめる仕様は `SPEC-HLP-001`、`SPEC-HLP-006`、`SPEC-SET-005` である。

最初の1回の準備は [`prepare.md`](prepare.md)、最後の片付けは [`cleanup.md`](cleanup.md) で行う。それ以外の検証ファイルの操作には依存しない。所要時間は未実測である。

## 始める前に

- オーナーが、ヘルパーの登録・削除とシステム設定の Capsaicin の許可の変更を承認している。未保存の作業を保存する。
- `prepare.md` を終え、`B` の絶対パスを控えている。署名・公証済みの PR Debug ビルド（`S-Preview`）を `/Applications` に置いている。ad-hoc 署名の `just build` では行わない。
- 過去に同じビルドのヘルパーを許可したことのある Mac では、登録の直後に承認待ちを経ずに「有効」になることがある（`EVID-HLP-006`）。その場合は操作4の期待どおりに分岐する。過去の許可の記録は消さない。
- `SleepDisabled = 0` で、抑止は開始しない。Release は起動しない。

リポジトリのルートで devShell に入り、退避先と対象を確かめる。`OK` が出なければ止める。

```sh
cd <リポジトリのルート>
nix develop
B='控えた退避先の絶対パスに置き換える'
test "$(cat "$B/repository-path.txt")" = "$PWD" && echo OK
```

`OK` が出たら、対象のアプリを開く。

```sh
APP="$(cat "$B/app-path.txt")"
printf 'APP=%s\n' "$APP"
/usr/bin/open "$APP"
sleep 5
just status
/usr/bin/pmset -g
/usr/bin/sfltool dumpbtm
```

`just status` に出る実行ファイルが `$APP/Contents/MacOS/Capsaicin` の1つだけであることと、`SleepDisabled = 0` を確かめる。設定の「ヘルパー」の「状態」が「未インストール」であることと、「スリープ」の「ディスプレイを閉じたとき」が「Macをスリープ（標準）」であることを確かめる。MacBook 以外の Mac では「Appleメニューからのスリープも防ぐ」がオフであることを確かめる。開始時の状態・設定値・システム設定の許可を `"$B/result-helper-approval-guidance.txt"` に控える。前提と異なるときは、設置済みのヘルパーを取り除いたり設定を変えたりせず、判定不能にする。

システム設定の「一般 > ログイン項目と機能拡張」とバックグラウンドの一覧の項目名は実装にないため、検証時の画面で照合する。BTM の Debug の識別子と `$APP` のパスで対象を見分け、Release や別アプリと区別できなければ変更しない。

保存値の開始点を読む。`capsaicin.settings` は JSON を入れた Data なので、plist をバイト列から読み、その中の JSON を開く。`{}` はまだ保存がなく、既定値を使う状態である。コマンドは読むだけで、設定を書き換えない。

```sh
/usr/bin/defaults export io.github.koutyuke.capsaicin.debug - | python3 -c 'import json, plistlib, sys; print(json.dumps(json.loads(plistlib.loads(sys.stdin.buffer.read()).get("capsaicin.settings", b"{}")), ensure_ascii=False, indent=2))'
```

`blocksManualSleep` が `false`（未保存なら既定値）であることを確かめ、`lidCloseDisplay` とともに結果に控える。システム設定は終了しておく。

## 操作と期待

1. 「スリープ」を開く。「ディスプレイを閉じたとき」のポップアップを開き、「オンのまま」を選ぼうとする。MacBook 以外の Mac では「Appleメニューからのスリープも防ぐ」をオンにしようとする。

   期待: 「Macをスリープ（標準）」以外の選択肢はグレーで選べず、アラートは出ない。項目名の下に「ヘルパーのインストールが必要です。」と「ヘルパーの設定…」が出る。MacBook 以外の Mac ではスイッチが無効で、同じ文とリンクが出る。

2. ポップアップを開いている場合は Esc で閉じる。説明文の末尾にある「ヘルパーの設定…」を押す。

   期待: リンクを押すと「ヘルパー」セクションに切り替わる。

3. 「ヘルパー」で「インストール…」を選び、設置の確認を見る。

   期待: 設定ウインドウのシートとして開き、注意の記号がなく、既定のボタンが「インストール」、もう一方が「キャンセル」である。本文は、スリープを切り替えるだけの小さなプログラムを root で動かして Mac の起動時に元へ戻すことと、設定の「ヘルパー」から削除できることを2文以内で伝える。システム設定が開くことは予告しない。

4. シートで「インストール」を押し、システム設定が開かないことを確かめる。

   期待: 「インストール」の後はシステム設定が開かず、状態の行に許可の手順が出る。「状態」は「システム設定の許可待ち」になり、管理の行に「システム設定を開く」が出る。今回登録したことを結果に控える。

   「状態」がすぐ「有効」になった場合は、過去の許可が残っている。システム設定が開かなかったことと「有効」になったことを結果に控え、操作5〜7を判定不能として操作8へ進む。

5. 「スリープ」へ戻って項目の表示を見て、保存値を読む。

   ```sh
   /usr/bin/defaults export io.github.koutyuke.capsaicin.debug - | python3 -c 'import json, plistlib, sys; print(json.dumps(json.loads(plistlib.loads(sys.stdin.buffer.read()).get("capsaicin.settings", b"{}")), ensure_ascii=False, indent=2))'
   ```

   期待: 「Macをスリープ（標準）」以外の選択肢はグレーで選べない。MacBook 以外の Mac ではスイッチが無効である。承認待ちでも同じ文とリンクが出る。保存値は変わらない。

6. 設定の「ヘルパー」で「システム設定を開く」を押す。

   期待: 「システム設定を開く」でシステム設定の「ログイン項目と機能拡張」が開く。

7. 開いた画面で Capsaicin のバックグラウンドの項目を許可する。識別できない項目は変更せず中止する。アプリの設定ウインドウに戻り、「ヘルパー」と「スリープ」を見て保存値を読む。

   ```sh
   /usr/bin/defaults export io.github.koutyuke.capsaicin.debug - | python3 -c 'import json, plistlib, sys; print(json.dumps(json.loads(plistlib.loads(sys.stdin.buffer.read()).get("capsaicin.settings", b"{}")), ensure_ascii=False, indent=2))'
   /usr/bin/pmset -g
   /usr/bin/sfltool dumpbtm
   ```

   期待: 許可した後は「ヘルパー」の状態が「有効」になり、「ディスプレイを閉じたとき」の保存値は「Macをスリープ（標準）」のままで、ほかの選択肢を選べるようになる。MacBook 以外の Mac では「Appleメニューからのスリープも防ぐ」がオフのまま操作できるようになる。「ヘルパーのインストールが必要です。」と「ヘルパーの設定…」は消える。`blocksManualSleep` と `lidCloseDisplay` は開始点から変わらず、`SleepDisabled = 0` のままである。

8. 許可を外したときの表示を確認する。「ディスプレイを閉じたとき」で「オンのまま」を選ぶ。MacBook 以外の Mac では「Appleメニューからのスリープも防ぐ」をオンにする。システム設定の「ログイン項目と機能拡張」で、識別済みの Capsaicin の項目をオフにして「スリープ」に戻る。

   - MacBook の期待: ポップアップは「オンのまま」を表示し、開いて「Macをスリープ（標準）」を選べる。ほかの選択肢はグレーで選べない。アイコンが注意の記号に置き換わり、項目名の下に「ヘルパーが有効になっていないため、設定を反映できません。」と「ヘルパーの設定…」が出て、「ヘルパーのインストールが必要です。」は出ない。確認したら「Macをスリープ（標準）」を選ぶ。
   - MacBook 以外の Mac の期待: スイッチはオンのまま表示され、オフにできる。アイコンが注意の記号に置き換わり、項目名の下の説明文の先頭に「ヘルパーが有効になっていないため、設定を反映できません。」が出て、説明文の末尾に「ヘルパーの設定…」が出る。オフにすると注意が消え、スイッチは無効になり、説明文の先頭に「ヘルパーのインストールが必要です。」が出る。

## 中止するとき

対象を識別できない、登録後の状態が期待と異なる、またはアプリが終了した場合は止める。設置の確認が開いたままなら「キャンセル」で閉じる。登録や許可を追加で操作せず、抑止は開始しない。状態を保存する。

```sh
/usr/bin/pmset -g
/usr/bin/sfltool dumpbtm > "$B/btm.approval-aborted.txt"
/usr/bin/defaults export io.github.koutyuke.capsaicin.debug "$B/defaults.approval-aborted.plist"
```

今回の登録を特定できる場合だけ、次の復元に進む。特定できない場合はアプリ・登録・記録を残して PM に渡す。

## 元に戻す

今回登録したヘルパーを削除する。アプリが停止していれば同じビルドを開く。

```sh
/usr/bin/open "$APP"
```

今回登録した場合だけ、「ヘルパー」の「削除…」と確認の「削除」を押す。「状態」が「未インストール」に戻り、「ディスプレイを閉じたとき」が「Macをスリープ（標準）」、MacBook 以外の Mac では「Appleメニューからのスリープも防ぐ」がオフに戻っていることを確かめる。削除できなければ手作業で登録やファイルを変更せず PM に渡す。実行前の設定の最終復元は `cleanup.md` で行う。システム設定が過去の許可の記録を残す場合は、消さずに記録する。

```sh
/usr/bin/pmset -g
/usr/bin/sfltool dumpbtm
```

## 記録

`"$B/result-helper-approval-guidance.txt"` に次を書く。

- PR・コミット・ビルド番号・アプリの絶対パス、許可を変更した項目の識別子とパス、開始時と復元後の許可
- 設置の確認のタイトル・本文・ボタン、システム設定が開いた操作、開いた画面の名前
- 登録前・許可前・許可後それぞれの選択肢やスイッチの操作可否、説明文とリンク、`blocksManualSleep`、`lidCloseDisplay`
- 許可を外した後の表示と戻す操作の結果、写真の絶対パス
- `SleepDisabled`、今回登録したヘルパーを削除したか、成功／失敗／判定不能、未実施の操作と理由
