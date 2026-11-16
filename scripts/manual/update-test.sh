#!/usr/bin/env bash
# docs/manual/update-verification.md のオーナー専用補助。アプリや launchctl は操作しない。
# エージェントが実行してよいのは prepare / disabled のビルド・appcast 生成だけである。
set -euo pipefail
set +x
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail() {
  echo "中止: $*" >&2
  exit 1
}
usage() {
  echo '使い方: update-test.sh prepare [port=8123] [local-ats]'
  echo '        update-test.sh {disabled|serve|clean} WORK'
  echo '        update-test.sh feed WORK {good|current|tampered|wrong-key|wrong-feed|unsigned}'
  exit 64
}

workspace() {
  W="$(cd "${1:?作業先が必要}" && pwd -P)"
  [[ $W == "$ROOT"/.build/tmp/update-test.* && -f "$W/.update-test" ]] || fail '作業先が違う'
  PORT="$(<"$W/port")"
}

build_app() {
  local name="$1" version="$2" number="$3" feed="$4" key="$5"
  /usr/bin/xcodebuild -project Capsaicin.xcodeproj -scheme Capsaicin -sdk macosx \
    -destination 'platform=macOS,arch=arm64' -configuration Debug \
    -derivedDataPath "$W/build-$name" -clonedSourcePackagesDirPath "$W/spm" \
    "MARKETING_VERSION=$version" "CURRENT_PROJECT_VERSION=$number" \
    "SPARKLE_FEED_URL=$feed" "SPARKLE_PUBLIC_ED_KEY=$key" \
    "${INFO_ARGS[@]}" build >"$W/build-$name.log" 2>&1
  /usr/bin/codesign --verify --deep --strict "$W/build-$name/Build/Products/Debug/Capsaicin.app"
}

archive_app() {
  /usr/bin/ditto -c -k --norsrc --noextattr --noacl --keepParent \
    "$W/build-$1/Build/Products/Debug/Capsaicin.app" "$W/$2/Capsaicin-$1.zip"
}

appcast() {
  "$W/tools/bin/generate_appcast" --ed-key-file - --embed-release-notes \
    --download-url-prefix "http://127.0.0.1:$PORT/" \
    -o "$W/$1/appcast.xml" "$W/$1" <"$W/keys/seed" >"$W/appcast-$1.log" 2>&1
}

select_feed() {
  case "$1" in good | current | tampered | wrong-key | wrong-feed | unsigned) ;; *) usage ;; esac
  cp "$W/$1/appcast.xml" "$W/public/appcast.next"
  mv "$W/public/appcast.next" "$W/public/appcast.xml"
  # current 以外は同じ URL を使うので、feed と一緒に配信する zip も切り替える。
  if [[ $1 != current ]]; then cp "$W/$1/Capsaicin-B.zip" "$W/public/Capsaicin-B.zip"; fi
  echo "配信: $1"
}

INFO_ARGS=()
case "${1:-}" in
prepare)
  PORT="${2:-8123}"
  [[ $PORT =~ ^[0-9]{4,5}$ && $PORT -ge 1024 && $PORT -le 65535 ]] || fail 'port は1024〜65535'
  [[ ${3:-} == '' || ${3:-} == local-ats ]] || usage
  mkdir -p "$ROOT/.build/tmp"
  W="$(mktemp -d "$ROOT/.build/tmp/update-test.XXXXXX")"
  touch "$W/.update-test"
  printf '%s\n' "$PORT" >"$W/port"
  echo "作業先: $W（失敗した場合も鍵を片付けること）"
  mkdir "$W/keys" "$W/tools" "$W/good" "$W/current" "$W/public"
  for name in seed other-seed; do
    /usr/bin/head -c 32 /dev/urandom | /usr/bin/base64 >"$W/keys/$name"
  done
  cat >"$W/derive.swift" <<'SWIFT'
