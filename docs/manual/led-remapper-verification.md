# キー配列を変えるアプリと Caps Lock の LED の干渉を確かめる手順

Capsaicin の LED の制御が、キー配列を変えるアプリとどの条件で干渉し、何が起きるかを確かめる手順である。Karabiner-Elements を代表例にするが、目的はアプリ名に頼らない解決方法を選ぶことにある。どの方式のアプリが干渉しうるか、その状態を汎用に見分けられるか、Capsaicin が書く対象を汎用に決められるかを確かめる。

手順は2つに分かれる。A はエージェントが読み取りだけで行う調査で、作業は `TASK-049` にある。B はオーナーが実機で行う検証で、エージェントは実行しない。B は A を待たずに始めてよい。B で LED への書き込みと Caps Lock の操作をするのはオーナーだけである。

## 確かめる問い

| 問い | 仮説 | 調査 | 実機 |
| --- | --- | --- | --- |
| どの方式のアプリが LED を書き換えうるか | `HYP-LED-002`、`HYP-LED-009` | A1 | B3、B4 |
| Capsaicin の書き込みが、アプリの入力の扱いを変えるか | `HYP-LED-006` | A1 | B3 |
| 干渉しうる状態（キーボードの占有）をアプリ名に頼らず検出できるか | `HYP-LED-008` | A3 | B3 |
| 書く対象を、実機のキーボードに汎用の属性で絞れるか | `HYP-LED-007`、`HYP-LED-010` | A2 | B1 |
| 抑止中に増えた・作り直されたキーボードに書けるか | `HYP-LED-005` | A4 | B2 |
| 外付けキーボードで LED が光るか | `HYP-LED-003` | なし | B1 |

すでに分かっている事実は `EVID-LED-005`（ログで見た書き込みの取りこぼし）と `EVID-LED-006`（IORegistry で読める印）にある。

## A. 調査（エージェント）

読み取りだけで行う。LED への書き込み、Caps Lock の操作、アプリの起動、Karabiner-Elements の操作はしない。参照したソースはコミット、ファイル、行で示す。確かめた事実は根拠の下書きにし、ID は PM が振る。

- **A1 方式の分類**: 主なキー配列の変更の仕組みを、方式で分ける。占有と仮想キーボード、イベントタップ、OS の割り当て（`UserKeyMapping`、修飾キーの設定）、機器のファームウェアや専用ソフトである。対象は Karabiner-Elements、Kanata、Raycast の Hyper Key、Keyboard Maestro、BetterTouchTool、Hammerspoon、Logi Options+、Razer Synapse、システム設定の修飾キー、`hidutil` などとする。アプリごとに、占有するか、仮想キーボードを作るか、LED に書くか、Caps Lock の状態をどこから得るかを、公式の資料とソースで示す。
- **A2 実機と仮想の区別**: IOHIDFamily と DriverKit（HIDDriverKit）のソースで、仮想デバイスに付く属性と、実機のバスに付く属性を確かめる。`IOHIDUserDevice` と DriverKit の仮想デバイスの両方を対象にする。`HYP-LED-007` の条件で足りるか、もっと確かな属性があるかを答える。
- **A3 占有の検出**: `IOHIDLibUserClient` の `DebugState` の各値の意味と、過去の版の IOHIDFamily での変遷を確かめる。占有を示す公開のキーや API がほかにあるか、その権限の要否も調べる。
- **A4 一覧の追従**: Passive のクライアントの `IOHIDEventSystemClientCopyServices` が、作成後のサービスの増減を反映する条件を、公開ヘッダーと公開ソースで確かめる。run loop やキューへの登録、追加・削除の通知の API を含む。本体が非公開で確かめられない場合は、その旨を書く。

## B. 実機検証（オーナー）

### 機材と呼び名

| 呼び名 | 機材 | 接続 |
| --- | --- | --- |
| 内蔵 | この MacBook の内蔵キーボード | なし |
| Lofree-USB、Lofree-BT、Lofree-2.4G | Lofree Flow Lite（Caps Lock の LED あり） | 有線、Bluetooth、2.4 GHz |
| Viper-USB、Viper-2.4G | Viper V2 Pro（マウス、Caps Lock の LED なし） | 有線、2.4 GHz |
| KE | Karabiner-Elements | 起動・終了、デバイスごとの設定 |

外付けの機器は、指定がない限り1台ずつ接続する。

### B0 毎回の準備

Capsaicin は、リポジトリのルートで `scripts/manual/verify.sh restart` を実行して起動する（止めてからビルドし、Finder と同じ経路で起動する）。手順の中の「Capsaicin を起動し直す」もこのコマンドで行い、「Capsaicin を終了する」は `scripts/manual/verify.sh stop` で行う。`verify.sh env` は変数 `B` を上書きするので、この手順の記録先は `LC` に置く。

