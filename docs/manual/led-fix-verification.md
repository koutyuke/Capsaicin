# LED の書き込み先と案内の修正を実機で確かめる手順

`TASK-053`、`TASK-054`、`TASK-056` の修正が実機で期待どおりに動くかを確かめる手順である。オーナーが実機で行い、エージェントは実行しない。LED の点灯、Caps Lock の操作、Karabiner-Elements の起動・終了を伴う。

## 確かめること

| 手順 | 見ること | チケット | 仕様 |
| --- | --- | --- | --- |
| 1 | Karabiner-Elements を止めた状態で、内蔵と Lofree の3つの接続方式が点灯する。案内は出ない | `TASK-054`、`TASK-056` | `SPEC-LED-002`、`SPEC-LED-005` |
| 2 | 抑止中に接続したキーボードが点灯する。スリープから復帰した後も、解除で「一部を戻せません」が出ない | `TASK-053` | `SPEC-LED-002` |
| 3 | Karabiner-Elements の動作中も、抑止中にルールが成立する。仮想キーボードに書かない | `TASK-054` | `SPEC-LED-002` |
| 4 | Karabiner-Elements の起動・終了に合わせて、メニューと設定の案内が出入りする | `TASK-056` | `SPEC-LED-005` |
| 5 | 仮想キーボードの監視で、Capsaicin のメモリと CPU が増え続けない | `TASK-056` | なし |

## 機材と呼び名

| 呼び名 | 機材 | 接続 |
| --- | --- | --- |
| 内蔵 | この MacBook の内蔵キーボード | なし |
| Lofree-USB、Lofree-BT、Lofree-2.4G | Lofree Flow Lite（Caps Lock の LED あり） | 有線、Bluetooth、2.4 GHz |
| KE | Karabiner-Elements | 起動・終了 |

外付けの機器は、指定がない限り1台ずつ接続する。

## 0 毎回の準備

リポジトリのルートで `scripts/manual/verify.sh restart` を実行し、最新のコミットで Capsaicin をビルドして起動する。手順の中の「Capsaicin を起動し直す」もこのコマンドで行う。`verify.sh env` は変数 `B` を上書きするので、この手順の記録先は `LC` に置く。

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
# 記録をまとめて保存する。引数は記録の名前（例: 1-lofree-usb-on）
snap() { kbds > "$LC/$1-kbds.txt"; leds > "$LC/$1-leds.txt"; /bin/date '+%Y-%m-%d %H:%M:%S' > "$LC/$1-time.txt"; }
# T0 以降に LED を書いたプロセスとサービスのログ（成功した書き込みだけが残る）
ledlog() { /usr/bin/log show --start "$T0" --info --style compact --predicate 'eventMessage CONTAINS "updateCapslockLED"'; }
# T0 以降に Capsaicin が書き込んだサービスと失敗したサービス、仮想キーボードの検出の失敗
applog() { /usr/bin/log show --start "$T0" --style compact --predicate 'subsystem == "io.github.koutyuke.capsaicin" AND (category == "LED" OR category == "VirtualKeyboard")'; }
```

続けて、開始前の状態を残し、手順5のための記録を裏で始める。記録は1分ごとに60回取り、自動で止まる。

```sh
/usr/bin/sw_vers > "$LC/env.txt"; /usr/sbin/sysctl -n hw.model >> "$LC/env.txt"
/usr/bin/defaults read /Applications/Karabiner-Elements.app/Contents/Info.plist CFBundleShortVersionString >> "$LC/env.txt"
/usr/bin/git -C "$PWD" rev-parse --short HEAD >> "$LC/env.txt"
snap 0-start
( for i in $(/usr/bin/seq 1 60); do
    P="$(/usr/bin/pgrep -n -x Capsaicin)"
    printf '%s pid=%s %s\n' "$(/bin/date '+%H:%M:%S')" "$P" "$(/bin/ps -o rss=,%cpu= -p "$P" 2>/dev/null)"
    /bin/sleep 60
  done ) > "$LC/5-mem.txt" 2>&1 &
