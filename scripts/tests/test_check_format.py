"""整形検査が入力を変更せず、formatter の失敗をそのまま返すことを確かめる。"""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from scripts.check_format import check_format


class CheckFormatTests(unittest.TestCase):
    def test_real_formatter_rejects_swift_and_json_without_changing_sources(self):
        project = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory(dir=project / ".build") as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "--quiet", str(root)], check=True)
            (root / ".gitignore").write_text(".build/\n")
            for name in ["flake.nix", ".swiftformat", ".prettierrc.json"]:
                shutil.copy2(project / name, root / name)
            swift = root / "Sample.swift"
            json = root / "sample.json"
            swift.write_text("struct Sample {\n    let value = 1\n}\n")
            json.write_text('{\n  "value": 1\n}\n')
            self.assertEqual(check_format(root), 0)
            for path, malformed in [
                (swift, "struct Sample{let value=1}\n"),
                (json, '{"value":1}\n'),
            ]:
                with self.subTest(language=path.suffix):
                    formatted = path.read_text()
                    path.write_text(malformed)
                    try:
                        self.assertNotEqual(check_format(root), 0)
                        self.assertEqual(path.read_text(), malformed)
                    finally:
                        path.write_text(formatted)

    def test_formatter_only_changes_temporary_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "flake.nix"
            source.write_text("{ a=1;}\n")
            (root / "AGENTS.md").write_text("# AGENTS\n")
            (root / "CLAUDE.md").symlink_to("AGENTS.md")
            (root / "EXTERNAL.md").symlink_to(root / "AGENTS.md")
            copies = []

            def format_copy(command, *, cwd, check):
                self.assertEqual(command, ["treefmt", "--ci", "--walk", "filesystem"])
                copy = Path(cwd)
                copies.append(copy)
                self.assertEqual((copy / "flake.nix").read_text(), source.read_text())
                (copy / "flake.nix").write_text("{ a = 1; }\n")
                (copy / "EXTERNAL.md").write_text(
                    "元のリンク先を変更してはならない。\n"
                )
                return SimpleNamespace(returncode=1)

            files = b"flake.nix\0AGENTS.md\0CLAUDE.md\0EXTERNAL.md\0deleted.nix\0flake.nix\0"
            with (
                patch(
                    "scripts.check_format.subprocess.check_output", return_value=files
                ),
                patch("scripts.check_format.subprocess.run", side_effect=format_copy),
            ):
                self.assertEqual(check_format(root), 1)
            self.assertEqual(source.read_text(), "{ a=1;}\n")
            self.assertEqual((root / "AGENTS.md").read_text(), "# AGENTS\n")
            self.assertFalse(copies[0].exists())

    def test_stale_string_catalog_keys_fail_even_when_formatter_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            catalog = root / "Sample.xcstrings"
            files = b"Sample.xcstrings\0"
            for state, expected in [("manual", 0), ("stale", 1)]:
                with self.subTest(state=state):
                    catalog.write_text(
                        '{"strings": {"used": {}, "key": {"extractionState": "%s"}}}'
                        % state
                    )
                    with (
                        patch(
                            "scripts.check_format.subprocess.check_output",
                            return_value=files,
                        ),
                        patch(
                            "scripts.check_format.subprocess.run",
                            return_value=SimpleNamespace(returncode=0),
                        ),
                    ):
                        self.assertEqual(check_format(root), expected)


if __name__ == "__main__":
    unittest.main()