ターミナルで次を貼り付け、記録の置き場所と読み取り用の関数を作る。どれも読み取りだけで、システムを変えない。

```sh
LC="$HOME/capsaicin-led-check/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$LC"
T0="$(date '+%Y-%m-%d %H:%M:%S')"
# キーボードとして名乗るサービス
kbds() { /usr/bin/hidutil list --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}'; }
# サービスごとの LED のモード（登録 ID、モード、製品名）
leds() {
  /usr/sbin/ioreg -l -w0 -r -c IOHIDEventService | /usr/bin/awk '
    function flush() { if (led != "") print id, led, prod; led = ""; prod = "" }
    / -o / || /^\+-o / { flush(); id = $0; sub(/.*, id /, "", id); sub(/,.*/, "", id) }
    /"Product" = / { if (prod == "") { prod = $0; sub(/.*"Product" = /, "", prod) } }
    /"HIDEventServiceProperties" = / {
      if (match($0, /"HIDCapsLockLED"="?[A-Za-z]+/)) { led = substr($0, RSTART + 17, RLENGTH - 17); gsub(/"/, "", led) }
    }
    END { flush() }'
}
# 機器の属性（実機と仮想の区別に使う）
devs() {
  /usr/sbin/ioreg -l -w0 -r -c IOHIDDevice | /usr/bin/grep -E -- '^\+-o |^  \|   "(Product|Transport|PrimaryUsagePage|PrimaryUsage|HIDVirtualDevice|Built-In|IOUserClass|VendorID)" = '
}
# 機器を開いているクライアントと、占有のオプション
seize() {
  /usr/sbin/ioreg -l -w0 -r -c IOHIDDevice | /usr/bin/grep -E -- '^\+-o |^  \|   "(Product|PrimaryUsage)" = |-o IOHIDLibUserClient|IOUserClientCreator|"DebugState" = \{.*ClientOptions' |
    /usr/bin/sed -E 's/"DebugState" = \{.*"ClientSeized"=([A-Za-z]+).*"ClientOptions"=([0-9]+).*"ClientOpened"=([A-Za-z]+).*/Seized=\1 Options=\2 Opened=\3/'
}
# 記録をまとめて保存する。引数は記録の名前（例: B1-lofree-usb-on）
snap() {
  kbds > "$LC/$1-kbds.txt"; leds > "$LC/$1-leds.txt"; devs > "$LC/$1-devs.txt"; seize > "$LC/$1-seize.txt"
  /bin/cat "$HOME/Library/Application Support/io.github.koutyuke.capsaicin.debug/resume-record.json" > "$LC/$1-record.json" 2>/dev/null
  /bin/date '+%Y-%m-%d %H:%M:%S' > "$LC/$1-time.txt"
}
# T0 以降に LED を書いたプロセスとサービスのログ
ledlog() { /usr/bin/log show --start "$T0" --info --style compact --predicate 'eventMessage CONTAINS "updateCapslockLED"'; }
```

続けて、開始前の状態を残す。

```sh
/usr/bin/sw_vers > "$LC/env.txt"; /usr/sbin/sysctl -n hw.model >> "$LC/env.txt"
/usr/bin/defaults read /Applications/Karabiner-Elements.app/Contents/Info.plist CFBundleShortVersionString >> "$LC/env.txt"
/bin/cp "$HOME/.config/karabiner/karabiner.json" "$LC/karabiner.json.before"
snap B0-start
```

システム設定の「キーボード」→「キーボードショートカット」→「修飾キー」の現在の割り当てと、KE の「Devices」で各機器の「Modify events」「Manipulate caps lock LED」の状態を、画面写真で `LC` に残す。

**LED の戻し方**: 試験中に LED を通常の動作に戻すときは、次の順に試す。

1. Capsaicin で抑止を解除する。
2. 対象に `"Auto"` を書く。`<製品名>` は `leds` に出た名前である。

   ```sh
   /usr/bin/hidutil property --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6,"Product":"<製品名>"}' --set '{"HIDCapsLockLED":"Auto"}'
   ```

3. 外付けの機器を抜き差しする。
4. 画面だけをスリープさせて復帰させる（`pmset displaysleepnow`）。OS が LED を通常の動作に戻す（`EVID-LED-003`）。
5. それでも戻らなければ、Mac を再起動する。

戻ったかは、Caps Lock を手でオン・オフし、LED が連動し、入力が大文字・小文字で切り替わることで判断する。`leds` の値だけで判断しない（`EVID-LED-002`）。

**共通の中止条件**: Caps Lock の入力状態が勝手に変わる、入力監視の許可を求められる、上の手順で LED が戻らない。中止したら B5 の後片付けをする。

