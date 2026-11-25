"""GitHub へ接続せずにコメントの本文と更新対象を確かめる。"""

import json
import os
import unittest
from unittest.mock import patch

from scripts import preview_comment as comment


class PreviewCommentTests(unittest.TestCase):
    def test_states_and_kinds(self):
        for kind in ("debug", "release"):
            for state in ("building", "ready", "failed"):
                with self.subTest(kind=kind, state=state):
                    body = comment.render(
                        kind,
                        state,
                        "abc1234" + "0" * 33,
                        "commit-url",
                        "run-url",
                        "artifact-url",
                        "Capsaicin-1.2.3.dmg",
                        "1.2.3",
                        "2026-11-25",
                    )
                    self.assertTrue(body.startswith(comment.marker(kind) + "\n### "))
                    self.assertIn(f"{kind.title()} preview · {state}", body)
                    if state == "ready":
                        build = (
                            "Debug · `io.github.koutyuke.capsaicin.debug`"
                            if kind == "debug"
                            else "Release 1.2.3"
                        )
                        for row in (
                            "| **Download** | [Capsaicin-1.2.3.dmg](artifact-url) |",
                            "| **Commit** | [`abc1234`](commit-url) |",
                            f"| **Build** | {build} |",
                            "| **Signing** | Developer ID · notarized · stapled |",
                            "| **Expires** | 2026-11-25 (7 days) |",
                        ):
                            self.assertIn(row, body)
                    else:
                        self.assertNotIn("Download", body)

    def test_only_bot_comment_with_leading_marker_is_updated(self):
        def entry(user, body, identifier):
            return {"user": {"login": user}, "body": body, "id": identifier}

        pages = [
            [
                entry("someone", comment.marker("debug"), 1),
                entry("github-actions[bot]", "text " + comment.marker("debug"), 2),
            ],
            [
                entry("github-actions[bot]", comment.marker("release"), 3),
                entry("github-actions[bot]", comment.marker("debug"), 4),
            ],
        ]
        self.assertEqual(comment.find_comment(pages, "debug")["id"], 4)
        self.assertEqual(comment.find_comment(pages, "release")["id"], 3)
        legacy = entry(
            "github-actions[bot]", "<!-- capsaicin-release-preview -->\nold", 5
        )
        self.assertIsNone(comment.find_comment([[legacy]], "release"))
        self.assertIsNone(comment.find_comment([[legacy]], "debug"))

    def test_outdated_head_does_not_write(self):
        env = {
            "GITHUB_EVENT_PATH": "unused.json",
            "GITHUB_REPOSITORY": "owner/repo",
            "PREVIEW_KIND": "debug",
            "PREVIEW_STATE": "building",
        }
        event = {"number": 7, "pull_request": {"head": {"sha": "abc1234"}}}
        with (
            patch.dict(os.environ, env),
            patch.object(comment.Path, "read_text", return_value=json.dumps(event)),
            patch.object(
                comment, "api", return_value={"head": {"sha": "new-sha"}}
            ) as api,
        ):
            comment.main()
            api.assert_called_once_with("repos/owner/repo/pulls/7")

    def test_ready_preview_links_the_package_from_environment(self):
        package_name = "Capsaicin-debug-pr7-abc1234.dmg"
        env = {
            "GITHUB_EVENT_PATH": "unused.json",
            "GITHUB_REPOSITORY": "owner/repo",
            "GITHUB_RUN_ID": "42",
            "GITHUB_SERVER_URL": "https://github.com",
            "PREVIEW_KIND": "debug",
            "PREVIEW_STATE": "ready",
            "ARTIFACT_URL": "artifact-url",
            "PACKAGE_NAME": package_name,
        }
        head = {"sha": "abc1234" + "0" * 33}
        event = {"number": 7, "pull_request": {"head": head}}
        with (
            patch.dict(os.environ, env, clear=True),
            patch.object(comment.Path, "read_text", return_value=json.dumps(event)),
            patch.object(comment, "api", side_effect=[{"head": head}, [], {}]) as api,
        ):
            comment.main()
            self.assertIn(f"[{package_name}](artifact-url)", api.call_args.args[-1])


if __name__ == "__main__":
    unittest.main()
