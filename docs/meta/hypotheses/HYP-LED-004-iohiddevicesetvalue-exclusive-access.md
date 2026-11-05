---
schema: hypothesis
id: HYP-LED-004
title: IOHIDDeviceSetValue は Karabiner-Elements の独占時に失敗し、外付けには入力監視の権限が要る
status: open
affects: ["DEC-LED-001"]
evidence: []
---

# HYP-LED-004 IOHIDDeviceSetValue は Karabiner-Elements の独占時に失敗し、外付けには入力監視の権限が要る

## 主張

Karabiner-Elements がキーボードを独占しているとき、`IOHIDDeviceSetValue` で Caps Lock の LED の値を書き込むと `kIOReturnExclusiveAccess` で失敗する。また、外付けキーボードに対して `IOHIDDeviceSetValue` を使うには、入力監視の権限が要る。

## 外れたときに起きること

`DEC-LED-001` で `IOHIDDeviceSetValue` を却下した理由が崩れる。公開 API で同じことができるなら、非公開 API に依存しない方式として比べ直す。

## 確かめ方

1. 環境: 対応環境の Mac。Karabiner-Elements を有効にした場合と無効にした場合。内蔵キーボードと外付けキーボード。試作プログラムには入力監視の権限を与えない。
2. 試作プログラムで、各キーボードの `IOHIDDevice` を開き、Caps Lock の LED の要素に `IOHIDDeviceSetValue` で値を書き込み、戻り値を記録する。
3. 成功（主張どおり）: Karabiner-Elements が有効なとき `kIOReturnExclusiveAccess` が返り、外付けキーボードでは権限がないと開けないか書き込めない。失敗: どちらかの条件でも書き込みが成功する。

終わったら、LED が Caps Lock の状態に連動していることを確かめる。

## 結果

未確認。
