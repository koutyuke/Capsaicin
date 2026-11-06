"""登録も起動も行わない、専用 LaunchAgent 実験の準備。"""

import argparse
import hashlib
import json
import os
import plistlib
import re
import shlex
import stat
import subprocess
import sys
import uuid
from pathlib import Path

PREFIX = "io.github.koutyuke.capsaicin.debug.launchagent-probe."
HERE = Path(__file__).resolve().parent


def write_new(path, content):
    with path.open("x", encoding="utf-8") as output:
        output.write(content)


def identity(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
        raise ValueError(f"自分の通常ファイルではない: {path}")
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), "rb") as source:
        opened = os.fstat(source.fileno())
        digest = hashlib.file_digest(source, "sha256").hexdigest()
        finished = os.fstat(source.fileno())
    attributes = (
        "st_dev",
        "st_ino",
        "st_uid",
        "st_mode",
        "st_size",
        "st_mtime_ns",
        "st_ctime_ns",
    )
    for current in (opened, finished, path.lstat()):
        if any(getattr(current, key) != getattr(info, key) for key in attributes):
            raise ValueError(f"照合中にファイルが変わった: {path}")
    return {
        "device": info.st_dev,
        "inode": info.st_ino,
        "uid": info.st_uid,
        "mode": info.st_mode,
        "size": info.st_size,
        "mtime_ns": info.st_mtime_ns,
        "sha256": digest,
    }


def prepare(root, *, runner=None):
    if runner is None:
        runner = subprocess.run
    root = root.resolve(strict=True)
    parent = root
    for component in (".build", "manual"):
        parent = parent / component
        if parent.is_symlink():
            raise ValueError(f"symlink は使わない: {parent}")
        parent.mkdir(exist_ok=True)
    token = uuid.uuid4().hex
    workspace = parent / f"launchagent-probe-{token}"
    workspace.mkdir(mode=0o700)
    # 失敗しても既存物を削除しない。部分生成物はこの専用領域に残す。
    try:
        label = PREFIX + token
        binary = workspace / "probe"
        plist = workspace / f"{label}.plist"
        installed = Path.home() / "Library" / "LaunchAgents" / plist.name
        write_new(workspace / "events.log", "")
        write_new(workspace / "probe-stderr.log", "")
        write_new(workspace / "probe.c", (HERE / "probe.c").read_text())
        write_new(
            workspace / "config.h",
            f"#define PROBE_LABEL {json.dumps(label)}\n"
            f"#define PROBE_WORKSPACE {json.dumps(str(workspace), ensure_ascii=False)}\n",
        )
        runner(
            [
                "/usr/bin/xcrun",
                "--sdk",
                "macosx",
                "clang",
                "-std=c11",
                "-Wall",
                "-Wextra",
                "-Werror",
                str(workspace / "probe.c"),
                "-o",
                str(binary),
            ],
            check=True,
        )
        runner(["/usr/bin/codesign", "--sign", "-", str(binary)], check=True)
        job = {
            "Label": label,
            "ProgramArguments": [str(binary)],
            "RunAtLoad": False,
            "KeepAlive": {"Crashed": True},
            "WorkingDirectory": str(workspace),
            "StandardErrorPath": str(workspace / "probe-stderr.log"),
        }
        with plist.open("xb") as output:
            plistlib.dump(job, output)
            output.flush()
            os.fsync(output.fileno())
        workspace_info = workspace.stat()
        manifest = {
            "label": label,
            "workspace": str(workspace),
            "binary": str(binary),
            "plist": str(plist),
            "installed_plist": str(installed),
            "staged_plist": str(installed.with_name(f".{label}.staging")),
            "uid": os.getuid(),
            "format": "plain-executable-ad-hoc",
            "lifetime_seconds": 900,
            "plist_identity": identity(plist),
            "binary_identity": identity(binary),
            "workspace_identity": [workspace_info.st_dev, workspace_info.st_ino],
        }
        write_new(workspace / "instructions.md", instructions(manifest, root))
        write_new(workspace / "manifest.json", json.dumps(manifest, indent=2) + "\n")
        return workspace
    except Exception as error:
        raise RuntimeError(
            f"準備失敗。未完了の専用領域を残した: {workspace}"
        ) from error


