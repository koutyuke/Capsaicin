# アプリ内の更新を実機で確認して元に戻す手順

オーナーが承認済みの検証用 Mac で、使い捨ての鍵と Debug の2つの版を使い、更新と画面を確かめる手順である。アプリの入れ替え、ログアウト、Mac の再起動を行う。所要時間は未実測である。

アプリ・サーバーの起動と以下の動的確認は未検証である。期待は仕様と仮説を参照し、実測と区別する。エージェントが実行してよいのは補助スクリプトのビルドと appcast 生成だけで、`launchctl` はオーナーが手で実行する。

```text
[1. 退避・A/B と試験用 feed の作成] ──前提不足──▶ [中止・記録]
│
▼
[2. ブラウザ経由で A を入れる]
│
▼
[3〜6. 画面・拒否・手動／自動更新] ──異常──▶ [7. 復元・PMへ渡す]
│
▼
[7. 復元・結果をPMへ渡す]
```

各節は「目的 → 前提 → 操作 → 期待 → 中止 → 復元 → 記録」の順に読む。期待に仕様の本文を写さず、参照先の受け入れ例と照らす。前提不足は判定不能、復元に支障のある異常は中止とし、飛ばした試験を成功に数えない。写真とログは既存の退避先 `B` に置き、秘密鍵はコピーしない。

## 1. 開始前の状態と試験用の材料を用意する

- **目的**: `HYP-SYS-002`、`SPEC-SET-007` の試験を、本番の鍵・アプリを使わず復元可能にする。
- **前提**: [実機確認の手順](verification.md)の1.1〜1.4を実施する。環境、未読込の `.debug` ジョブ、Release の常駐処理がないこと、設定と再開記録の退避、LED の独立復旧手段のゲートを省かない。今回ヘルパーを設置しない。`SleepDisabled` の開始値は `0` とする。`trash` が必要である。
- **操作**:
  1. リポジトリのルートを同じ Bash で開き、既存の変数と退避先を再利用する。

     ```sh
     eval "$(scripts/manual/verify.sh env)"
     printf 'B=%s\nJOB=%s\n' "$B" "$JOB"
     ```

     `B` が空なら先へ進まない。開始時に既存の Debug ジョブが読み込まれていた場合も、本手順で外さず中止する。
  2. ビルドと署名用の材料を作る。`8123` はこの試験だけに使う、空いているポートである。

     ```sh
     scripts/manual/update-test.sh prepare 8123
     ```

     表示された `W='…'` を同じシェルで実行し、パスだけを退避する。

     ```sh
     printf '%s\n' "$W" > "$B/update-workspace.txt"
     scripts/manual/update-test.sh disabled "$W"
     UAPP="$HOME/Applications/Capsaicin-update-test/Capsaicin.app"
     ```

     `W` は `.build/tmp/update-test.XXXXXX` で、退避先 `B` とは別物である。A は `0.9.0 (100)`、更新先の B は `0.9.1 (101)` である。両方とも同じソース、配信 URL、公開鍵を使う。版とビルド番号だけを変え、DerivedData を分ける。作業中にソースを変更しない。
  3. 別のターミナルでリポジトリのルートを開き、同じ `W` を設定して配信する。

     ```sh
     scripts/manual/update-test.sh serve "$W"
     ```

     このターミナルは開いたままにする。止めるときは **Ctrl-C** を押し、プロンプトが戻ったことを確かめる。バックグラウンド化しない。
- **期待**: `HYP-SYS-002` の試験用に、A/B、署名付き feed、否定試験用のファイルができる。`prepare` 内の検査が成功し、サーバーは `127.0.0.1` だけで待ち受ける。更新無効の Debug は `build-disabled` にできる。
- **中止**: ビルド・チェックサム・署名検査の失敗、ポート使用中、作業中のソース変更。ビルドのログは `W/build-A.log` と `W/build-B.log`、appcast のログは `W/appcast-good.log` にある。seed の内容を開かず、公開用フォルダー以外を配信しない。
- **復元**: 起動前ならシステムの復元は不要である。失敗しても作業先に鍵が残るので、7節で片付ける。
- **記録**: `B`、`W` の絶対パス、ソースのコミットと未コミットの変更の有無、ポート、ビルド結果。鍵や環境変数の全体は採取しない。

### 補助スクリプトの操作

