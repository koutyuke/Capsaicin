# Homebrew の Cask で入れて消す

`brew install --cask koutyuke/tap/capsaicin` で入れた Release 版の Capsaicin が、Gatekeeper の検査に通って起動すること、`capsaicin` のコマンドが PATH に入ること、`brew uninstall --cask capsaicin` でアプリとコマンドが消えることを確かめる。あわせて、tap を `brew trust` で信頼していなくても、入れる・消すの手順が通るかを見る。対応する判断は `DEC-SYS-031` と `DEC-CLI-004`、未確認のことは `EVID-SYS-010` にある。

対象は Debug ではなく、`/Applications/Capsaicin.app` の Release 版である。このファイルは `prepare.md` と `cleanup.md` を使わず、このファイルの中で始めから元に戻すまでを行う。実行するのはオーナーである。

## 始める前に

- `/Applications/Capsaicin.app` に GitHub Release から入れた Release 版（0.2.0）があり、ヘルパーが「有効」になっている。違う場合は、開始時の状態を記録してから進める。
- `brew --version` が動く。
- 抑止していない（メニューバーのアイコンが「スリープ防止中」でない）。

ターミナルで退避先を作り、開始時の状態を残す。以降の操作は同じターミナルで行う。

```sh
B="$(/usr/bin/mktemp -d "$HOME/Capsaicin-verification.XXXXXX")"
printf 'B=%s\n' "$B"
brew --version > "$B/start.txt"
/usr/bin/defaults read /Applications/Capsaicin.app/Contents/Info CFBundleShortVersionString >> "$B/start.txt"
/usr/bin/defaults read /Applications/Capsaicin.app/Contents/Info CFBundleVersion >> "$B/start.txt"
brew list --cask 2>/dev/null | /usr/bin/grep -x capsaicin >> "$B/start.txt" || echo "capsaicin cask: not installed" >> "$B/start.txt"
brew trust --json=v1 >> "$B/start.txt" 2>&1
/usr/bin/pmset -g | /usr/bin/grep -i SleepDisabled >> "$B/start.txt"
cat "$B/start.txt"
```

期待: `capsaicin cask: not installed` が出る。`brew trust --json=v1` の出力に `koutyuke/tap` がない。`koutyuke/tap` がすでに信頼されているなら、操作4の信頼の確認は判定不能にする。

## 操作と期待

### 1. GitHub Release の版を外す

1. メニューバーの Capsaicin のメニューから「設定…」を開き、「ヘルパー」を選ぶ。
2. 「削除…」を押し、確認の「削除」を押す。
3. 「状態」が「未インストール」になる。
4. メニューから「Capsaicinを終了」を選ぶ。
5. Finder で `/Applications/Capsaicin.app` をゴミ箱に入れる。ゴミ箱は空にしなくてよい。設定と記録（`~/Library` の下）は消さない。

```sh
/bin/ls -d /Applications/Capsaicin.app 2>&1
/usr/bin/pmset -g | /usr/bin/grep -i SleepDisabled
```

期待: `No such file or directory` が出る。`SleepDisabled` は `0` である。

### 2. Homebrew で入れる

```sh
brew install --cask koutyuke/tap/capsaicin 2>&1 | /usr/bin/tee "$B/install.txt"
```

期待:

- 最後まで成功し、Gatekeeper や署名のエラーが出ない。
- `Linking Binary 'capsaicin'` のような、コマンドへのリンクを作る行が出る。
- Caveats に「If you installed the helper, remove it before uninstalling: open Capsaicin's settings, go to Helper, and click Remove…」が出る。

続けて、入ったものを読む。

```sh
/usr/bin/defaults read /Applications/Capsaicin.app/Contents/Info CFBundleShortVersionString
/usr/bin/xattr -p com.apple.quarantine /Applications/Capsaicin.app 2>&1
/usr/sbin/spctl --assess --type execute -vv /Applications/Capsaicin.app 2>&1
command -v capsaicin
/bin/ls -l "$(command -v capsaicin)"
```

