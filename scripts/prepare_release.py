"""リリースの版を決め、ブランチ、コミット、リリース材料を手元に作る。"""

import json
import re
import subprocess
import sys
from pathlib import Path

VERSION_TAG = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
MERGE_SUBJECT = re.compile(r"^Merge pull request #(\d+) from ")
VERSION_LINE = re.compile(
    r'^([ \t]*MARKETING_VERSION:[ \t]*)["\']?([^"\'\s]+)["\']?[ \t]*$', re.MULTILINE
)
BUILD_LINE = re.compile(
    r'^([ \t]*CURRENT_PROJECT_VERSION:[ \t]*)["\']?(\d+)["\']?[ \t]*$', re.MULTILINE
)


class ReleaseError(Exception):
    """利用者が直せる理由で準備を止める。"""


def next_version(version, kind):
    major, minor, patch = map(int, version.split("."))
    if kind == "major":
        return f"{major + 1}.0.0"
    if kind == "minor":
        return f"{major}.{minor + 1}.0"
    return f"{major}.{minor}.{patch + 1}"


def release_kind(version, pull_requests):
    breaking = any(item["breaking"] for item in pull_requests)
    return "major" if breaking and int(version.split(".")[0]) else "minor"


def pull_request_numbers(subjects):
    return [
        int(match[1]) for subject in subjects if (match := MERGE_SUBJECT.match(subject))
    ]


def classify_labels(labels):
    types = [label for label in labels if label.startswith("T-")]
    if len(types) != 1:
        raise ValueError("Expected exactly one type label.")
    return types[0], "I-Breaking" in labels


def update_project(text, version):
    versions = list(VERSION_LINE.finditer(text))
    builds = list(BUILD_LINE.finditer(text))
    if len(versions) != 1 or len(builds) != 1:
        raise ValueError(
            "Expected one line each for MARKETING_VERSION and CURRENT_PROJECT_VERSION."
        )
    current_version = versions[0][2]
    build = int(builds[0][2])
    text = VERSION_LINE.sub(rf'\g<1>"{version}"', text)
    text = BUILD_LINE.sub(rf'\g<1>"{build + 1}"', text)
    return current_version, text


def command(*args, check=True):
    try:
        result = subprocess.run(args, check=False, capture_output=True, text=True)
    except FileNotFoundError as exc:
        raise ReleaseError(
            f"error: {args[0]} was not found.\nhint: Re-enter the devShell."
        ) from exc
    if check and result.returncode:
        detail = (result.stderr.strip() or result.stdout.strip()).replace("\n", " | ")
        raise ReleaseError(f"error: Command failed: {' '.join(args)} ({detail}).")
    return result


def git(*args, check=True):
    return command("git", *args, check=check)


def latest_release():
    versions = []
    for tag in git("tag", "--list").stdout.splitlines():
        if match := VERSION_TAG.fullmatch(tag):
            versions.append((tuple(map(int, match.groups())), tag))
    if not versions:
        raise ReleaseError(
            "error: No release tags found.\n"
            "hint: Check for tags in the form v{MAJOR}.{MINOR}.{PATCH}."
        )
    numbers, tag = max(versions)
    return tag, ".".join(map(str, numbers))


def ensure_ancestor(revision):
    result = git("merge-base", "--is-ancestor", revision, "HEAD", check=False)
    if result.returncode == 1:
        raise ReleaseError(
            "error: main has not been merged back.\n"
            "hint: Merge main into develop or the current hotfix branch."
        )
    if result.returncode:
        raise ReleaseError(
            f"error: Cannot check the history of {revision} and HEAD.\n"
            "hint: Check the Git history."
        )


def read_project(path):
    text = path.read_text(encoding="utf-8")
    try:
        # 書き換え後の文字列は使わず、行の検査と現在の版の読み取りだけに使う。
        current, _ = update_project(text, "0.0.0")
    except ValueError as exc:
        raise ReleaseError(
            f"error: Cannot read the version in project.yml: {exc}\n"
            "hint: Keep each version setting on exactly one line."
        ) from exc
    return text, current


