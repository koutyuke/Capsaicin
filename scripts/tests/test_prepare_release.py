"""リリース準備の判定と、一時 Git リポジトリでの流れを確かめる。"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from scripts.prepare_release import (
    classify_labels,
    next_version,
    pull_request_numbers,
    update_project,
)

PROJECT = 'settings:\n  MARKETING_VERSION: "0.3.0"\n  CURRENT_PROJECT_VERSION: "7"\n'
SCRIPT = Path(__file__).resolve().parents[1] / "prepare_release.py"


class PureFunctionsTests(unittest.TestCase):
    def test_next_version(self):
        self.assertEqual(next_version("1.2.3", "major"), "2.0.0")
        self.assertEqual(next_version("1.2.3", "minor"), "1.3.0")
        self.assertEqual(next_version("1.2.3", "patch"), "1.2.4")

    def test_pull_request_numbers(self):
        subjects = [
            "Merge pull request #12 from owner/feature",
            "Merge branch 'main' into develop",
            "Merge pull request #34 from owner/fix",
        ]
        self.assertEqual(pull_request_numbers(subjects), [12, 34])

    def test_classify_labels(self):
        self.assertEqual(
            classify_labels(["T-Feature", "I-Breaking"]), ("T-Feature", True)
        )
        for labels in ([], ["A-App"], ["T-Bug", "T-Test"]):
            with self.subTest(labels=labels), self.assertRaises(ValueError):
                classify_labels(labels)

    def test_update_project(self):
        current, updated = update_project(PROJECT, "0.4.0")
        self.assertEqual(current, "0.3.0")
        self.assertIn('MARKETING_VERSION: "0.4.0"', updated)
        self.assertIn('CURRENT_PROJECT_VERSION: "8"', updated)
        for text in (
            PROJECT.replace("MARKETING_VERSION", "OTHER_VERSION"),
            PROJECT + '  MARKETING_VERSION: "9.9.9"\n',
        ):
            with self.subTest(text=text), self.assertRaises(ValueError):
                update_project(text, "0.4.0")


class ReleaseFlowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.remote = self.root / "origin.git"
        self.repo = self.root / "repo"
        self.bin = self.root / "bin"
        self.execute("git", "init", "--bare", str(self.remote), cwd=self.root)
        self.execute("git", "init", "-b", "main", str(self.repo), cwd=self.root)
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release@example.com")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "tag.gpgsign", "false")
        self.git("remote", "add", "origin", str(self.remote))
        # 書き出した材料で作業ツリーが汚れないよう、リポジトリと同じく .build を無視する。
        (self.repo / ".git/info/exclude").write_text(".build/\n", encoding="utf-8")
        (self.repo / "project.yml").write_text(PROJECT, encoding="utf-8")
        self.git("add", "project.yml")
        self.git("commit", "-m", "Initial release")
        self.git("tag", "v0.3.0")
        self.git("push", "-u", "origin", "main", "--tags")

    def execute(self, *args, cwd=None, env=None, check=True):
        return subprocess.run(
            args,
            cwd=cwd or self.repo,
            env=env,
            check=check,
            capture_output=True,
            text=True,
            timeout=20,
        )

    def git(self, *args):
        return self.execute("git", *args).stdout.strip()

    def install_fake_gh(self, *labels):
        self.bin.mkdir()
        executable = self.bin / "gh"
        names = labels or ("T-Feature", "A-App")
        pull_request = {
            "number": 12,
            "title": "Add feature",
            "url": "https://example.test/pull/12",
            "labels": [{"name": name} for name in names],
        }
        executable.write_text(
            f"#!{sys.executable}\nprint({json.dumps(json.dumps(pull_request))})\n",
            encoding="utf-8",
        )
        executable.chmod(0o755)

    def merge_pull_request(self, *labels):
        """develop に PR #12 をマージした状態を作り、origin に push する。"""
        self.git("switch", "-c", "develop")
        self.git("switch", "-c", "feature")
        (self.repo / "feature.txt").write_text("feature\n", encoding="utf-8")
        self.git("add", "feature.txt")
        self.git("commit", "-m", "Add feature")
        self.git("switch", "develop")
        self.git(
            "merge",
            "--no-ff",
            "feature",
            "-m",
            "Merge pull request #12 from owner/feature",
        )
        self.git("push", "-u", "origin", "develop")
        self.install_fake_gh(*labels)

    def commit_hotfix(self):
        self.git("switch", "-c", "hotfix/crash")
        (self.repo / "fix.txt").write_text("fix\n", encoding="utf-8")
        self.git("add", "fix.txt")
        self.git("commit", "-m", "Fix crash")

    def assert_error(self, result, message):
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, message)

    def prepare(self, *args):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin}:{env['PATH']}"
        return self.execute(sys.executable, str(SCRIPT), *args, env=env, check=False)

    def read_material(self, version):
        path = self.repo / ".build/release" / f"v{version}.json"
        return json.loads(path.read_text(encoding="utf-8"))

    def test_normal_release_flow(self):
        self.merge_pull_request()

        result = self.prepare("minor")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout, "Version: 0.4.0\nMaterials: .build/release/v0.4.0.json\n"
        )
        self.assertEqual(result.stderr, "")
        self.assertEqual(self.git("branch", "--show-current"), "release/v0.4.0")
        self.assertEqual(self.git("log", "-1", "--format=%s"), "Release v0.4.0")
        self.assertEqual(
            self.git("show", "--format=", "--name-only", "HEAD"), "project.yml"
        )
        material = self.read_material("0.4.0")
        self.assertEqual(material["version"], "0.4.0")
        self.assertEqual(material["previous_tag"], "v0.3.0")
        self.assertEqual(material["kind"], "minor")
        self.assertEqual(material["branch"], "release/v0.4.0")
        self.assertEqual(material["pull_requests"][0]["number"], 12)
        self.assertEqual(material["commits"], [])
        self.assertIn(
            'CURRENT_PROJECT_VERSION: "8"', (self.repo / "project.yml").read_text()
        )

    def test_hotfix_release_flow(self):
        self.commit_hotfix()

        result = self.prepare("patch")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout, "Version: 0.3.1\nMaterials: .build/release/v0.3.1.json\n"
        )
        self.assertEqual(result.stderr, "")
        self.assertEqual(self.git("branch", "--show-current"), "hotfix/crash")
        self.assertEqual(self.git("log", "-1", "--format=%s"), "Release v0.3.1")
        material = self.read_material("0.3.1")
        self.assertEqual(material["kind"], "patch")
        self.assertEqual(material["pull_requests"], [])
        self.assertEqual(material["commits"][0]["subject"], "Fix crash")
        self.assertEqual(len(material["commits"][0]["sha"]), 40)

    def test_develop_major_and_patch_releases(self):
        self.merge_pull_request()

        for kind, version in (("major", "1.0.0"), ("patch", "0.3.1")):
            with self.subTest(kind=kind):
                result = self.prepare(kind)

                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    self.git("branch", "--show-current"), f"release/v{version}"
                )
                self.assertEqual(self.read_material(version)["kind"], kind)
                self.git("switch", "develop")
                self.git("branch", "-D", f"release/v{version}")

    def test_patch_release_rejects_breaking_pull_requests(self):
        self.merge_pull_request("T-Feature", "I-Breaking")

        result = self.prepare("patch")

        self.assert_error(
            result,
            "error: A patch release cannot include I-Breaking PRs: #12.\n"
            "hint: Run with minor or major.\n",
        )
        self.assertEqual(self.git("branch", "--show-current"), "develop")

    def test_patch_releases_do_not_overlap(self):
        self.merge_pull_request()
        self.git("branch", "hotfix/crash", "main")

        result = self.prepare("patch")

        self.assert_error(
            result,
            "error: A hotfix/* branch exists.\n"
            "hint: Complete or remove the hotfix, then try again.\n",
        )

        self.git("branch", "-D", "hotfix/crash")
        self.assertEqual(self.prepare("patch").returncode, 0)
        self.git("switch", "main")
        self.commit_hotfix()

        result = self.prepare("patch")

        self.assert_error(
            result,
            "error: release/v0.3.1 already exists.\n"
            "hint: Complete or remove that release, then try again.\n",
        )

    def test_hotfix_accepts_only_patch(self):
        self.commit_hotfix()

        result = self.prepare("minor")

        self.assert_error(
            result,
            "error: A hotfix/* branch can only make a patch release.\n"
            "hint: Run with patch, or release from develop.\n",
        )

    def test_kind_is_required(self):
        for args in ((), ("release",), ("minor", "patch")):
            with self.subTest(args=args):
                result = self.prepare(*args)

                self.assertEqual(result.returncode, 1)
                self.assertTrue(result.stderr.startswith("usage: "))

    def test_dirty_worktree_reports_error_and_hint(self):
        (self.repo / "project.yml").write_text(PROJECT + "# dirty\n", encoding="utf-8")

        result = self.prepare("minor")

        self.assert_error(
            result,
            "error: The working tree has changes.\n"
            "hint: Commit or stash the changes, then try again.\n",
        )


if __name__ == "__main__":
    unittest.main()