def load_manifest(path):
    if os.getuid() != os.geteuid():
        raise ValueError("実 UID と実効 UID が一致しない")
    path = path.absolute()
    workspace = path.parent
    if path.name != "manifest.json" or path.is_symlink():
        raise ValueError("専用 manifest.json だけを使う")
    if any(parent.is_symlink() for parent in (workspace, *workspace.parents)):
        raise ValueError("symlink は使わない")
    manifest = json.loads(path.read_text())
    token = workspace.name.removeprefix("launchagent-probe-")
    if not re.fullmatch(r"[0-9a-f]{32}", token):
        raise ValueError("専用作業領域ではない")
    if workspace.parent.name != "manual" or workspace.parent.parent.name != ".build":
        raise ValueError(".build/manual の外は使わない")
    label = PREFIX + token
    expected = {
        "workspace": str(workspace),
        "label": label,
        "binary": str(workspace / "probe"),
        "plist": str(workspace / f"{label}.plist"),
        "installed_plist": str(
            Path.home() / "Library" / "LaunchAgents" / f"{label}.plist"
        ),
        "staged_plist": str(
            Path.home() / "Library" / "LaunchAgents" / f".{label}.staging"
        ),
        "uid": os.getuid(),
    }
    if any(manifest.get(key) != value for key, value in expected.items()):
        raise ValueError("manifest と専用領域が一致しない")
    if workspace.stat().st_uid != os.getuid() or workspace.stat().st_mode & 0o077:
        raise ValueError("作業領域は自分だけが使える権限にする")
    info = workspace.stat()
    if manifest.get("workspace_identity") != [info.st_dev, info.st_ino]:
        raise ValueError("作業領域のオブジェクトが変わっている")
    return manifest


def control(path, action):
    if action not in ("exit", "crash"):
        raise ValueError("exit または crash だけを許可する")
    manifest = load_manifest(path)
    workspace = Path(manifest["workspace"])
    log = workspace / "events.log"
    if log.is_symlink():
        raise ValueError("ログの symlink は使わない")
    lines = log.read_text().splitlines()
    if not lines:
        raise ValueError("起動記録がない")
    fields = lines[-1].split()
    if (
        len(fields) != 5
        or fields[3] != manifest["label"]
        or fields[4] != "start"
        or not re.fullmatch(r"[0-9a-f]{32}", fields[2])
    ):
        raise ValueError("最後の記録が専用プローブの start ではない")
    if action == "crash" and (workspace / "crash-used").exists():
        raise ValueError("この作業領域では自己クラッシュを使用済み")
    write_new(workspace / f"{action}-{fields[2]}", "")


def instructions(manifest, root):
    q = shlex.quote
    workspace = Path(manifest["workspace"])
    target = f"gui/{manifest['uid']}/{manifest['label']}"
    domain = f"gui/{manifest['uid']}"
    plist = manifest["plist"]
    installed = manifest["installed_plist"]
    log = str(workspace / "events.log")
    controller = (
        f"nix develop {q(str(root))} --command python3 {q(str(HERE / 'prepare.py'))} "
        f"control {q(str(workspace / 'manifest.json'))}"
    )
    manual = (
        f"nix develop {q(str(root))} --command python3 {q(str(HERE / 'operations.py'))}"
    )
    values = {
        "TARGET": q(target),
        "DOMAIN": q(domain),
        "PLIST": q(plist),
        "INSTALLED": q(installed),
        "INSTALL_DIR": q(str(Path(installed).parent)),
        "WORKSPACE": q(str(workspace)),
        "LOG": q(log),
        "CONTROL": controller,
        "UID": str(manifest["uid"]),
        "MANIFEST": q(str(workspace / "manifest.json")),
        "MANUAL": manual,
    }
    text = (HERE / "procedure.md").read_text()
    for key, value in values.items():
        text = text.replace(f"@@{key}@@", value)
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("prepare")
    request = sub.add_parser("control")
    request.add_argument("manifest", type=Path)
    request.add_argument("action", choices=("exit", "crash"))
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            print(prepare(HERE.parents[2]))
        else:
            control(args.manifest, args.action)
    except (OSError, ValueError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