| コマンド | 操作 |
| --- | --- |
| `prepare [port] [local-ats]` | 一時フォルダーと32バイトの seed 2つを作り、CryptoKit で公開鍵を導く。固定版の Sparkle をチェックサムで照合し、A/B と feed を作る。初めは `current` を配信する |
| `disabled W` | 配信元・公開鍵を空にした Debug を別の DerivedData にビルドする |
| `feed W 種類` | 配信する feed と B の zip を切り替える。ダウンロード中には切り替えない |
| `serve W` | 公開用フォルダーだけを前面のプロセスで配信する。Ctrl-C で停止する |
| `clean W` | サーバーとアプリが停止していることを確かめ、seed を空にしてから作業先全体を `trash` へ移す。`B`、設定、LaunchAgent、インストール先には触れない |

鍵はログインキーチェーンを使わず、[リリースの鍵の手順](release.md)と同じ形式で作る。`project.yml` を書き換えず、`SPARKLE_FEED_URL` と `SPARKLE_PUBLIC_ED_KEY` を `xcodebuild` に渡す。Sparkle の版とチェックサムは `.github/build-tools.env` を使う。`generate_appcast` は release-appcast ジョブと同じく標準入力で鍵を受け取り、項目と feed の署名を検査する。通常の Xcode・SwiftPM・`generate_appcast` のキャッシュは片付け対象に含めない。

### HTTP が ATS に拒否された場合

`curl` で配信を読めても、アプリの ATS が許可したことにはならない。Sparkle のエラーと Console で `NSURLErrorDomain` の `-1022` など ATS の拒否を記録する。ネットワーク接続エラーだけで署名の否定試験を合格にしない。

macOS 26 でこのアプリが `http://127.0.0.1` を読み込めるかは未確認である。Apple の [NSAllowsLocalNetworking](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking) は、macOS 14 以降の IP アドレスへの例外を `NSExceptionDomains` に置く方法を示している。

ATS の拒否が確認された場合は、アプリを終了し、サーバーを Ctrl-C で止める。失敗時のログを `B` に保存してから、次で別の材料を作る。

```sh
scripts/manual/update-test.sh prepare 8123 local-ats
```

この引数は、一時フォルダーに複製した Info.plist に `NSAppTransportSecurity.NSExceptionDomains.127.0.0.1.NSExceptionAllowsInsecureHTTPLoads = true` を足し、`INFOPLIST_FILE` をビルドの引数で渡す。ソースと `project.yml` は変更しない。例外ありの実行時の有効性も未確認である。新しい `W` を記録し、`disabled` も作って、サーバーを起動し直す。2節の戻し方で A を入れ直す。例外が有効にならなければ、それ以上例外を広げず中止して PM に渡す。初めの `W` の鍵も7節で片付ける。

## 2. quarantine の付いた A を入れ、起動経路を確かめる

- **目的**: `HYP-SYS-002` の主張2・3の開始条件を作る。
- **前提**: 1節を完了し、`.debug` ジョブが未読込である。`~/Applications/Capsaicin-update-test` が存在しないことを Finder で確かめる。既存のフォルダーがあれば上書きせず中止する。
- **操作**:
  1. Safari で `http://127.0.0.1:8123/Capsaicin-A.zip` を開いてダウンロードする。ポートを変えた場合は URL も変える。ローカルの zip を直接コピーして代用しない。
  2. ダウンロードした zip を展開し、新しく作った `~/Applications/Capsaicin-update-test/` に `Capsaicin.app` を移す。自動展開された場合もダウンロード元を記録する。起動前に次を読む。

     ```sh
     /usr/bin/xattr -lr "$UAPP" > "$B/update-A-xattr.txt"
     /usr/bin/codesign -d -r- "$UAPP" 2> "$B/update-A-requirement.txt"
     /usr/bin/codesign -dv --verbose=4 "$UAPP" 2> "$B/update-A-signature.txt"
     ```

     `com.apple.quarantine` がない場合は初回配布の再現として判定不能にし、属性を手で付けたり外したりしない。
  3. 初回の値を測るため、退避した Debug 設定が読めることを確かめ、アプリが停止中のまま `defaults delete "$ID"` で今回使うドメインを空にする。ドメインなし以外のエラーなら中止する。Finder から A を開く。Gatekeeper に拒否されたらシステム設定の「プライバシーとセキュリティ」で、この A だけを「このまま開く」で許可する。一般の Gatekeeper 設定は変えない。後の試行ではこの削除を重ねず、「各試行で A に戻す方法」で指定する起動前の設定を使う。
  4. 5秒待ち、次の出力でジョブの PID と唯一のアプリの PID・パスを照らす。

     ```sh
     /bin/launchctl print "$JOB"
     /usr/bin/plutil -p "$PLIST"
     /bin/ps -axo pid,ppid,comm | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin'
     ```

     実行パスは `UAPP/Contents/MacOS/Capsaicin`、`ProgramArguments` もこのパスであることを見る。更新した後もこの3つを同じ方法で読む。