def read_pull_requests(tag):
    subjects = git(
        "log", "--first-parent", "--merges", "--reverse", "--format=%s", f"{tag}..HEAD"
    ).stdout.splitlines()
    pull_requests = []
    invalid = []
    for number in pull_request_numbers(subjects):
        result = command(
            "gh", "pr", "view", str(number), "--json", "number,title,url,labels"
        )
        try:
            raw = json.loads(result.stdout)
            labels = [label["name"] for label in raw["labels"]]
        except (json.JSONDecodeError, KeyError, TypeError) as exc:
            raise ReleaseError(
                f"error: Cannot read PR #{number}.\n"
                "hint: Check gh authentication and the PR."
            ) from exc
        if "S-Release" in labels:
            continue
        try:
            kind, breaking = classify_labels(labels)
        except ValueError:
            invalid.append(f"#{number} ({', '.join(labels) or 'no labels'})")
            continue
        pull_requests.append(
            {
                "number": raw["number"],
                "title": raw["title"],
                "url": raw["url"],
                "type": kind,
                "breaking": breaking,
                "labels": labels,
            }
        )
    if invalid:
        raise ReleaseError(
            f"error: Some PRs do not have exactly one type label: {'; '.join(invalid)}.\n"
            "hint: Add exactly one T-* label to each PR."
        )
    if not pull_requests:
        raise ReleaseError(
            "error: No PRs to release.\n"
            "hint: Merge the PRs into develop, then try again."
        )
    return pull_requests


def patch_commits():
    lines = git(
        "log", "--no-merges", "--reverse", "--format=%H%x00%s", "origin/main..HEAD"
    ).stdout.splitlines()
    return [
        {"sha": sha, "subject": subject}
        for line in lines
        for sha, subject in [line.split("\0", 1)]
    ]


def prepare(mode):
    if git("status", "--porcelain").stdout:
        raise ReleaseError(
            "error: The working tree has changes.\n"
            "hint: Commit or stash the changes, then try again."
        )
    # マージ後に消えた release/* の追跡ブランチを残さないよう、ブランチは prune する。
    # タグは prune しない（--prune と --tags を併せると、手元だけのタグまで消えるため）。
    fetches = (
        git("fetch", "--prune", "origin", check=False),
        git("fetch", "origin", "--tags", check=False),
    )
    if any(fetch.returncode for fetch in fetches):
        raise ReleaseError(
            "error: Cannot fetch branches and tags from origin.\n"
            "hint: Check the connection and origin configuration."
        )

    tag, previous = latest_release()
    ensure_ancestor(tag)
    ensure_ancestor("origin/main")
    project = Path("project.yml")
    project_text, project_version = read_project(project)
    if project_version != previous:
        raise ReleaseError(
            f"error: Version {project_version} in project.yml does not match the latest tag {tag}.\n"
            "hint: Correct the version or tag."
        )

    branch = git("branch", "--show-current").stdout.strip()
    if mode == "patch":
        if not branch.startswith("hotfix/"):
            raise ReleaseError(
                "error: The current branch is not hotfix/*.\n"
                "hint: Create a hotfix/* branch from main and switch to it."
            )
        if not git("rev-list", "origin/main..HEAD").stdout:
            raise ReleaseError(
                "error: No commits to release on the hotfix branch.\n"
                "hint: Commit the fix, then try again."
            )
        kind = "patch"
        version = next_version(previous, kind)
        pull_requests = []
        commits = patch_commits()
    else:
        if branch != "develop":
            raise ReleaseError(
                "error: The current branch is not develop.\nhint: Switch to develop."
            )
        if git("rev-parse", "HEAD").stdout != git("rev-parse", "origin/develop").stdout:
            raise ReleaseError(
                "error: develop does not match origin/develop.\n"
                "hint: Push or pull to bring them in sync."
            )
        release_refs = git(
            "for-each-ref",
            "--format=%(refname)",
            "refs/heads/release/",
            "refs/remotes/origin/release/",
        ).stdout
        if release_refs:
            raise ReleaseError(
                "error: A release/* branch already exists.\n"
                "hint: Complete or remove the current release, then try again."
            )
        pull_requests = read_pull_requests(tag)
        kind = release_kind(previous, pull_requests)
        version = next_version(previous, kind)
        branch = f"release/v{version}"
        commits = []

    if git("tag", "--list", f"v{version}").stdout:
        raise ReleaseError(
            f"error: Tag v{version} already exists.\n"
            "hint: Check the tag and version history."
        )
    if mode != "patch":
        git("switch", "-c", branch)

    try:
        _, updated = update_project(project_text, version)
    except ValueError as exc:
        raise ReleaseError(
            f"error: Cannot update project.yml: {exc}\n"
            "hint: Keep each version setting on exactly one line."
        ) from exc
    project.write_text(updated, encoding="utf-8")
    git("add", "--", str(project))
    git("commit", "-m", f"Release v{version}", "--", str(project))

    material = {
        "version": version,
        "previous_tag": tag,
        "kind": kind,
        "branch": branch,
        "pull_requests": pull_requests,
        "commits": commits,
    }
    output = Path(".build/release") / f"v{version}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(material, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Version: {version}")
    print(f"Materials: {output}")


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    if args not in ([], ["patch"]):
        print(
            "usage: prepare_release.py [patch]\nRun with no arguments, or patch for a patch release.",
            file=sys.stderr,
        )
        return 1
    try:
        prepare(args[0] if args else "release")
    except ReleaseError as exc:
        print(exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
