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
        raise ValueError("種類のラベルがちょうど1つではない")
    return types[0], "I-Breaking" in labels


def update_project(text, version):
    versions = list(VERSION_LINE.finditer(text))
    builds = list(BUILD_LINE.finditer(text))
    if len(versions) != 1 or len(builds) != 1:
        raise ValueError("MARKETING_VERSION と CURRENT_PROJECT_VERSION は1行ずつ必要")
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
            f"{args[0]} が見つかりません。\ndevShell に入り直してください。"
        ) from exc
    if check and result.returncode:
        detail = (result.stderr.strip() or result.stdout.strip()).replace("\n", " | ")
        raise ReleaseError(f"{' '.join(args)} に失敗しました。\n{detail}")
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
            "リリースのタグがありません。\nv{MAJOR}.{MINOR}.{PATCH} のタグを確認してください。"
        )
    numbers, tag = max(versions)
    return tag, ".".join(map(str, numbers))


def ensure_ancestor(revision):
    result = git("merge-base", "--is-ancestor", revision, "HEAD", check=False)
    if result.returncode == 1:
        raise ReleaseError(
            "main を戻しマージしていません。\nmain を develop または現在の hotfix にマージしてください。"
        )
    if result.returncode:
        raise ReleaseError(
            f"{revision} と HEAD の履歴を確認できません。\nGit の履歴を確認してください。"
        )


def read_project(path):
    text = path.read_text(encoding="utf-8")
    try:
        # 書き換え後の文字列は使わず、行の検査と現在の版の読み取りだけに使う。
        current, _ = update_project(text, "0.0.0")
    except ValueError as exc:
        raise ReleaseError(
            f"project.yml の版を読み取れません: {exc}\n版の設定を1行ずつに直してください。"
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
                f"PR #{number} の情報を読み取れません。\ngh の認証と PR を確認してください。"
            ) from exc
        if "S-Release" in labels:
            continue
        try:
            kind, breaking = classify_labels(labels)
        except ValueError:
            invalid.append(f"#{number} ({', '.join(labels) or 'ラベルなし'})")
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
            f"種類のラベルがちょうど1つではない PR があります: {'; '.join(invalid)}\n各 PR に T-* ラベルを1つ付けてください。"
        )
    if not pull_requests:
        raise ReleaseError(
            "リリース対象の PR がありません。\ndevelop に対象の PR をマージしてからやり直してください。"
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
            "作業ツリーに変更があります。\n変更をコミットするか退避してからやり直してください。"
        )
    # マージ後に消えた release/* の追跡ブランチを残さないよう、ブランチは prune する。
    # タグは prune しない（--prune と --tags を併せると、手元だけのタグまで消えるため）。
    fetches = (
        git("fetch", "--prune", "origin", check=False),
        git("fetch", "origin", "--tags", check=False),
    )
    if any(fetch.returncode for fetch in fetches):
        raise ReleaseError(
            "origin のブランチとタグを取得できません。\n接続と origin の設定を確認してください。"
        )

    tag, previous = latest_release()
    ensure_ancestor(tag)
    ensure_ancestor("origin/main")
    project = Path("project.yml")
    project_text, project_version = read_project(project)
    if project_version != previous:
        raise ReleaseError(
            f"project.yml の版 {project_version} が最新のタグ {tag} と一致しません。\n版かタグを正しい状態に直してください。"
        )

    branch = git("branch", "--show-current").stdout.strip()
    if mode == "patch":
        if not branch.startswith("hotfix/"):
            raise ReleaseError(
                "現在のブランチが hotfix/* ではありません。\nmain から hotfix/* を作って切り替えてください。"
            )
        if not git("rev-list", "origin/main..HEAD").stdout:
            raise ReleaseError(
                "hotfix にリリースするコミットがありません。\n修正をコミットしてからやり直してください。"
            )
        kind = "patch"
        version = next_version(previous, kind)
        pull_requests = []
        commits = patch_commits()
    else:
        if branch != "develop":
            raise ReleaseError(
                "現在のブランチが develop ではありません。\ndevelop に切り替えてください。"
            )
        if git("rev-parse", "HEAD").stdout != git("rev-parse", "origin/develop").stdout:
            raise ReleaseError(
                "develop が origin/develop と一致しません。\npush または pull して一致させてください。"
            )
        release_refs = git(
            "for-each-ref",
            "--format=%(refname)",
            "refs/heads/release/",
            "refs/remotes/origin/release/",
        ).stdout
        if release_refs:
            raise ReleaseError(
                "release/* ブランチが既にあります。\n進行中のリリースを完了または削除してからやり直してください。"
            )
        pull_requests = read_pull_requests(tag)
        kind = release_kind(previous, pull_requests)
        version = next_version(previous, kind)
        branch = f"release/v{version}"
        commits = []

    if git("tag", "--list", f"v{version}").stdout:
        raise ReleaseError(
            f"v{version} のタグが既にあります。\nタグと版の履歴を確認してください。"
        )
    if mode != "patch":
        git("switch", "-c", branch)

    try:
        _, updated = update_project(project_text, version)
    except ValueError as exc:
        raise ReleaseError(
            f"project.yml を更新できません: {exc}\n版の設定を1行ずつに直してください。"
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
    print(f"版: {version}")
    print(f"材料: {output}")


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    if args not in ([], ["patch"]):
        print(
            "使い方: prepare_release.py [patch]\n引数なし、または patch で実行してください。",
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
