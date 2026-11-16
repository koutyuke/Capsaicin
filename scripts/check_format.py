"""treefmt の変更検出を一時コピー上で実行し、作業ツリーを変更しない。

String Catalog は Xcode が書き出す形を正とし、整形の代わりに stale のキーがないことを確かめる。
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def check_format(root):
    root = Path(root).resolve()
    files = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=root,
    )
    names = sorted(set(files.split(b"\0")) - {b""})
    stale = stale_strings(root, [Path(os.fsdecode(name)) for name in names])
    if stale:
        print(
            "Stale String Catalog keys found; set extractionState to manual "
            "for keys looked up dynamically, or remove unused keys.",
            file=sys.stderr,
        )
        print("\n".join(f"  {key}" for key in stale), file=sys.stderr)
    (root / ".build").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix="fmt-check-", dir=root / ".build"
    ) as temporary:
        for name in names:
            relative = Path(os.fsdecode(name))
            source = root / relative
            if source.is_file():
                destination = Path(temporary) / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                # 絶対パスの symlink 経由でも元のファイルを変更させない。
                shutil.copy2(source, destination)
        returncode = subprocess.run(
            ["treefmt", "--ci", "--walk", "filesystem"], cwd=temporary, check=False
        ).returncode
    return returncode or int(bool(stale))


def stale_strings(root, relatives):
    """Xcode が使われていないと判断して stale を付けたキーを「ファイル: キー」で返す。"""
    found = []
    for relative in relatives:
        if relative.suffix == ".xcstrings" and (root / relative).is_file():
            catalog = json.loads((root / relative).read_text(encoding="utf-8"))
            found += [
                f"{relative}: {key}"
                for key, entry in catalog["strings"].items()
                if entry.get("extractionState") == "stale"
            ]
    return found


if __name__ == "__main__":
    raise SystemExit(check_format(Path(__file__).resolve().parents[1]))
