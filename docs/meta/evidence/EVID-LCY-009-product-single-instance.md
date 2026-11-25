---
schema: evidence
id: EVID-LCY-009
title: 製品のビルドで Debug の動作中に同じ bundle ID の別のコピーを開くと、後から開いた方が終了し、動いていた方の設定ウインドウが前に出た
observed_on: 2026-11-19
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、Xcode 27.2（27B52）。`feature/smappservice` の `fa4bc85` の Debug ビルドを `just sign-debug` で Developer ID Application の証明書で署名し直した。電源アダプターに接続
sources: ["fa4bc85:docs/manual/verification/single-instance.md"]
---

# EVID-LCY-009 製品のビルドで Debug の動作中に同じ bundle ID の別のコピーを開くと、後から開いた方が終了し、動いていた方の設定ウインドウが前に出た

## 確かめた事実

手元のビルド（PID 58133）を「指定時刻」をオンにして抑止中にし、設定ウインドウを閉じておいた。1回だけ試した。

1. `just start` は `Debug apps are running. Run just stop first.` を出し、終了コード 1 で起動しなかった。
2. ビルドを退避先にコピーし（署名検査に成功、bundle ID は同じ）、`open -n -W` で新しいプロセスとして開いた。`open` は終了コード 0 で戻り、コピーのプロセスは残らなかった。
3. 動いていた方の設定ウインドウが自動で前に出た。PID、開始時刻、実行ファイル、アサーション、解除の時刻（04:00）は変わらず、`SleepDisabled 0` のままだった。

## 確かめ方

`docs/manual/verification/single-instance.md`（`fa4bc85`）の手順で、前後の PID、実行ファイル、アサーション、`SleepDisabled` を読んだ。設定ウインドウと解除の時刻はオーナーが目で確かめた。

## 適用範囲

同じ bundle ID のコピーを別の場所から開いた場合に当てはまる。動いていた方が先に起動を終えていたので、起動途中に開き直しを受ける場合は含まない。

## 未確認のこと

- `/Applications` に置いた PR の Debug ビルドとの組み合わせ。
- ほぼ同時の起動と、動いていた方が終了しかけている間の起動。