```

`leds` で、KE の仮想キーボード（`Karabiner DriverKit VirtualHIDKeyboard`）が `On` になっていないことを確かめる。前の版の Capsaicin が書いた `On` が残っていると、手順3のルールが成立しない。残っていたら、KE をメニューバーから終了して起動し直す。仮想キーボードが作り直され、`Auto` に戻る。

**LED の戻し方**: 試験中に LED を通常の動作に戻すときは、次の順に試す。`hidutil property --set` は書き込みが届かないので使わない（`EVID-LED-009`）。

1. Capsaicin で抑止を解除する。
2. 外付けの機器を抜き差しする。
3. 画面だけをスリープさせて復帰させる（`pmset displaysleepnow`）。OS が LED を通常の動作に戻す（`EVID-LED-003`）。
4. それでも戻らなければ、Mac を再起動する。

戻ったかは、Caps Lock を手でオン・オフし、LED が連動し、入力が大文字・小文字で切り替わることで判断する。`leds` の値だけで判断しない（`EVID-LED-002`）。

**共通の中止条件**: Caps Lock の入力状態が勝手に変わる、入力監視の許可を求められる、上の手順で LED が戻らない。中止したら手順6の後片付けをする。

## 1 Karabiner-Elements を止めた状態の点灯

- **前提**: KE をメニューバーから終了している（「Quit Karabiner-Elements」）。「Caps Lock の LED で知らせる」はオンにする。Caps Lock はオフにする。
- **操作**: 構成「内蔵だけ」「Lofree-USB」「Lofree-BT」「Lofree-2.4G」のそれぞれで、次を行う。外付けの機器は、抑止を始める前に接続する。Capsaicin を起動し直す必要はない。
  1. メニューと、設定の「LED」セクションを開き、案内がないことを見る。
  2. メニューから抑止を始める。内蔵と Lofree の LED を目視する。`snap 1-<構成>-on` を実行する。
  3. 外付けキーボードで `abc` と入力する。
  4. 抑止を解除する。HUD の文言を見る。Caps Lock を手でオン・オフし、LED が連動することを見る。
  5. 機器を外し、次の構成へ進む。
- **期待**: 案内は出ない。どの構成でも、抑止中は内蔵と Lofree の LED が点き、入力は小文字のままで、解除で通常の動作に戻る。
- **記録**: 構成ごとに、LED の点灯、入力、HUD の文言、案内の有無。

## 2 抑止中に接続したキーボードと、スリープからの復帰

- **前提**: 手順1と同じ。外付けの機器は外しておく。
- **操作**:
  1. KE を終了した状態で抑止を始める。`snap 2-1-before` を実行する。
  2. Lofree-2.4G を接続し、10秒待つ。Lofree の LED を目視し、`snap 2-1-2.4g` を実行する。機器を外し、Lofree-BT でも繰り返す（`snap 2-1-bt`）。
  3. 抑止を解除し、HUD の文言を見る。機器を外す。
  4. KE を起動する。抑止を始め、`snap 2-2-before` を実行する。
  5. Apple メニューから Mac をスリープさせ、30秒後に復帰させる。`snap 2-2-woke` を実行する。
  6. 抑止を解除し、HUD の文言を見る。
  7. `applog > "$LC/2-applog.txt"` を実行する。
- **期待**:
  - 2: 接続した Lofree の LED が10秒以内に点く。`applog` の、接続の後の `LED 書き込み` の `targets` に、`2-1-2.4g-leds.txt`・`2-1-bt-leds.txt` に出た Lofree の登録 ID が入り、`failedTargets=[]` である。
  - 3・6: HUD は通常のオフの表示で、「一部を戻せません」は出ない。
  - 5: 復帰の後の `targets` には、`2-2-woke-leds.txt` にある登録 ID だけが入り、`failedTargets=[]` である。KE が占有するキーボードの LED は点かなくてよい（`DEC-LED-006`）。
- **記録**: 各時点の LED の目視、HUD の文言、`applog` の `targets` と `failedTargets`。

## 3 Karabiner-Elements の動作中の入力

- **前提**: KE を起動し、内蔵と Lofree-USB の「Modify events」と「Manipulate caps lock LED」を既定のオンにする。Lofree-USB を接続する。修飾キーを厳密に照合する KE のルールを1つ使う（`from.modifiers` に `optional` がないもの。前回と同じ「左 Shift＋左 Option＋3 を、左 Shift＋左 Command＋左 Control＋4 に変える」なら、成立すると画面の範囲選択の十字が出る。Esc で消す）。
- **操作**:
  1. 抑止していない状態で、内蔵と Lofree のそれぞれでルールが成立することを確かめる。
  2. 抑止を始める。`snap 3-2-on` を実行する。内蔵と Lofree の LED を、開始直後と1分後に目視する。
  3. 抑止中に、内蔵と Lofree のそれぞれでルールを試す。
  4. 抑止を解除し、もう一度ルールを試す。
  5. `applog > "$LC/3-applog.txt"` を実行する。
  6. 余裕があれば: 内蔵の「Manipulate caps lock LED」をオフにして抑止を始め、内蔵の LED を1分見る。抑止を解除し、設定をオンに戻す。
- **期待**:
  - 2: `3-2-on-leds.txt` で、仮想キーボードの `HIDCapsLockLED` は `Auto` のままである。内蔵と Lofree の LED は点かないか、一瞬点いて消える（`DEC-LED-006` で受け入れた振る舞い）。
  - 3・4: 抑止中も解除後も、ルールが成立する。
  - 5: 抑止を始めたときの `targets` に、仮想キーボードの登録 ID がない。
  - 6: 内蔵の LED が1分間点いたままである。
- **記録**: LED の目視、ルールの成否（キーボードごと、抑止の前・中・後）、仮想キーボードの登録 ID とモード、`targets`。

## 4 案内の出入り

- **前提**: KE が動いている。抑止はしていない。設定ウインドウを開き、「LED」セクションが見える状態にしておく。
- **操作**:
  1. メニューを開き、案内を見る。設定の「LED」セクションの案内と、その (i) の説明を見る。画面写真を `LC` に残す。
  2. KE をメニューバーから終了する（「Quit Karabiner-Elements」）。設定ウインドウを見ながら、案内が消えるまでの秒数を数える。メニューを開き直して、案内がないことを見る。`snap 4-2-quit` を実行する。
  3. KE を起動する。案内が戻るまでの秒数を数え、メニューも開き直して見る。
- **期待**:
  - 1: メニューに「キー配列を変更するアプリが動作中」と副題「LEDが点灯しないことがあります」、設定に同じ見出しと説明「そのアプリがCaps LockのLEDを制御している場合、スリープ防止中もLEDが点灯しないことがあります。」が出る。
  - 2: 10秒以内に、設定とメニューの両方から案内が消える。`4-2-quit-kbds.txt` に KE の仮想キーボードがない。
  - 3: 10秒以内に、案内が戻る。
- **記録**: 案内の画面写真、消えるまでと戻るまでの秒数。

## 5 監視の負荷

- **前提**: 手順0で始めた記録が裏で動いている。
- **操作**: 何もしない。手順6で記録を見る。
- **期待**: `5-mem.txt` の RSS（KB）が、Capsaicin を起動し直していない区間で増え続けない。CPU は、抑止の操作をしていない間は 0% 付近である。
- **記録**: 区間ごとの RSS の最小と最大、CPU の最大。

## 6 後片付け

1. 抑止を解除する。
2. KE の各機器の設定と、KE の起動・終了の状態を開始前に戻す。
3. 内蔵と接続した各キーボードで Caps Lock を手でオン・オフし、LED が連動し、入力が切り替わることを確かめる。
4. `ledlog > "$LC/session-ledlog.txt"` と `applog > "$LC/session-applog.txt"` を実行する。
5. 手順5の記録が終わっていなければ、`jobs` で番号を見て `kill %<番号>` で止める。

`LC` のディレクトリは、PM が結果を取り込むまで消さない。

## 結果のまとめ方

試験ごとに、成功・失敗・判定不能と、期待と照らした結論を1行で書き、`$LC/verification-results.txt` に置く。例: `2-1 Lofree-2.4G: 接続から3秒で点灯。targets に新しい ID あり、failedTargets なし`。PM が結果を確かめ、チケットを閉じる。
