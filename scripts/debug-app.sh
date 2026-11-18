#!/usr/bin/env bash
# justfile の app レシピが読み込む。agent から起動したアプリはコマンドラインが相対パスになるので、
# Debug のプロセスは PID から引いた実行ファイルの絶対パスで見つける（DEC-SYS-025）。

executable_path() {
  /usr/sbin/lsof -a -p "$1" -d txt -Fn 2>/dev/null | /usr/bin/awk '/^n/ && !found {print substr($0, 2); found = 1}'
}

# どのチェックアウトの手元の Debug ビルドにも一致する。/Applications の PR ビルドと Release は含めない。
debug_pids() {
  local pid path
  for pid in $(/usr/bin/pgrep -x Capsaicin || true); do
    path="$(executable_path "$pid")" || continue
    case "$path" in
    /*/.build/xcode/Build/Products/Debug/Capsaicin.app/Contents/MacOS/Capsaicin) printf '%s\n' "$pid" ;;
    esac
  done
}
