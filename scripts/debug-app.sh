#!/usr/bin/env bash
# justfile の app レシピが読み込む。

# 単一インスタンスの判定と同じ API で探す。終了要求は bundle ID で開かず、各プロセスに直接送る。
debug_processes() {
  /usr/bin/osascript -l JavaScript - "${1:-list}" <<'JXA'
ObjC.import('AppKit');

function run(argv) {
    const apps = $.NSRunningApplication.runningApplicationsWithBundleIdentifier('io.github.koutyuke.capsaicin.debug');
    const rows = [];
    for (let i = 0; i < apps.count; i++) {
        const app = apps.objectAtIndex(i);
        const pid = app.processIdentifier;
        if (pid <= 0 || app.terminated) continue;
        const url = app.executableURL;
        const path = url.isNil() ? '' : ObjC.unwrap(url.path);
        if (argv[0] === 'quit') app.terminate;
        rows.push(pid + '\t' + path);
    }
    return rows.join('\n');
}
JXA
}
