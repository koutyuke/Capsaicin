---
schema: evidence
id: EVID-HLP-005
title: SMAppService のデーモンは版の入れ替えで承認を保って新しい版になり、書き換えや別の署名への差し替えでは起動されなかった
observed_on: 2026-11-18
environment: Apple Silicon（Mac16,8）、macOS 27.2.1（26B131）、試作 CapsaicinProbe の版1〜3を Apple Development の証明書で署名、版1を ad-hoc でも署名、/Applications に配置
sources: ["29fef76:Prototypes/SMAppServiceProbe/MANUAL.md"]
---

# EVID-HLP-005 SMAppService のデーモンは版の入れ替えで承認を保って新しい版になり、書き換えや別の署名への差し替えでは起動されなかった

## 確かめた事実

`EVID-HLP-004` と同じ試作で、デーモンを許可した後に次を確かめた。デーモンの「版」は、ビルドで埋め込んで応答に含めた値である。

### 版の入れ替え

- 別の inode への置き換え（版1を `mv` でゴミ箱へ移し、版2を `ditto` で置く）: 登録し直す前から状態は `enabled` のままで、問い合わせには版2のデーモンが応答した。launchd は、登録済みのジョブの `BundleProgram` を、置き換えた後のバンドルから解決した。
- 同じバンドルへの上書き（版3を `ditto` で上書きする）: 同じく、登録し直す前から `enabled` で、版3のデーモンが応答した。
- 登録し直し（`unregister` の完了を待ってから `register`）: どちらの入れ替えの後も、承認は求められなかった。直後の `register` は2回とも `code=1`（EPERM）で失敗し、3秒待った2回目で成功した。成功すると、デーモンが `RunAtLoad` で起動した。同じ起動の中なので、後片付けは行わなかった。

### 書き換えと差し替え

- 署名の範囲の1バイトを書き換える（デーモンの最初のページにある文字列を変え、`codesign --verify` が `invalid signature` になる状態）: 問い合わせると launchd は起動を試みたが、カーネルが `AMFI: Launch Constraint Violation (enforcing) … (signing-identifier)` を出し、exec の段階で止めた（`OS_REASON_EXEC`）。書き換えたコードは一度も動かなかった。保留中の接続がある間、launchd は10秒おきに起動を試し続けた（8回）。正しい版を入れ直すと、次の試みで起動し、試し直しは止まった。状態は `enabled` のままだった。
- ad-hoc 署名の同じ識別子の実行ファイルへの差し替え（署名としては壊れておらず、`valid on disk`）: カーネルと amfid が `adhoc signed`（`-423`）を記録し、起動の制約が `Constraint not matched` で外れ、exec の段階で止まった（`OS_REASON_CODESIGNING`）。差し替えたコードは一度も動かなかった。正しい版を入れ直した後にアプリを開くと、状態は `requiresApproval` になっていた。
- 署名の範囲の外（ファイルの末尾）に1バイト足しても、`codesign --verify` は失敗するが、デーモンは普通に起動した。実行時に読み込まれる範囲が変わらないためで、書き換えの試験にはならない。

## 確かめ方

オーナーが `MANUAL.md` の手順 6 と 7 に沿って操作した。手順書の 7-2（末尾に1バイト）が試験にならなかったので、手順書の外で上の2つ（署名の範囲の書き換え、ad-hoc 署名への差し替え）を加えた。書き換えは、位置を `assert` で確かめる Python で1バイトだけ行った。結果は、試作の画面の記録と、launchd、xpcproxy、amfid、カーネルのログで確かめた。

## 適用範囲

- 使ってよい: 更新の後にデーモンの承認が保たれること、更新の後の登録し直しの手順（EPERM の試し直しを含む）、利用者が書き込めるバンドルの中のデーモンが root で動かないことを判断するとき。
- 使ってはいけない: plist の中身が変わる更新の振る舞いの根拠（試したのは実行ファイルの版だけ）。

## 未確認のこと

- ad-hoc 署名への差し替えの後に `requiresApproval` になった理由（起動の拒否で承認が外れたと見ているが、記録からは確かめられていない）。
- plist のキーを変えた版へ入れ替えたとき、登録し直さずに新しい定義が使われるか。
- 1台、1つの macOS のバージョンでしか確かめていない。