- **期待**: `HYP-SYS-002` の主張2・3の開始条件、`SPEC-LCY-005`。起動直後の引き渡しを終えた後の PID を記録する。
- **中止**: Release や別のビルドを起動した、パスが App Translocation 配下である、5秒後も複数動く、ジョブが既存の `.build/xcode` を指す場合。そのジョブを動かしたまま続けない。
- **復元**: 最後は7節へ進む。`verify.sh restart` は通常の Debug に戻すため、この更新試験では使わない。`verify.sh stop` と `status` も `.build/xcode` の固定パスを探すため、インストールした A/B の判定には使わない。
- **記録**: ブラウザと展開経路、quarantine の有無、「このまま開く」の操作、版、署名、PID、`ProgramArguments`、`KeepAlive`、`RunAtLoad`。

### 各試行で A に戻す方法

インストールを伴う試行は毎回 A から始める。前のインストールが完了し、抑止を解除した後、メニューから終了する。**インストール待ちのまま終了して A を上書きしない。** 終了時にも Sparkle がインストールする可能性があるため、待機中のままやエラー後に状態が分からないときは中止して PM に渡す。

1. 2節のプロセス一覧でアプリがなく、ジョブの実行中の PID もないことを確かめる。
2. オーナーが次で今回の `.debug` ジョブだけを外す。サービスなしの場合は `bootout` を省き、それ以外のエラーなら中止する。

   ```sh
   /bin/launchctl print "$JOB"
   /bin/launchctl bootout "$JOB"
   /bin/launchctl print "$JOB"
   ```

3. ジョブがサービスなしになったことを確かめる。今回作った `UAPP` だけを `trash "$UAPP"` へ移し、2節のブラウザのダウンロードから入れ直す。このとき、既に今回作った親フォルダーは再利用する。試験用フォルダー全体や既存のアプリは削除しない。まだ A を起動しない。
4. 既存設定の退避が読めることを再確認してから、今回の Debug 設定だけを消す。

   ```sh
   /usr/bin/defaults delete "$ID"
   scripts/manual/update-test.sh feed "$W" current
   ```

   ドメインが存在しない旨以外のエラーなら中止する。必要な試験設定は、起動前に各節の指示で入れる。再開記録は試行ごとには消さない。抑止中・所有中の記録が残ったら復旧が済むまで次へ進まない。

## 3. 「このアプリについて」の画面と設定を確認する

