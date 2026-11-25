"""確認用ビルドのコメントを gh api で作成・更新する。"""

import json
import os
import subprocess
from datetime import UTC, datetime, timedelta
from pathlib import Path


def marker(kind):
    if kind not in {"debug", "release"}:
        raise ValueError("Unknown preview kind")
    return f"<!-- capsaicin-preview:{kind} -->"


def find_comment(pages, kind):
    prefix = marker(kind)
    return next(
        (
            comment
            for page in pages
            for comment in page
            if comment["user"]["login"] == "github-actions[bot]"
            and comment["body"].startswith(prefix)
        ),
        None,
    )


def render(
    kind,
    state,
    sha,
    commit_url,
    run_url,
    artifact_url="",
    package_name="",
    version="",
    expires_on="",
):
    title = f"{kind.title()} preview"
    commit = f"[`{sha[:7]}`]({commit_url})"
    prefix = f"{marker(kind)}\n"
    if state == "building":
        return f"{prefix}### 🔨 {title} · building\n\nBuilding {commit} — [view run]({run_url})"
    if state == "failed":
        return f"{prefix}### ❌ {title} · failed\n\nThe build for {commit} failed. [View run]({run_url})"
    if state != "ready" or not artifact_url or not package_name or not expires_on:
        raise ValueError(
            "A ready preview requires its artifact URL, package name, and expiration"
        )
    build = (
        "Debug · `io.github.koutyuke.capsaicin.debug`"
        if kind == "debug"
        else f"Release {version}"
    )
    note = (
        "Installs alongside the release app. Updates through Sparkle are disabled in this build."
        if kind == "debug"
        else "Replaces an installed release app."
    )
    return (
        f"{prefix}### ✅ {title} · ready\n\n"
        "| | |\n| --- | --- |\n"
        f"| **Download** | [{package_name}]({artifact_url}) |\n"
        f"| **Commit** | {commit} |\n"
        f"| **Build** | {build} |\n"
        "| **Signing** | Developer ID · notarized · stapled |\n"
        f"| **Expires** | {expires_on} (7 days) |\n\n"
        f"> {note}\n\n[View run]({run_url})"
    )


def api(*args):
    return json.loads(subprocess.check_output(["gh", "api", *args], text=True))


def main():
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    repo = os.environ["GITHUB_REPOSITORY"]
    number = event["number"]
    sha = event["pull_request"]["head"]["sha"]
    kind = os.environ["PREVIEW_KIND"]
    state = os.environ["PREVIEW_STATE"]
    # 古いコミットの再実行でも、新しいコミットの状態を上書きしない。
    if api(f"repos/{repo}/pulls/{number}")["head"]["sha"] != sha:
        print("Skipping preview comment for an outdated commit")
        return
    pages = api(
        "--paginate", "--slurp", f"repos/{repo}/issues/{number}/comments?per_page=100"
    )
    comment = find_comment(pages, kind)
    server = os.environ["GITHUB_SERVER_URL"]
    body = render(
        kind,
        state,
        sha,
        f"{server}/{repo}/commit/{sha}",
        f"{server}/{repo}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
        os.environ.get("ARTIFACT_URL", ""),
        os.environ.get("PACKAGE_NAME", ""),
        os.environ.get("VERSION", ""),
        (datetime.now(UTC) + timedelta(days=7)).date().isoformat(),
    )
    if comment:
        api(
            "--method",
            "PATCH",
            f"repos/{repo}/issues/comments/{comment['id']}",
            "-f",
            f"body={body}",
        )
    else:
        api(
            "--method",
            "POST",
            f"repos/{repo}/issues/{number}/comments",
            "-f",
            f"body={body}",
        )


if __name__ == "__main__":
    main()