`hidutil` で書いた試験では、`ledlog` に `process:hidutil` の行があるか、`leds` の値が変わったかを確かめる。どちらもなければ、書き込みが届いていないので、その試験は判定不能にする。

### B1 機器ごとの対象と点灯（KE は終了）

- **目的**: `HYP-LED-003`、`HYP-LED-007`、`HYP-LED-010`。どの機器がキーボードとして名乗り、どの属性を持ち、LED が光るかを集める。
- **前提**: KE をメニューバーから終了している（「Quit Karabiner-Elements」）。Capsaicin を起動し直してから始める（`HYP-LED-005` の影響を避けるため）。「Caps Lock の LED で知らせる」はオンにする。Caps Lock はオフにする。
- **操作**: 次の各構成で 1〜5 を繰り返す。構成は「内蔵だけ」「Lofree-USB」「Lofree-BT」「Lofree-2.4G」「Viper-USB」「Viper-2.4G」である。外付けの機器は、Capsaicin を起動する前に接続しておく。
  1. `snap B1-<構成>-idle` を実行する。
  2. メニューから抑止を始める。各キーボードの LED を目視する。`snap B1-<構成>-on` を実行する。メニューの警告の有無を見る。
  3. 外付けキーボードで `abc` と入力する。Caps Lock を手でオン・オフし、LED を見る。
  4. 抑止を解除する。HUD の文言を見る。Caps Lock を手でオン・オフし、LED が連動することを見る。`snap B1-<構成>-off` を実行する。
  5. 機器を外す。次の構成の機器を接続してから、Capsaicin を起動し直す。
- **期待**: Lofree は3つの接続のすべてで、抑止中に LED が点き、入力は小文字のままで、解除で通常の動作に戻る。Viper はキーボードとして名乗るサービスを持つかどうかを記録し、持つ場合に警告と「一部を戻せません」が出るかを記録する。
- **記録**: 構成ごとに、`kbds` に出たサービス（製品名、Transport、クラス）、`devs` の `HIDVirtualDevice` と `IOUserClass`、LED の点灯、入力、警告、HUD の文言。KE を終了しても仮想キーボードが `kbds` に残るかも書く。

Lofree-BT で LED が点かない場合は、点かなかった事実を記録して先へ進む。Bluetooth のキーボードには、Caps Lock の LED の要素を複数持つものがある。

### B2 抑止中に増えた・作り直されたキーボード

- **目的**: `HYP-LED-005`。
- **前提**: B1 と同じ。外付けの機器は外しておく。
- **操作**:
  1. KE を終了した状態で Capsaicin を起動し直し、抑止を始める。`snap B2-1-before` を実行する。
  2. Lofree-2.4G を接続し、10秒待つ。LED を目視し、`snap B2-1-connected` を実行する。Lofree-BT でも繰り返す。
  3. 抑止を解除し、HUD の文言を見る。`snap B2-1-off` を実行する。機器を外す。
  4. KE を起動する。Capsaicin を起動し直して抑止を始め、`snap B2-2-before` を実行する。
  5. Apple メニューから Mac をスリープさせ、30秒後に復帰させる。復帰後に LED を目視し、`snap B2-2-woke` を実行する。
  6. 抑止を解除し、HUD の文言を見る。`snap B2-2-off` を実行する。
  7. 対照として、Capsaicin を終了して起動し直し、抑止を始めて `snap B2-3-restarted` を実行する。解除する。
  8. `ledlog > "$LC/B2-ledlog.txt"` を実行する。
- **期待（仮説どおりなら）**: 2 で、接続した機器のサービスは `leds` で `Auto` のまま、または LED が点かない。5 で仮想キーボードの登録 ID が変わり、新しい ID は `Auto` のまま、6 で「一部を戻せません」が出る。7 ではすべてのサービスが `On` になる。仮説が外れていれば、2 と 5 でも新しいサービスが `On` になる。
- **記録**: 各時点の登録 ID とモード、LED の目視、HUD の文言、`record.json` の `misalignments`。

### B3 キーボードを占有するアプリ（KE）との干渉

