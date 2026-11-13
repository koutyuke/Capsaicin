<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

  <h1>🌶️ Capsaicin</h1>

  <p><i>Mac のスリープを止めている間、Caps Lock の LED が知らせます。</i></p>
  <p>
    <a href="https://github.com/koutyuke/Capsaicin/actions/workflows/ci.yml"><img src="https://github.com/koutyuke/Capsaicin/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
    <img src="https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&amp;logoColor=white" alt="macOS 26+">
    <img src="https://img.shields.io/badge/Apple_Silicon-arm64-000000" alt="Apple Silicon">
    <img src="https://img.shields.io/badge/Swift-6.4-F05138?logo=swift&amp;logoColor=white" alt="Swift 6.4">
    <img src="https://img.shields.io/badge/License-MIT-64748B" alt="MIT License">
  </p>

  <p>
    <a href="./README.md">🇬🇧 English</a> | <b>🇯🇵 日本語</b>
  </p>

  <p><sub>✦ ✦ ✦</sub></p>
</div>
<!-- markdownlint-enable MD033 -->

## 概要

**Capsaicin** は、Mac のスリープを種類ごとに止め、止めている間は Caps Lock の LED を点灯させるメニューバーアプリです。画面を見なくても、スリープを止めたままかどうかが分かります。変えるのは LED の表示だけで、Caps Lock の入力状態は変わりません。

```text
               ┌──→ スリープを止める（自動 / ディスプレイ / 手動 / ディスプレイを閉じたとき）
抑止を開始 ────┤
               └──→ Caps Lock の LED を点灯

解除・タイマー・指定時刻・バッテリー残量 ──→ スリープの設定と LED を元に戻す
```

- **止めるスリープを選べる**: 自動スリープ、ディスプレイスリープとスクリーンセーバ、手動スリープ、ディスプレイを閉じたときのスリープを止められます。ディスプレイを閉じたときは、ディスプレイをオフにするか輝度を 0 にして動かし続けられます。
- **画面を見ずに分かる LED**: 内蔵と外付けのキーボードの Caps Lock の LED を点灯します。Caps Lock の入力状態は変えず、入力監視の権限も求めません。
- **止めたままにしない**: タイマー、指定時刻、バッテリー残量で解除し、スリープの設定を元に戻します。終了、クラッシュ、再起動の後も後片付けをします。
- **メニューバー、ホットキー、CLI**: メニューバー、自分で割り当てるホットキー、`capsaicin` コマンドで開始と解除ができます。メニューバーとホットキーでの切り替えは HUD で知らせます。
- **最小限の root ヘルパー**: 管理者認証で承認する設置と削除の処理を除けば、root で動くのは、2つのサブコマンドだけを受け付ける小さなヘルパーだけです。

UI は日本語だけです。開発中で、配布用のビルドはまだありません。使うには、ソースからビルドします。

## 動作環境

- Apple Silicon の Mac
- macOS 26 以降

## root 権限で動くヘルパー

手動スリープとディスプレイを閉じたときのスリープを止めるには、root 権限が要ります。この2つを止める設定を選ぶと、Capsaicin は管理者認証を1回求め、次の3つを設置します。

| 設置するもの     | 置き場所                          | 役割                                                                                                 |
| ---------------- | --------------------------------- | ---------------------------------------------------------------------------------------------------- |
| ヘルパー         | `/Library/PrivilegedHelperTools/` | `on`（`pmset -a disablesleep 1` と同じ）と `off`（`pmset -a disablesleep 0` と同じ）だけを受け付ける |
| sudoers のルール | `/etc/sudoers.d/`                 | インストールしたユーザーに、ヘルパーの `on` と `off` だけをパスワードなしで許可する                  |
| LaunchDaemon     | `/Library/LaunchDaemons/`         | Mac の起動時にヘルパーの `off` を実行し、スリープを止めたままにしない                                |

3つは設定画面の「ヘルパー」から削除できます。振る舞いは [`docs/specs/helper.md`](./docs/specs/helper.md)、この構成を選んだ理由は [`DEC-HLP-001`](./docs/meta/decisions/DEC-HLP-001-minimal-helper-via-sudoers.md) にあります。

## ソースからビルドする

Xcode 27.2 と、flakes を有効にした Nix が必要です。次を実行します。

```bash
git clone https://github.com/koutyuke/Capsaicin.git
cd Capsaicin
nix develop --command just build
```

アプリは `.build/xcode/Build/Products/Debug/Capsaicin.app` にできます。ad-hoc 署名で、Apple の公証は受けていません（理由は [`DEC-SYS-004`](./docs/meta/decisions/DEC-SYS-004-no-developer-program-distribution.md)）。

## 開発とテスト

```bash
nix develop --command just check  # 整形の検査、lint、すべてのテスト
nix develop --command just test   # 検査スクリプト、パッケージ、アプリのテスト
nix develop --command just fmt    # treefmt ですべてのファイルを整形
```

開発環境の前提とすべてのレシピは [`AGENTS.md`](./AGENTS.md) にあります。

## 文書

- 🧭 [文書の入口](./docs/README.md) — 要件、仕様、判断の探し方
- 🎯 [製品の概要](./docs/product/overview.md) — 目的、利用者、目標、非目標
- 📐 [仕様](./docs/specs/) — 機能ごとの振る舞い
- 🧱 [判断](./docs/meta/decisions/) — 何を選び、なぜ選び、いつ見直すか

## 貢献

不具合の報告と要望は、[Issues](https://github.com/koutyuke/Capsaicin/issues) で受け付けています。英語でも日本語でも構いません。Pull Request は受け付けていません。

## ライセンス

Copyright 2026 koutyuke

本リポジトリは [MIT License](./LICENSE) のもとで公開されています。リポジトリに含める第三者の著作物は [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md) にあります。
