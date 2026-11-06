"""利用者の別承認後だけ実行する、専用 plist 一件の配置・観測・撤去。"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

from prepare import identity, load_manifest


def checked_files(manifest):
    # 同名・同内容でも別 inode は拒否する。hard link による ctime 変化だけは許す。
    for key in ("plist", "binary"):
        if identity(Path(manifest[key])) != manifest[f"{key}_identity"]:
            raise ValueError(f"準備したファイルが変わっている: {key}")
    installed = Path(manifest["installed_plist"])
    for directory in (installed.parent, *installed.parent.parents):
        if directory.is_symlink() or not directory.is_dir():
            raise ValueError(f"配置先のディレクトリを照合できない: {directory}")
    present = []
    for key in ("installed_plist", "staged_plist"):
        path = Path(manifest[key])
        try:
            path.lstat()
        except FileNotFoundError:
            continue
        if identity(path) != manifest["plist_identity"]:
            raise ValueError(f"配置先のオブジェクトまたは内容が変わっている: {path}")
        present.append(path)
    return present


def command(runner, arguments):
    result = runner(
        arguments,
        capture_output=True,
        text=True,
        check=False,
        env={**os.environ, "LC_ALL": "C"},
    )
    print(f"$ {' '.join(arguments)}\n{result.stdout}{result.stderr}", end="")
    return result


def service(manifest, runner):
    target = f"gui/{manifest['uid']}/{manifest['label']}"
    result = command(runner, ["/bin/launchctl", "print", target])
    missing = (
        f'Could not find service "{manifest["label"]}" '
        f"in domain for user gui: {manifest['uid']}"
    )
    # 診断用出力は安定 API ではない。未知の文面・domain 不在・権限エラーは拒否する。
    if (
        result.returncode == 113
        and not result.stdout
        and result.stderr.strip() == missing
    ):
        return None
    if result.returncode != 0 or result.stderr:
        raise ValueError("ジョブの不在を確定できない。操作を中止する")
    lines = result.stdout.splitlines()
    if not lines or lines[0] != f"{target} = {{" or lines[-1] != "}":
        raise ValueError("未知の print 形式。操作を中止する")
    fields = {}
    seen = set()
    depth = 1
    # 対応形式はタブで階層を表す「key = {」・単独の「}」・括弧なしの値だけ。
    # 値中の括弧も曖昧なので拒否し、診断出力全般の文法は推測しない。
    for line in lines[1:-1]:
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip("\t"))
        content = line[indent:]
        if content == "}":
            if depth <= 1 or indent != depth - 1:
                raise ValueError("print の閉じ括弧または階層が不正")
            depth -= 1
            continue
        if indent != depth or not content or content[0].isspace():
            raise ValueError("print の字下げが不正")
        match = re.fullmatch(r"([A-Za-z0-9_][A-Za-z0-9_ .-]*) = (.*)", content)
        if depth == 1:
            if not match:
                raise ValueError("未知の print フィールド形式")
            key, value = match.groups()
            if key in seen:
                raise ValueError("print に重複フィールドがある")
            seen.add(key)
        if match and match[2] == "{":
            depth += 1
            continue
        if any(character in content for character in "{}\t"):
            raise ValueError("未知の print 構造")
        if depth == 1:
            fields[key] = value
    if depth != 1:
        raise ValueError("print のブロックが閉じていない")
    if (
        fields.get("program") != manifest["binary"]
        or fields.get("path") != manifest["installed_plist"]
    ):
        raise ValueError("ジョブの実行先または plist が一致しない")
    return fields


def install(path, *, runner=None):
    runner = runner or subprocess.run
    manifest = load_manifest(path)
    checked_files(manifest)
    if service(manifest, runner) is not None:
        raise ValueError("ジョブが既に登録されている")
    manifest = load_manifest(path)
    checked_files(manifest)
    installed = Path(manifest["installed_plist"])
    stage = Path(manifest["staged_plist"])
    # 完成済み plist の同一 inode を排他的に同じ配置ディレクトリへ置く。
    # EXDEV は中止。コピーへのフォールバックや既存 stage の再利用はしない。
    os.link(manifest["plist"], stage, follow_symlinks=False)
    manifest = load_manifest(path)
    checked_files(manifest)
    if service(manifest, runner) is not None:
        raise ValueError("公開前にジョブが登録された。中止する")
    manifest = load_manifest(path)
    checked_files(manifest)
    os.link(stage, installed, follow_symlinks=False)
    checked_files(manifest)
    print("配置完了。登録・起動は行っていない。stage は撤去まで残す。")


def cleanup(path, *, runner=None):
    runner = runner or subprocess.run
    manifest = load_manifest(path)
    present = checked_files(manifest)
    job = service(manifest, runner)
    if job is not None:
        if Path(manifest["installed_plist"]) not in present:
            raise ValueError("登録済みだが配置 plist がない。中止する")
        # 新しいシェルでも manifest から UID・オブジェクト・実行先を直前に再照合する。
        if service(manifest, runner) is not None:
            manifest = load_manifest(path)
            if checked_files(manifest) != present:
                raise ValueError("解除直前に配置対象が変わっている")
            command(
                runner,
                [
                    "/bin/launchctl",
                    "bootout",
                    f"gui/{manifest['uid']}/{manifest['label']}",
                ],
            )
        # bootout の成否だけでは削除しない。失敗でも確実に未登録なら自身の stage を回収する。
    manifest = load_manifest(path)
    checked_files(manifest)
    if service(manifest, runner) is not None:
        raise ValueError("ジョブが残っている。削除しない")
    remaining = present.copy()
    for candidate in (*present, Path(manifest["workspace"])):
        manifest = load_manifest(path)
        checked_files(manifest)
        if service(manifest, runner) is not None:
            raise ValueError("撤去直前にジョブが現れた。削除しない")
        manifest = load_manifest(path)
        current = checked_files(manifest)
        if current != remaining:
            raise ValueError("撤去対象が変わっている")
        result = command(runner, ["/usr/bin/trash", str(candidate)])
        if result.returncode != 0:
            raise ValueError(f"ゴミ箱への移動失敗。残存対象: {candidate}")
        if candidate.exists() or candidate.is_symlink():
            raise ValueError(f"ゴミ箱への移動を確認できない。残存対象: {candidate}")
        if candidate in remaining:
            remaining.remove(candidate)


def no_start_verdict(*, events_changed, pid, runs, termination, evidence_complete):
    if events_changed or pid is not None or (runs is not None and runs > 0):
        return "unexpected-start"
    if termination is not None and termination != "(never exited)":
        return "unexpected-start"
    if not evidence_complete or runs != 0 or termination is None:
        return "inconclusive"
    return "no-start-candidate"


def observe(path, *, relogin=False, runner=None):
    manifest = load_manifest(path)
    checked_files(manifest)
    job = service(manifest, runner or subprocess.run)
    if job is None:
        print("inconclusive: ジョブが存在しない")
        return "inconclusive"
    workspace = Path(manifest["workspace"])
    for name in (
        "events.log",
        "probe-stderr.log",
        *(("baseline.log",) if relogin else ()),
    ):
        identity(workspace / name)
    baseline = (workspace / "baseline.log").read_bytes() if relogin else b""
    events = (workspace / "events.log").read_bytes()
    errors = (workspace / "probe-stderr.log").read_bytes()
    runs = int(job["runs"]) if re.fullmatch(r"[0-9]+", job.get("runs", "")) else None
    termination = job.get("last exit code")
    spawn_error = job.get("last spawn error")
    if spawn_error not in (None, "0"):
        termination = f"exec failure: {spawn_error}"
    for key in ("last exec error", "last terminating signal"):
        if job.get(key) not in (None, "0"):
            termination = f"{key}: {job[key]}"
    verdict = no_start_verdict(
        events_changed=events != baseline or bool(errors),
        pid=job.get("pid"),
        runs=runs,
        termination=termination,
        evidence_complete=(job.get("state") == "not running" and spawn_error == "0"),
    )
    print(f"{verdict}: print 原文・時刻・ログも保存する。候補は成功判定ではない。")
    return verdict


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "cleanup", "observe"))
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--relogin", action="store_true")
    args = parser.parse_args()
    try:
        if args.action == "observe":
            verdict = observe(args.manifest, relogin=args.relogin)
            if verdict != "no-start-candidate":
                return 1
        elif args.relogin:
            raise ValueError("--relogin は observe 専用")
        else:
            {"install": install, "cleanup": cleanup}[args.action](args.manifest)
    except (OSError, ValueError, KeyError) as error:
        print(f"中止: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