- **目的**: `HYP-LED-002`、`HYP-LED-006`、`HYP-LED-008`。KE がどの条件で実機の LED を書き換えるか、Capsaicin の書き込みが KE の入力の扱いを変えるか、占有を汎用に見分けられるかを確かめる。
- **前提**: KE を起動し、内蔵と Lofree-USB の「Modify events」をオン、「Manipulate caps lock LED」を既定のオンにする。修飾キーを厳密に照合する KE のルールを1つ選ぶ（`optional` に `any` も `caps_lock` もないもの。例: Shift + Option + 3 のルール）。Capsaicin は起動し直してある。
- **操作**:
  1. `snap B3-1-seized` を実行する。KE を終了して `snap B3-1-quit`、起動して `snap B3-1-restarted` を実行する。
  2. 抑止していない状態で、選んだルールが成立することを確かめる。Caps Lock を手で1回オンにしてからオフにする（KE に「消灯」を覚えさせる）。
  3. 抑止を始め、`snap B3-3-on` を実行する。内蔵と Lofree の LED を、開始直後、15秒後、1分後、10分後に目視する。途中で Caps Lock を手でオン・オフし、LED を見る。
  4. 抑止中に、選んだルールが成立するかを試す。抑止を解除し、もう一度試す。
  5. 抑止していない状態で、Capsaicin を使わずに書いて切り分ける。各書き込みの後に `ledlog` で届いたことを確かめ、試験が終わるたびに B0 の方法で `"Auto"` に戻す。
     - 実機だけ: Caps Lock を手で1回オン・オフしてから、`Apple Internal Keyboard / Trackpad` に `"On"` を書く。LED を10秒見る。
     - 仮想キーボードだけ: `Karabiner DriverKit VirtualHIDKeyboard 1.8.0` に `"On"` を書く。内蔵の LED を10秒見て、選んだルールを試す。`"Auto"` に戻して、もう一度ルールを試す。

     ```sh
     /usr/bin/hidutil property --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6,"Product":"<製品名>"}' --set '{"HIDCapsLockLED":"On"}'
     ```

  6. KE の「Devices」で内蔵の「Manipulate caps lock LED」をオフにし、`snap B3-6` を実行して、5 の「実機だけ」を繰り返す。オンに戻す。
  7. 内蔵の「Modify events」をオフにし、`snap B3-7` を実行して、5 の「実機だけ」を繰り返す。オンに戻す。
  8. `ledlog > "$LC/B3-ledlog.txt"` を実行する。
- **期待（ソースの読解からの予想）**:
  - 1: KE が動いている間だけ、内蔵の usage 6 のデバイスに、KE のクライアントで `Options=1 Opened=Yes` が現れる。「Modify events」をオフにした 7 でも消える。
  - 3: Capsaicin が仮想キーボードにも書くので、KE も点灯を書き、LED は点いたままになる。仮想キーボードに書けていない場合は、3秒以内に消える。
  - 4: 抑止中だけルールが成立しない。
  - 5: 実機だけに書くと3秒以内に消える。仮想キーボードだけに書くと、実機の LED が点き、ルールが成立しなくなる。
  - 6・7: 実機だけに書いても消えない。
- **記録**: 条件ごとに、LED が消えたか（消えたまでの秒数）、ルールの成否、`seize` の印、`leds` の値。

### B4 キーボードを占有しない割り当て

- **目的**: `HYP-LED-009`。
- **前提**: KE を終了している。Capsaicin は起動し直してある。
- **操作**:
  1. システム設定の「修飾キー」で、内蔵の Caps Lock を Control に割り当てる。抑止を始め、10分間 LED を見る。途中で Caps Lock のキー（いまは Control）を押す。`snap B4-1` を実行する。解除して、割り当てを元に戻す。
  2. Lofree-USB を接続し、Lofree に対して 1 を繰り返す。
  3. Raycast の Hyper Key を Caps Lock に割り当てて、1 を繰り返す。終わったら元の設定に戻す。Hyper Key を使っていない場合は、試してよいかを先に決め、試さないなら判定不能にする。
- **期待**: どの割り当てでも LED は点いたままで、解除で通常の動作に戻る。`seize` に、ほかのプロセスの `Options=1 Opened=Yes` は現れない。
- **記録**: 割り当てごとに、LED、割り当てたキーを押したときの変化、`seize` の印。

### B5 後片付け

1. 抑止を解除する。
2. `leds` に出たすべてのサービスに、B0 の方法で `"Auto"` を書く。
3. KE の各機器の設定を開始前に戻し、`diff "$LC/karabiner.json.before" "$HOME/.config/karabiner/karabiner.json"` で差がないことを確かめる。KE の起動・終了の状態を開始前に戻す。
4. システム設定の修飾キーと Raycast の設定を開始前に戻す。
5. 内蔵と接続した各キーボードで Caps Lock を手でオン・オフし、LED が連動し、入力が切り替わることを確かめる。
6. `ledlog > "$LC/session-ledlog.txt"` を実行する。

`LC` のディレクトリは、PM が結果を取り込むまで消さない。

## 結果のまとめ方

試験ごとに、成功・失敗・判定不能と、期待と照らした結論を1行で書く。例: `B3-5 実機だけ: 2.8秒で消灯。KE の Manipulate はオン`。生の記録は `LC` に置き、結果にはそのパスを書く。PM が結果を根拠（`EVID-*`）にし、各仮説の状態を更新する。