期待: 版は `0.2.0`。`spctl` は `accepted` と `source=Notarized Developer ID` を出す。`capsaicin` は Homebrew の `bin` にあり、`/Applications/Capsaicin.app/Contents/Helpers/capsaicin` へのリンクである。quarantine の属性は、付いていてもいなくても記録だけする。

### 3. 起動してコマンドを使う

```sh
/usr/bin/open /Applications/Capsaicin.app
```

1. 初めて開くときに macOS のダイアログが出たら、その文面を記録する。「開く」を選べば開けるインターネットからのダウンロードの確認は、失敗に数えない。開けない、または「このまま開く」が要る警告は失敗とする。
2. メニューバーに Capsaicin のアイコンが出る。
3. 「設定…」の「このアプリについて」に「バージョン0.2.0」が出る。
4. 「設定…」の「操作」で「CLIからの操作を許可」がオンであることを確かめる。

```sh
capsaicin status; echo "exit=$?"
```

期待: 1行目が `○` で始まり、`exit=0` になる。

### 4. 信頼していない tap のまま、短い名前で扱う

```sh
brew info --cask capsaicin 2>&1 | /usr/bin/tee "$B/info.txt"
```

期待: Cask の情報が出るか、`brew trust` を求めるメッセージが出る。どちらかを記録する。

### 5. Homebrew で消す

ヘルパーは操作1で外してある。

```sh
brew uninstall --cask capsaicin 2>&1 | /usr/bin/tee "$B/uninstall.txt"
```

`brew trust` を求めるメッセージで失敗したら、そのまま記録してから信頼し、もう一度消す。

```sh
brew trust --tap koutyuke/tap
brew uninstall --cask capsaicin 2>&1 | /usr/bin/tee "$B/uninstall-trusted.txt"
```

消えたことを読む。

```sh
/bin/ls -d /Applications/Capsaicin.app 2>&1
command -v capsaicin || echo "capsaicin: not found"
/bin/ps -axo pid,comm | /usr/bin/grep -i '/Capsaicin.app/' | /usr/bin/grep -v grep || echo "no Capsaicin process"
```

期待: アプリが動いていれば終了してから消える。`No such file or directory`、`capsaicin: not found`、`no Capsaicin process` が出る。

`--zap` は設定と記録を消すので、この確認では使わない。

## 中止するとき

- 操作2で Gatekeeper や署名のエラーが出たとき。`--no-quarantine` などで回避せず、出力を `B` に残して「元に戻す」へ進む。
- 操作3でアプリが開けないとき。システム設定の「プライバシーとセキュリティ」で許可せず、画面写真を `B` に残して「元に戻す」へ進む。
- `SleepDisabled` が `0` に戻らないとき。承認済みの復旧操作で戻し、PM に報告する。

```sh
/usr/bin/sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g | /usr/bin/grep -i SleepDisabled
```

## 元に戻す

Homebrew で入れた版を使い続けるなら、入れ直してヘルパーを戻す。

```sh
brew install --cask koutyuke/tap/capsaicin
/usr/bin/open /Applications/Capsaicin.app
```

1. 「設定…」の「ヘルパー」で「インストール…」を押し、確認の「インストール」を押す。
2. 「システム設定を開く」が出たら押し、システム設定で Capsaicin を許可する（項目名は確かめた画面の表記で記録する）。
3. 「状態」が「有効」になる。

GitHub Release の版に戻すなら、Homebrew で入れた版があれば先に `brew uninstall --cask capsaicin` で消す。そのうえで、ゴミ箱に入れた `Capsaicin.app` を `/Applications` に戻すか、Release の DMG から入れ直し、同じ手順でヘルパーを戻す。

## 記録

`B/result.txt` に、次を期待と照らした結論で書く。

- 操作2: インストールの成否、Gatekeeper のエラーの有無、リンクの行、Caveats の文面、`spctl` の結果、quarantine の属性の有無
- 操作3: 初めて開いたときのダイアログの文面、`capsaicin status` の1行目と終了コード
- 操作4: 信頼していない tap で `brew info --cask capsaicin` が通ったか
- 操作5: 信頼していない tap で `brew uninstall --cask capsaicin` が通ったか。通らなければ、信頼した後に通ったか
- 元に戻した後の状態（どちらの版か、ヘルパーの「状態」）