- **目的**: `SPEC-SET-004`、`SPEC-SET-007`、`SPEC-SET-008`。
- **前提**: A が起動済みで `current` を配信している。以下の画面項目は仕様と String Catalog の機能名で指す。外観、文字サイズ、時刻形式、VoiceOver の開始値を `B` に保存してある。
- **操作**:
  1. 初回に自動確認の許可画面が出るかと、ポップアップの初期値を記録する。「オフ」「確認のみ」「ダウンロードしてインストール」を順に選び、停止中に終了・再起動して選択を読み直す。`current` のままなので新版のインストールは起こらない。保存先を次で読み、Capsaicin の設定の保存値に混ざっていないことも見る。

     ```sh
     /usr/bin/defaults read "$ID" SUEnableAutomaticChecks
     /usr/bin/defaults read "$ID" SUAutomaticallyUpdate
     /usr/bin/defaults read "$ID" > "$B/update-defaults.txt"
     ```

  2. 未確認の状態を安定して観察するため、停止中に終了して次を実行し、Finder から A を開く。最後のキーが初めからなければ削除を省く。

     ```sh
     /usr/bin/defaults write "$ID" SUEnableAutomaticChecks -bool NO
     /usr/bin/defaults write "$ID" SUAutomaticallyUpdate -bool NO
     /usr/bin/defaults read "$ID" SULastCheckTime
     /usr/bin/defaults delete "$ID" SULastCheckTime
     /usr/bin/open "$UAPP"
     ```

     「このアプリについて」を撮る。ほかのアプリを前面にしてから手動確認し、確認中のボタン、Sparkle の結果画面、終了後の日時を観察する。OS の12時間制／24時間制を切り替えてページを開き直す。昨日・それ以前の日時は実際にその日に確認した記録で確かめ、なければその部分を判定不能とする。OS の日付は変えない。
  3. システム設定で文字を大きくして、このページを上端から下端までスクロールする。版とビルド番号をコピーし、`UAPP/Contents/Info.plist` と比較する。アイコン、カード、余白、終了ボタン、著作権を `SPEC-SET-004` と照らす。
  4. VoiceOver でアプリアイコンのラベル、アプリ名の見出し、状態の静的テキスト、確認ボタンを読む。(i) を Tab と Space で開く。「Web サイト」の読み上げとヒントを聞き、文字のない部分を押して既定のブラウザの URL を記録する。
  5. 「ライセンス」を開き、3部品の本文を下端までスクロールしてコピーする。バンドル内のライセンス全文と比較し、Sparkle の外部コードの条項も確認する。標準の戻る操作と、別のセクションへ移って戻る操作をそれぞれ試す。
  6. 「確認のみ」にして4節の方法で定期確認を起こす。新しい版の行とボタンの読み上げを記録する。Sparkle の画面の自動ダウンロードのチェックを切り替え、開いたままのポップアップとの連動を見る。インストールはまだ選ばない。逆方向も、ポップアップの選択を変えて Sparkle の画面を開き直し、チェックを読む。
  7. ダウンロード前に Sparkle の画面を閉じ、A を終了する。「確認をオフ、ダウンロードをオン」は次で用意してから起動し、ポップアップを読む。

     ```sh
     /usr/bin/defaults write "$ID" SUEnableAutomaticChecks -bool NO
     /usr/bin/defaults write "$ID" SUAutomaticallyUpdate -bool YES
     /usr/bin/open "$UAPP"
     ```
- **期待**: 各操作を `SPEC-SET-004`、`SPEC-SET-007`、`SPEC-SET-008` の該当する受け入れ例と照合する。4つ目のインストール待ちの状態は6節で確認する。状態切り替え時の行の高さ、右寄せ、読み上げの通知の有無も比較する。
- **中止**: 本番配信への接続、意図しないインストール、操作不能な項目。チェックボックスがない Sparkle の画面では連動を合格にせず、画面の種類を記録して PM に渡す。
- **復元**: ダウンロード前の Sparkle の画面を閉じ、「確認のみ」に戻す。OS の変更値は7節で開始値に戻す。
- **記録**: 受け入れ例ごとの結論、画面写真、コピーした版とライセンス、開いた URL、キー2つの値、未確認／今日確認済み／新版ありの表示。鍵を含む `W` 全体は保存しない。

## 4. 定期確認を待たずにメニューの知らせを出す

- **目的**: `SPEC-MENU-009`、`SPEC-SET-007`。
- **前提**: A でインストールを待つ版がなく、抑止を止めている。Sparkle の画面で「この版をスキップ」を選んでいない。
- **操作**:
  1. A の設定を「確認のみ」にして終了する。次で、停止している Debug の最終確認日時だけを消し、正しい feed へ切り替える。キーがなければ削除を省く。

     ```sh
     /usr/bin/defaults read "$ID" SULastCheckTime
     /usr/bin/defaults delete "$ID" SULastCheckTime
     scripts/manual/update-test.sh feed "$W" good
     /usr/bin/open "$UAPP"
     ```

  2. ほかのアプリを前面にして、サーバーに `GET /appcast.xml` が出るかを観察する。60秒を観測の上限とし、メニューと「このアプリについて」を開く。これは製品の保証時間ではない。手動確認ボタンで代用しない。
  3. 停止中と抑止中のメニューを撮る。警告のある状態は、既存の実機確認の2.3で安全に作れるときだけ試し、その復元も同節に従う。警告を安全に用意できなければ、警告との並びだけ判定不能とする。
  4. ほかのアプリを前面にしてメニューの更新項目を選び、その後メニューを開き直す。ダウンロード前に画面を閉じる。別の試行では一般設定でメニューバーのアイコンを隠して1からやり直し、「このアプリについて」を観察する。再提示には毎回1の操作を使う。
