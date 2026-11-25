---
schema: evidence
id: EVID-SYS-003
title: ad-hoc 署名で launchd の管理下にある Capsaicin を、Sparkle 2.10.1 で利用者の追加の操作なしに更新できた
observed_on: 2026-11-16
environment: Apple Silicon（arm64）、macOS 27.2.1（26B131）、Xcode 27.2、Debug 構成の 0.9.0 (100) → 0.9.1 (101)、配信は 127.0.0.1 の HTTP、ヘルパーは未設置
sources: ["ac1897d:docs/manual/update-verification.md", "ac1897d:scripts/manual/update-test.sh"]
---

# EVID-SYS-003 ad-hoc 署名で launchd の管理下にある Capsaicin を、Sparkle 2.10.1 で利用者の追加の操作なしに更新できた

## 確かめた事実

- 署名の検証: 次の4種は、どれも A（0.9.0、同じ PID）のまま更新されなかった。
  - `tampered` と `wrong-key`: zip を取得した後、展開の前に `EdDSA signature does not match` で拒否された。
  - `wrong-feed`: appcast の署名が合わないため拒否され、zip は取得されなかった。
  - `unsigned`: `no EdDSA signature in the appcast` で拒否され、zip は取得されなかった。
  - Developer ID による代わりの検証も、TeamIdentifier がないため失敗した。
  - 正しい更新は `EdDSA signature is correct for update` で受け入れられた。
- 起動: 更新後、Gatekeeper や認証の画面は出なかった。
  - 更新後のアプリの 191 ファイルのどれにも `com.apple.quarantine` はなかった（`com.apple.provenance` だけ）。
  - `codesign --verify --deep --strict` は成功した。本体、`Sparkle.framework`、`Autoupdate`、`Updater.app` はすべて ad-hoc 署名で、TeamIdentifier はない。
- launchd: 0.2〜0.3 秒ごとに記録したプロセスでは、旧版と新版が同時に動いた時点はなく、旧版の再起動もなかった。
  - 新版だけは、引き渡しの約 0.4 秒間に2つ並んだ（Sparkle が起動した個体と launchd の個体）。最後に残ったのは1つである。
  - ジョブの `pid` は残ったプロセスと一致し、`ProgramArguments` は入れ替え前と同じパスのままだった。
- 再起動: Mac を再起動すると、手で開かなくても新版（PPID 1）が起動した。ログイン項目とバックグラウンド項目の Capsaicin は1件で、再起動の前後で変わらなかった。
- 終了の扱い: 更新のために終了した後の再開記録には `exitReason` がなく、`session` は消えていた。メニューと「このアプリについて」から終了したときは、どちらも `exitReason: "userQuit"` だった。
- 抑止との関係（`SPEC-LCY-008`）:
  - 自動のインストールは、抑止の解除と設定ウインドウを閉じることの両方がそろうまで待った。どちらの順にそろえても同じだった。
  - 抑止中に手動のインストールを取り消すと、抑止とその解除時刻は変わらず、項目はインストール待ちになった。
  - 抑止中に手動のインストールを続けると、更新後は停止中で起動した。このとき再開の設定は「クラッシュおよびMacの再起動後」で、LED は消灯し、アサーションは残らなかった。
- 既知の差: Sparkle 2.10.1 の日本語の画面でも、`wrong-feed` と `unsigned` のエラーの本文は英語だった。題は日本語である。

## 確かめ方

オーナーが、`feature/sparkle-updates` の `ac1897d` にあった手順書 `docs/manual/update-verification.md` に従って実施した。手順書と補助スクリプトは、確認を終えた後に削除した。再び確かめるときは、そのコミットから取り出し、`DEC-SYS-020` の just のレシピに合わせて直す。

- 鍵は使い捨てのものを使った。
- 版の番号とビルド番号だけが違う2つの Debug ビルドを `scripts/manual/update-test.sh` で作った。
- `127.0.0.1:8123` から配信した。ATS の例外は使っていない。
- ログと画面写真は、オーナーの退避先に残した。

## 適用範囲

- 使ってよい: ad-hoc 署名のビルド同士の更新で、EdDSA の検証、quarantine、launchd の管理下での入れ替え、再起動後の起動を判断するとき。
- 使ってはいけない:
  - 別の版の Sparkle や Developer ID 署名のビルド。
  - GitHub Releases の HTTPS 配信と、ブラウザで入れた Release 構成のビルド。
  - ヘルパーを設置した環境。

## 未確認のこと

- 利用者がバックグラウンド項目を無効にした状態が、更新の後も保たれるか。
- Sparkle による終了を、判定できない終了として分類しているか。直接記録する手段がないため、記録の結果から間接に確かめただけである。
- ヘルパーを設置した状態で更新したときに、ヘルパーが使えるままか。
- VoiceOver の読み上げ。
