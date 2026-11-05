"""treefmt の変更検出を一時コピー上で実行し、作業ツリーを変更しない。"""

import os
import shutil
import subprocess
import tempfile
from pathlib import Path


def check_format(root):
    root = Path(root).resolve()
    files = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=root,
    )
    (root / ".build").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix="fmt-check-", dir=root / ".build"
    ) as temporary:
        for name in sorted(set(files.split(b"\0")) - {b""}):
            relative = Path(os.fsdecode(name))
            source = root / relative
            if source.is_file():
                destination = Path(temporary) / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                # 絶対パスの symlink 経由でも元のファイルを変更させない。
                shutil.copy2(source, destination)
        return subprocess.run(
            ["treefmt", "--ci", "--walk", "filesystem"], cwd=temporary, check=False
        ).returncode


if __name__ == "__main__":
    raise SystemExit(check_format(Path(__file__).resolve().parents[1]))