- **期待**: `SPEC-MENU-009` の知らせの位置、版、アイコン、画面を見た後の消失、アイコンを隠した場合の受け入れ例と照合する。ウインドウ・通知・フォーカスの変化も記録する。
- **中止**: 60秒で定期確認を観察できない、または手動確認と区別できない場合は、この方法を未確認として PM に渡す。署名・ATS のエラーを「新版なし」と混ぜない。
- **復元**: 抑止を解除し、メニューバーの表示を元に戻す。警告試験で変えたバックグラウンド項目も戻す。
- **記録**: 起動から GET までの時間、更新項目の出現時刻、画面写真、通知と前面化の有無。画面を見ずに更新の処理だけを終了させる受け入れ例は、そのための実機操作がないので判定不能とする。

この方法は Sparkle 2.10.1 の [SPUUpdater.h](https://github.com/sparkle-project/Sparkle/blob/2.10.1/Sparkle/SPUUpdater.h) の `SULastCheckTime` の試験用説明と、[SPUUpdater.m](https://github.com/sparkle-project/Sparkle/blob/2.10.1/Sparkle/SPUUpdater.m) の期限超過ならバックグラウンド確認する処理による。実機での成立は未確認である。[SPUUpdaterSettings.m](https://github.com/sparkle-project/Sparkle/blob/2.10.1/Sparkle/SPUUpdaterSettings.m) の最短間隔は通常1時間で、`-SUScheduledCheckInterval 5` では5秒ごとにならない。Finder 起動の引数も launchd への引き渡しで保持されるとは限らないため、永続設定を退避したうえで最終日時を消す。

## 5. 不正な更新を拒否し、正しい更新だけを受け入れる

- **目的**: `HYP-SYS-002` の主張1〜4、`SPEC-SET-007`、`SPEC-LCY-008`。
- **前提**: A を入れ直して起動し、自動アップデートを「オフ」にする。抑止を停止する。各試行はダウンロードが動いていないときに feed を切り替える。
- **操作**:
  1. 次の種類を1つずつ配信し、手動確認からインストールまで進める。エラーが出たら、その内容と段階を撮って閉じ、A のままであることを確かめる。

     ```sh
     scripts/manual/update-test.sh feed "$W" tampered
     ```

     | 種類 | 与える不正と観測する段階 |
     | --- | --- |
     | `tampered` | 署名付きの正しい feed と、同じ長さで1バイトだけ違う zip。ダウンロード後の署名拒否を見る |
     | `wrong-key` | 別の鍵で zip を署名し、feed 自体は A の鍵で署名し直す。zip の署名拒否を見る |
     | `wrong-feed` | 正しい zip を示す feed 自体を別の鍵で署名する。feed の拒否を見る |
     | `unsigned` | 正しい zip の署名は残し、feed の末尾の署名ブロックだけを外す。feed の拒否を見る |

     各試行の後にジョブ、PID、版を2節と同じ方法で採取する。HTTP の取得失敗ではなく署名の拒否と分かる記録が必要である。区別できなければ判定不能にする。
  2. `good` を配信し、停止中に手動でインストールする。終了の直前から完了まで Console でアプリと Sparkle の該当区間を保存し、2節の照会をインストール中と完了後に行う。新しい PID が実行した版も画面で見る。権限や Gatekeeper の追加操作を求められたら承認せず記録する。
  3. 更新後に次を実行し、`com.apple.quarantine`、署名、版を記録する。

     ```sh
     /usr/bin/xattr -lr "$UAPP" > "$B/update-B-xattr.txt"
     /usr/bin/codesign --verify --deep --strict "$UAPP"
     /usr/bin/codesign -d -r- "$UAPP" 2> "$B/update-B-requirement.txt"
     /usr/bin/plutil -p "$UAPP/Contents/Info.plist" > "$B/update-B-info.txt"
     ```

     バンドル内の Sparkle.framework と、その中の `Autoupdate`・`Updater.app` についても `codesign -dv --verbose=4` で署名と TeamIdentifier を保存する。実際のパスは Finder でバンドルを開いて選び、別のコピーを測らない。
  4. ログイン起動をオンにして、Apple メニューから Mac を再起動する。ログイン後は変数を次で戻す。アプリを手で開く前に、2節の照会と画面の版を確認する。

     ```sh
     eval "$(scripts/manual/verify.sh env)"
     W="$(cat "$B/update-workspace.txt")"
     UAPP="$HOME/Applications/Capsaicin-update-test/Capsaicin.app"
     ```

     ログイン項目とバックグラウンド項目の写真を開始前と比較する。別の試行では A に戻し、既存の実機確認の2.3で Debug のバックグラウンド項目を無効にしてから手動更新し、更新直後と再起動・ログイン後の無効状態と項目数を比較する。無効状態でアプリが自動起動しない場合は、その状態を保持した結果として記録し、起動を強制しない。
- **期待**: 否定の4試行は `HYP-SYS-002` の主張1、正しい更新とログイン後は同仮説の主張2〜4および `SPEC-LCY-008` の停止中の手動インストールの受け入れ例と照合する。版は `0.9.1 (101)` を測る。
- **中止**: 不正な更新が入る、追加の許可を求める、重複起動や項目の重複、無効状態の変化。短い間隔の照会で旧版の再起動の有無を捉えられなければ、その部分を未確認とし、「観測しなかった」を「起きなかった」にしない。
- **復元**: オン／オフを試したバックグラウンド項目は開始値へ戻す。次の試行には2節の戻し方を使い、終了時は7節へ進む。
- **記録**: 種類ごとの URL、拒否の段階と文言、A/B の版・署名・quarantine、PID とジョブ、インストール中の観測、再起動後の版、項目数と無効状態。成功・失敗・判定不能を主張ごとに付ける。

## 6. 抑止と設定ウインドウが終わるまでインストールを待つ

- **目的**: `SPEC-LCY-008`、`SPEC-SET-007`、`HYP-SYS-002` の主張5。
- **前提**: 各試行の前に2節の方法で A に戻す。電源を接続し、ヘルパーを要しない抑止の設定を使う。解除条件の開始値を記録する。
- **操作**:
  1. A を起動する前に自動確認をオフにし、最終確認日時を消す。キーがなければ削除を省く。

     ```sh
     /usr/bin/defaults write "$ID" SUEnableAutomaticChecks -bool NO
     /usr/bin/defaults write "$ID" SUAutomaticallyUpdate -bool NO
     /usr/bin/defaults read "$ID" SULastCheckTime
     /usr/bin/defaults delete "$ID" SULastCheckTime
     scripts/manual/update-test.sh feed "$W" good
     /usr/bin/open "$UAPP"
     ```

     抑止を開始して設定ウインドウを開き、「ダウンロードしてインストール」を選ぶ。4節と同じく定期確認を待つ。60秒以内に確認が始まらなければ判定不能とする。待っている版の表示でダウンロード完了を判定し、GET だけで完了とみなさない。
  2. 待っている版の画面と無効なボタン、版と操作の VoiceOver を採取する。抑止を解除しても設定ウインドウは開いたままにし、30秒観察する。その後閉じ、手で終了せず更新後を確認する。
  3. 別の A で、1と同じく抑止中かつ設定ウインドウを開いて待つ版を用意し、先に設定ウインドウだけを閉じる。30秒観察した後メニューで抑止を解除し、更新後を確認する。この試行で抑止だけが待つ条件の場合も確認する。
  4. 別の A で自動を「オフ」にする。タイマーを1時間、再開を「アプリと Mac の再起動時」にし、抑止を開始する。手動確認とダウンロードの前後で、メニューの解除予定時刻と次の出力を保存する。

     ```sh
     /usr/bin/pmset -g assertions | /usr/bin/grep -i capsaicin
     /usr/bin/plutil -p "$RECORD"
     ```

     手動インストールで抑止を解除する確認を一度取り消し、同じ内容を採取する。待つ版の表示を確認し、抑止を解除して設定ウインドウを閉じる。
  5. 別の A で4と同じ抑止・再開設定を使い、今度は確認で続行する。終了直前と更新後の再開記録、アサーション、LED、メニューを採取する。「このアプリについて」からの終了ボタンも、更新試行が完了した後に操作して、メニューの終了との後片付けを比べる。
- **期待**: `SPEC-LCY-008` の抑止中・設定ウインドウ・両条件の順序・取り消し・続行の受け入れ例と、`SPEC-SET-007` のインストール待ちの状態を照合する。確認とダウンロードだけの段階も照合する。30秒は待機を観察するための区間で、無期限に待つことの証明には使わない。
- **中止**: 解除前の無断終了、解除条件の変化、片方の条件が残る間のインストール、更新後の意図しない再開、LED・アサーションの残留。既知の制約である待機中のクラッシュ試験は行わない。
- **復元**: 取り消した版も後で入るため、解除・設定ウインドウの終了・更新完了を待ち、停止中を確かめてから次の A へ戻す。残留時は既存の実機確認の9.1と承認済みの LED 復旧手順を使い、記録を消さず PM に渡す。
- **記録**: 条件を変えた順序と時刻、待つ版の画面、確認の文言、解除予定時刻の前後、PID・版・再開記録・アサーション・LED。Sparkle の終了理由を直接記録する機能はないので、主張5は停止とセッションの消失による間接確認であり、理由の分類自体は判定不能と明記する。同じソースの A/B では保存形式の変更の互換性も判定しない。

## 7. 更新無効の Debug を確認し、開始前へ戻す

- **目的**: `SPEC-SET-007` の Debug の受け入れ例と、`SPEC-LCY-002`、`SPEC-LCY-007` の復元。
- **前提**: 更新を完了し、抑止を解除できている。`B` の開始前の退避物が読める。起動前に中止した場合は1・2を省き、サーバーと作業先の片付けだけを行う。
- **操作**:
  1. A/B を終了し、2節のプロセスとジョブの照会で実行終了を確認する。A に戻す方法と同じく、今回の `.debug` ジョブだけをオーナーが外す。今回の `UAPP` を `trash` へ移し、次で更新無効のビルドを同じ場所へコピーして Finder から開く。

     ```sh
     /usr/bin/ditto "$W/build-disabled/Build/Products/Debug/Capsaicin.app" "$UAPP"
     /usr/bin/open "$UAPP"
     ```

     更新の2行の操作と表示を調べ、サーバーにアプリからの新たな GET がないかを見る。既存の保存値があっても同じ無効表示かを記録する。
  2. メニューから終了する。以後は [実機確認の手順の9節](verification.md#9-今回の変更を片付け開始前の状態へ戻す)を使い、抑止・LED、今回の LaunchAgent、設定・再開記録、OS の変更値を順に戻す。同節の `APP` の照会先だけは `APP="$UAPP"` とする。`verify.sh env` を再実行したら、この上書きもやり直す。読み込み済みの既存ジョブを開始時に外していないため、復元した plist を `bootstrap` しない。
  3. サーバーのターミナルで Ctrl-C を押す。ログと写真、判定を `B` に保存し、鍵のない記録だけを PM に渡せることを確かめる。`W` から保存するのはビルド・appcast のログと公開 feed までにし、`keys` は保存しない。
  4. ジョブが未読込でプロセスがないことを確認して、今回の `UAPP`、ブラウザで落とした試験の zip と展開物だけを `trash` に移す。その後、次を実行する。

     ```sh
     scripts/manual/update-test.sh clean "$W"
     ```

     `local-ats` で作り直した場合は、初めの作業先にも `clean` を実行する。seed は空になってからゴミ箱へ移るが、媒体上の安全な消去は保証しない。`B` は PM の受領と復元確認まで残す。
- **期待**: 無効の画面は `SPEC-SET-007` の Debug の受け入れ例と照合する。復元は既存の9節の期待と開始前の記録で判定する。
- **中止**: インストール待ち、残留する抑止・プロセス・ジョブ、退避物の不足。`clean` が拒否したら強制削除せず、対象と出力を PM に渡す。
- **復元**: 既存の9節に従う。今回作ったフォルダーでも、残ったファイルの用途が不明なら消さない。Release のドメインや共用ディレクトリには触れない。
- **記録**: 更新無効の画面、GET の有無、復元した設定・plist・再開記録、消した試験用のパス、鍵を片付けたこと、残留対象。

## 結果を PM に渡す

各節の操作番号と、参照先の受け入れ例または仮説の主張番号ごとに、次を `B` のメモに残す。

```text
成功／失敗／判定不能:
試行の条件: A/B、feed の種類、ATS 例外の有無、自動アップデート、抑止・設定ウインドウ
観測値: 拒否の段階、版、PID、ジョブ、quarantine、画面の状態
写真・ログの絶対パス:
復元した対象／残留した対象:
未実施・直接確認できなかった項目と理由:
```

動的確認を行わなかった場合は、その旨を明記する。仮説の状態や根拠 ID はこの手順だけで変更せず、PM に判断を渡す。