import CryptoKit
import Foundation
let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    .trimmingCharacters(in: .whitespacesAndNewlines)
guard let seed = Data(base64Encoded: input), seed.count == 32 else {
    fatalError("seed must be 32 bytes base64")
}
let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
print(key.publicKey.rawRepresentation.base64EncodedString())
SWIFT
  /usr/bin/xcrun swift "$W/derive.swift" <"$W/keys/seed" >"$W/public-key.txt"
  # ShellCheck は入力ファイルだけを検査するため、版を持つ既存設定の追跡を省く。
  # shellcheck source=/dev/null
  source "$ROOT/.github/build-tools.env"
  curl -fsSL -o "$W/Sparkle.tar.xz" \
    "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
  printf '%s  %s\n' "$SPARKLE_SHA256" "$W/Sparkle.tar.xz" | /usr/bin/shasum -a 256 -c -
  tar -xf "$W/Sparkle.tar.xz" -C "$W/tools"
  if [[ ${3:-} == local-ats ]]; then
    python3 - "$ROOT/Sources/Capsaicin/Info.plist" "$W/test-Info.plist" <<'PY'
import plistlib
import sys
from pathlib import Path
info = plistlib.loads(Path(sys.argv[1]).read_bytes())
info["NSAppTransportSecurity"] = {
    "NSExceptionDomains": {"127.0.0.1": {"NSExceptionAllowsInsecureHTTPLoads": True}}
}
Path(sys.argv[2]).write_bytes(plistlib.dumps(info))
PY
    INFO_ARGS=("INFOPLIST_FILE=$W/test-Info.plist")
  fi
  nix develop --command just gen
  for name in A B; do
    if [[ $name == A ]]; then
      version=0.9.0
      number=100
    else
      version=0.9.1
      number=101
    fi
    echo "Debug $name をビルドする（ログ: $W/build-$name.log）"
    build_app "$name" "$version" "$number" "http://127.0.0.1:$PORT/appcast.xml" "$(<"$W/public-key.txt")"
  done
  archive_app A current
  archive_app B good
  printf '%s\n' 'ローカル更新試験 A' >"$W/current/Capsaicin-A.md"
  printf '%s\n' 'ローカル更新試験 B' >"$W/good/Capsaicin-B.md"
  appcast current
  appcast good
  for name in tampered wrong-key wrong-feed unsigned; do
    mkdir "$W/$name"
    cp "$W/good/"{appcast.xml,Capsaicin-B.zip} "$W/$name/"
  done
  "$W/tools/bin/sign_update" --ed-key-file - -p "$W/good/Capsaicin-B.zip" \
    <"$W/keys/other-seed" >"$W/other-signature.txt"
  python3 - "$W" <<'PY'
import base64
import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

