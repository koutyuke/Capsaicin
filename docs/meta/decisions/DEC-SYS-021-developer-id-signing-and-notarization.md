---
schema: decision
id: DEC-SYS-021
title: 配布物だけを Developer ID で署名して公証し、手元のビルドは ad-hoc 署名のままにする
status: accepted
supersedes: ["DEC-SYS-004"]
superseded_by: []
requirements: ["REQ-SYS-005", "REQ-SYS-006", "REQ-SYS-008"]
based_on: ["DEC-SYS-015", "DEC-SYS-019", "EVID-SYS-001", "HYP-SYS-004"]
---

# DEC-SYS-021 配布物だけを Developer ID で署名して公証し、手元のビルドは ad-hoc 署名のままにする

## 結論

オーナーは Apple Developer Program に個人で加入した。GitHub Releases で配る zip を、次のように作る。

- リリース用の PR の確認用のビルドと、公開する zip の両方を、Developer ID Application 証明書で署名する。Hardened Runtime と secure timestamp を付け、Apple の公証を通し、公証のチケットをアプリに staple する。
- Debug ビルド、`just build`、`just dist`、CI のテストは ad-hoc 署名のままにする。ソースからビルドする人に証明書を求めず、アプリの機能を署名の種類に依存させない（`REQ-SYS-005`、`REQ-SYS-006`）。
- 署名は、`just dist` が作った ad-hoc 署名の zip を受け取り、リポジトリを checkout しない macOS のジョブで、内側から順に署名し直す。順序は、`Contents/Helpers` の2つの実行ファイル、`Sparkle.framework` の中身（Sparkle の文書が示す順）、`Sparkle.framework`、アプリ本体である。`--deep` は使わない。entitlements は付けず、Sparkle の `Downloader.xpc` だけは既存の entitlements を保つ。
- 公証は `notarytool` に App Store Connect の Team Key（ロールは Developer）を渡して行い、結果を待つ。公証、`stapler validate`、`spctl --assess` のどれかが通らなければ、artifact を作らずに止める。
- Sparkle の appcast の EdDSA 署名、`SHA256SUMS.txt`、ビルドの来歴の attestation は、staple した後の zip に対して作る。
- 証明書（`.p12`）、そのパスワード、Team Key（`.p8`）、Key ID、Issuer ID は Actions secret に置く。証明書は実行ごとの一時キーチェーンに入れ、ジョブの最後に消す。secret の名前と登録の手順は `docs/manual/release.md` にある。
- Sparkle の検証の設定（`DEC-SYS-019`）は変えない。Developer ID の Team ID の一致で鍵を入れ替える経路は、使うときに別の判断で決める。

## 背景

`DEC-SYS-004` では加入せず、配布物は ad-hoc 署名で公証しなかった。利用者は初めて開くときに「このまま開く」を選ぶ必要があり（`EVID-SYS-002`）、Homebrew の公式 Cask にも載せられなかった（`EVID-SYS-001`）。その後、リポジトリを公開し、Sparkle で更新を配るようになった（`DEC-SYS-019`）。オーナーは加入を決め、Developer ID Application 証明書と公証用の Team Key を用意した。

リリース済みの安定版は v0.1.0 だけで、Sparkle を含まない。v0.1.0 の利用者は、次の版を手で入れ替える（`DEC-SYS-019`）。そのため、Sparkle で ad-hoc 署名の版から Developer ID 署名の版へ更新する利用者はいない。

加入で選べるようになったほかの方式（`SMAppService.daemon` のヘルパー、`SMAppService.agent`、XPC）は、この判断では採らない。`DEC-HLP-001` の覆す条件（加入したら `SMAppService.daemon` を比べ直す）には当たるが、比べ直しは別の判断で行う。

## 選択肢

署名する範囲:

- すべてのビルドを Developer ID か Apple Development で署名する。手元のビルドが配布物に近くなるが、ソースからビルドする人と CI のテストに証明書が要る（不採用）。
- 配布物だけを署名する（採用）。

署名する場所:

- `just dist` のビルドで Xcode に Developer ID で署名させる。手順は短いが、証明書の秘密鍵が、リポジトリのスクリプトと依存パッケージのコードを実行するジョブに入る（不採用）。
- ビルドしたアプリを、checkout しない別のジョブで署名し直す（採用）。Sparkle の秘密鍵と同じ隔離のしかたである（`DEC-SYS-019`）。

確認用のビルド:

- 公開する zip だけを署名する。確認用のビルドで実機の確認をしても、署名と公証の影響を確かめられない（不採用）。
- 確認用のビルドも同じ手順で署名して公証する（採用）。

公証の認証:

- Apple Account とアプリ用パスワードを使う。オーナーの Apple Account の認証情報を CI に置くことになる（不採用）。
- App Store Connect の Team Key を使う（採用）。キーは公証などに用途を絞れ、Apple Account とは別に無効にできる。

## 理由

- 利用者が初めて開くときに「このまま開く」を選ぶ手順がなくなる。
- 手元のビルドを ad-hoc 署名のままにすれば、加入していない人も今までどおりソースからビルドして使える。
- 署名の秘密鍵を、ビルドの処理から切り離せる。
- 確認用のビルドに同じ処理を通すことで、マージの前に、公開する zip と同じ署名と公証の状態で実機の確認ができる。

## 影響

- `.github/workflows/release.yml` に、署名と公証のジョブが加わる。リリース用の PR を更新するたびに公証を待つので、確認用のビルドは数分遅くなる。Apple の公証サービスが止まっていると、確認用のビルドも公開も止まる。公開が止まったときは、失敗したジョブを再実行する。
- `DEC-SYS-015` の「Release 構成・ad-hoc 署名の zip」は、確認用のビルドと公開のどちらも、この判断の署名と公証を通した zip に変わる。確認用のビルドの PR のコメントには、署名の状態を Developer ID と公証済みとして示す。
- `docs/product/overview.md` の非目標から公証を外す。README の「このまま開く」の案内を外す。
- 署名の名前（Developer ID Application の証明書の名前）に、オーナーの Apple Account の氏名が入る。
- 年会費がかかる。証明書の有効期限は 2027年12月17日、メンバーシップの更新日は 2027年11月18日である。期限が切れる前に証明書を作り直し、Actions secret を差し替える。期限が切れても、それまでに署名した版は動き続ける。
- Hardened Runtime を有効にするので、entitlements なしで既存の機能が動くことを確かめる必要がある（`HYP-SYS-004`）。

## 覆す条件

- メンバーシップを更新しないと決めたら、`DEC-SYS-004` の方式に戻すかを決める。
- `HYP-SYS-004` が外れ、Hardened Runtime か署名の変更で機能が動かないと分かったら、entitlements の例外を足すか、署名のしかたを見直す。
- 公証の要件が変わり、ビルドの後に署名し直す方式が通らなくなったら、ビルドで署名する方式を比べ直す。
- `SMAppService.daemon` などへの移行を決めたら、手元のビルドを ad-hoc 署名のままにできるか（`REQ-SYS-006`）を見直す。
