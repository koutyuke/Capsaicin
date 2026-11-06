#!/usr/bin/env bash
# 実機での確認（docs/manual/verification.md）をすぐ始めるための、オーナー専用の補助。
# アプリの起動とプロセスの停止を行うので、エージェントは実行しない（AGENTS.md）。
#
#   scripts/manual/verify.sh restart       動いている Debug アプリを止め、ビルドし、Finder と同じ経路で起動する
#   scripts/manual/verify.sh stop          動いている Debug アプリを止める
#   scripts/manual/verify.sh status        ジョブ、プロセス、SleepDisabled、アサーションを表示する
#   eval "$(scripts/manual/verify.sh env)" 手順書の変数（B、ID、JOB、PLIST、APP、CLI など）を今のシェルに入れる
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ID='io.github.koutyuke.capsaicin.debug'
APP="$ROOT/.build/xcode/Build/Products/Debug/Capsaicin.app"
EXE="$APP/Contents/MacOS/Capsaicin"
JOB="gui/$(id -u)/$ID"

# 1節で作った退避先のうち、いちばん新しいもの。まだなければ空にする。
backup_dir() {
  /bin/ls -dt "$HOME"/Capsaicin-verification.* 2>/dev/null | /usr/bin/head -n 1 || true
}

pids() {
  /usr/bin/pgrep -fx "$EXE" || true
}

print_env() {
  cat <<EOF
ROOT='$ROOT'
B='$(backup_dir)'
ID='$ID'
JOB='$JOB'
PLIST="\$HOME/Library/LaunchAgents/\$ID.plist"
RECORD="\$HOME/Library/Application Support/\$ID/resume-record.json"
APP='$APP'
CLI="\$APP/Contents/Helpers/capsaicin"
HELPER='/Library/PrivilegedHelperTools/io.github.koutyuke.capsaicin.helper.debug'
RULE='/etc/sudoers.d/capsaicin_debug'
DAEMON='/Library/LaunchDaemons/io.github.koutyuke.capsaicin.helper.debug.plist'
EOF
}

wait_until_stopped() {
  local seconds="$1"
  for _ in $(seq "$seconds"); do
    [ -z "$(pids)" ] && return 0
    sleep 1
  done
  [ -z "$(pids)" ]
}

stop_app() {
  [ -z "$(pids)" ] && {
    echo '動いている Debug アプリはない。'
    return 0
  }
  # quit の Apple Event は「終了理由を判定できない」終了になり、抑止を停止中の状態に戻してから終わる。
  /usr/bin/osascript -e "tell application id \"$ID\" to quit" >/dev/null 2>&1 || true
  wait_until_stopped 10 && {
    echo 'Debug アプリを終了した。'
    return 0
  }
  # 応答しないもの（引き渡しの途中で止まった古いビルドなど）だけを SIGTERM で止める。
  # SIGTERM はクラッシュではないので、launchd は再起動しない（EVID-LCY-001）。後片付けは通らない。
  echo "応答しないので SIGTERM を送る: $(pids | /usr/bin/tr '\n' ' ')"
  pids | /usr/bin/xargs kill -TERM
  wait_until_stopped 5 || {
    echo "まだ動いている: $(pids | /usr/bin/tr '\n' ' ')。手で確かめる。" >&2
    return 1
  }
}

status() {
  echo '--- launchd のジョブ'
  /bin/launchctl print "$JOB" 2>&1 | /usr/bin/grep -E '^\s*(state|pid|runs|last exit code) =' || echo '読み込まれていない'
  echo '--- Debug アプリのプロセス'
  /bin/ps -o pid=,lstart= -p "$(pids | /usr/bin/paste -sd, -)" 2>/dev/null || echo 'なし'
  echo '--- SleepDisabled'
  /usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" {print $2}'
  echo '--- Capsaicin のアサーション'
  /usr/bin/pmset -g assertions | /usr/bin/grep -i capsaicin || echo 'なし'
}

case "${1:-}" in
env) print_env ;;
stop) stop_app ;;
status) status ;;
restart)
  stop_app
  (cd "$ROOT" && nix develop --command just build)
  # open は Finder のダブルクリックと同じ LaunchServices の経路で起動する。
  /usr/bin/open "$APP"
  sleep 3
  status
  ;;
*)
  /usr/bin/sed -n '5,8p' "$0" | /usr/bin/sed 's/^# \{0,1\}//'
  exit 64
  ;;
esac