w = Path(sys.argv[1])
ns = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
block = rb"<!-- sparkle-signatures:\nedSignature: ([A-Za-z0-9+/]{86}==)\nlength: ([0-9]+)\n-->\n?\Z"
for name, version, number in [("A", "0.9.0", "100"), ("B", "0.9.1", "101")]:
    info = plistlib.loads((w / f"build-{name}/Build/Products/Debug/Capsaicin.app/Contents/Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == "io.github.koutyuke.capsaicin.debug"
    assert info["CFBundleShortVersionString"] == version and info["CFBundleVersion"] == number
    assert info["SUPublicEDKey"] == (w / "public-key.txt").read_text().strip()
    assert info["SUFeedURL"] == f"http://127.0.0.1:{(w / 'port').read_text().strip()}/appcast.xml"
    assert info["SUVerifyUpdateBeforeExtraction"] and info["SURequireSignedFeed"]
for name, archive in [("good", "B"), ("current", "A")]:
    data = (w / name / "appcast.xml").read_bytes()
    items = ET.fromstring(data).findall("./channel/item")
    assert len(items) == 1
    enclosure = items[0].find("enclosure")
    assert len(base64.b64decode(enclosure.get(ns + "edSignature"), validate=True)) == 64
    (w / name / "archive-signature.txt").write_text(enclosure.get(ns + "edSignature"))
    assert enclosure.get("url") == f"http://127.0.0.1:{(w / 'port').read_text().strip()}/Capsaicin-{archive}.zip"
    match = re.search(block, data)
    assert match and int(match[2]) == match.start()
original = (w / "good/Capsaicin-B.zip").read_bytes()
changed = bytearray(original)
changed[len(changed) // 2] ^= 1
(w / "tampered/Capsaicin-B.zip").write_bytes(changed)
assert len(original) == len(changed) and sum(a != b for a, b in zip(original, changed)) == 1
feed = (w / "good/appcast.xml").read_bytes()
unsigned = re.sub(block, b"", feed)
assert unsigned != feed and re.search(block, unsigned) is None
(w / "unsigned/appcast.xml").write_bytes(unsigned)
other = (w / "other-signature.txt").read_bytes().strip()
assert len(base64.b64decode(other, validate=True)) == 64
wrong = re.sub(rb'sparkle:edSignature="[^"]+"', b'sparkle:edSignature="' + other + b'"', unsigned)
assert wrong != unsigned
(w / "wrong-key/appcast.xml").write_bytes(wrong)
(w / "wrong-feed/appcast.xml").write_bytes(unsigned)
print("版、配信先、署名の構造、1バイトの改変を確認した")
PY
  # zip の鍵違いは、正しい鍵で feed を署名して zip の検証まで到達させる。
  "$W/tools/bin/sign_update" --ed-key-file - "$W/wrong-key/appcast.xml" <"$W/keys/seed"
  "$W/tools/bin/sign_update" --ed-key-file - "$W/wrong-feed/appcast.xml" <"$W/keys/other-seed"
  for name in good current wrong-key; do
    "$W/tools/bin/sign_update" --ed-key-file - --verify "$W/$name/appcast.xml" <"$W/keys/seed"
  done
  echo '以下の Error は、不正な feed と zip を拒否する想定どおりの出力である。'
  for name in wrong-feed unsigned; do
    if "$W/tools/bin/sign_update" --ed-key-file - --verify "$W/$name/appcast.xml" <"$W/keys/seed"; then
      fail "$name の feed が検証を通った"
    fi
  done
  for name in A B; do
    if [[ $name == A ]]; then kind=current; else kind=good; fi
    "$W/tools/bin/sign_update" --ed-key-file - --verify "$W/$kind/Capsaicin-$name.zip" \
      "$(<"$W/$kind/archive-signature.txt")" <"$W/keys/seed"
  done
  for name in tampered wrong-key; do
    if [[ $name == tampered ]]; then sig="$W/good/archive-signature.txt"; else sig="$W/other-signature.txt"; fi
    if "$W/tools/bin/sign_update" --ed-key-file - --verify "$W/$name/Capsaicin-B.zip" \
      "$(<"$sig")" <"$W/keys/seed"; then fail "$name の zip が検証を通った"; fi
  done
  cp "$W/current/Capsaicin-A.zip" "$W/public/"
  select_feed current
  echo "準備完了: W='$W'"
  ;;
disabled)
  workspace "${2:-}"
  nix develop --command just gen
  build_app disabled 0.9.0 100 '' ''
  echo "更新を無効にした Debug: $W/build-disabled/Build/Products/Debug/Capsaicin.app"
  ;;
feed)
  workspace "${2:-}"
  select_feed "${3:-}"
  ;;
serve)
  workspace "${2:-}"
  echo '停止は Ctrl-C。このターミナルを開いたままにする。鍵は配信しない。'
  exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$W/public"
  ;;
clean)
  workspace "${2:-}"
  command -v trash >/dev/null || fail 'trash がない'
  if /usr/sbin/lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null; then fail '先にサーバーを Ctrl-C で止める'; fi
  if /bin/ps -axo comm= | /usr/bin/grep '[C]apsaicin.app/Contents/MacOS/Capsaicin' >/dev/null; then fail '先にアプリを終了する'; fi
  # ゴミ箱にも seed の内容を残さない。媒体上の安全な消去を保証するものではない。
  for key in "$W/keys/seed" "$W/keys/other-seed"; do if [[ -f $key ]]; then : >"$key"; fi; done
  trash "$W"
  echo '作業先をゴミ箱へ移した。退避先 B とインストール先のアプリは変更していない。'
  ;;
*) usage ;;
esac
