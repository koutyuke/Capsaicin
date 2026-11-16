"""文書の構造と ID の整合性を検査する。内容の妥当性はレビューが担う。"""

import argparse
import re
import sys
import tomllib
from pathlib import Path

import yaml

# docs/documentation-management.md の領域表を正本とする。
DOMAIN_FILES = {
    "BLK": "blocking",
    "LED": "led",
    "MENU": "menu",
    "HUD": "hud",
    "SET": "settings",
    "CLI": "cli",
    "KEY": "hotkey",
    "HLP": "helper",
    "LCY": "lifecycle",
    "UI": "ui",
    "SYS": "system",
}
DOMAINS = set(DOMAIN_FILES)
SCHEMAS = {
    "decision": (
        "meta/decisions",
        "DEC",
        {"status", "supersedes", "superseded_by", "requirements", "based_on"},
    ),
    "question": ("meta/questions", "Q", {"requirements", "blocks"}),
    "hypothesis": ("meta/hypotheses", "HYP", {"status", "affects", "evidence"}),
    "evidence": ("meta/evidence", "EVID", {"observed_on", "environment", "sources"}),
    "plan": ("meta/plans", "PLAN", {"depends_on"}),
    "task": (
        "meta/tasks",
        "TASK",
        {"status", "requirements", "depends_on", "assignee"},
    ),
    "specification": ("specs", "SPEC", {"domain"}),
    "requirement-set": (
        "meta/requirements",
        "REQ",
        {"domain", "domain_code", "requirements"},
    ),
}
REFERENCE_FIELDS = {
    "requirements",
    "based_on",
    "affects",
    "evidence",
    "blocks",
    "depends_on",
    "supersedes",
    "superseded_by",
}
REFERENCE_KINDS = {
    "requirements": ("REQ",),
    "based_on": ("EVID", "HYP", "DEC"),
    "affects": ("REQ", "SPEC", "DEC"),
    "evidence": ("EVID",),
    "blocks": ("REQ", "PLAN", "TASK"),
    "supersedes": ("DEC",),
    "superseded_by": ("DEC",),
}
STATUSES = {
    "decision": {"accepted", "superseded"},
    "hypothesis": {"open", "supported", "refuted"},
    "task": {"todo", "in_progress", "in_review", "done"},
}
ID = re.compile(r"(?:TASK-[0-9]{3}|(?:REQ|SPEC|DEC|Q|HYP|EVID|PLAN)-([A-Z]+)-[0-9]{3})")
MENTION = re.compile(
    r"(?<![A-Za-z0-9_-])(?:TASK|REQ|SPEC|DEC|Q|HYP|EVID|PLAN)-(?:[A-Z]+-)?[0-9]+(?![A-Za-z0-9_])"
)


def without_fenced_code(body):
    lines = []
    fence = None
    for line in body.splitlines(keepends=True):
        marker = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line)
        if fence:
            if (
                marker
                and marker[1][0] == fence[0]
                and len(marker[1]) >= len(fence)
                and not marker[2].strip()
            ):
                fence = None
        elif marker:
            fence = marker[1]
        else:
            lines.append(line)
    return "".join(lines)


class Checker:
    def __init__(self, root):
        self.root = Path(root)
        self.errors = []
        self.ids = {}
        self.references = []
        self.requirements = {}
        self.specifications = {}

    def error(self, path, message):
        self.errors.append(f"{path.relative_to(self.root)}: {message}")

    def register(self, path, identifier, prefix, domain=None):
        match = ID.fullmatch(identifier) if isinstance(identifier, str) else None
        if not match or (match.group(1) and match.group(1) not in DOMAINS):
            self.error(path, f"Invalid ID format: {identifier!r}.")
            return False
        if not identifier.startswith(prefix + "-") or (
            domain and match.group(1) != domain
        ):
            self.error(path, f"ID kind or domain does not match: {identifier}.")
        if identifier in self.ids:
            self.error(
                path,
                f"Duplicate ID: {identifier} ({self.ids[identifier].relative_to(self.root)}).",
            )
            return False
        self.ids[identifier] = path
        return True

    def required(self, path, data, fields):
        for field in sorted(fields - data.keys()):
            self.error(path, f"Missing required field: {field}.")

    def enum(self, path, data, field, allowed):
        value = data.get(field)
        if not isinstance(value, str) or value not in allowed:
            self.error(path, f"Invalid value for {field}: {value!r}.")

    def refs(self, path, data, field, prefix=None):
        allowed_kinds = (prefix,) if isinstance(prefix, str) else prefix
        values = data.get(field, [])
        if not isinstance(values, list) or any(not isinstance(v, str) for v in values):
            self.error(path, f"Field {field} must be an array of IDs.")
            return []
        for value in values:
            match = ID.fullmatch(value)
            if not match or (match.group(1) and match.group(1) not in DOMAINS):
                self.error(path, f"Invalid ID format in {field}: {value!r}.")
            elif allowed_kinds and not any(
                value.startswith(kind + "-") for kind in allowed_kinds
            ):
                self.error(path, f"Invalid ID kind in {field}: {value}.")
            self.references.append((path, value))
        return values

    def read(self, path):
        text = path.read_text(encoding="utf-8")
        if path.suffix == ".toml":
            return tomllib.loads(text), text
        if not text.startswith("---\n"):
            return {}, text
        parts = text.split("\n---\n", 1)
        if len(parts) != 2:
            raise ValueError("Missing Front Matter closing delimiter.")
        return yaml.safe_load(parts[0][4:]), parts[1]

    def requirement_set(self, path, data):
        self.enum(path, data, "domain_code", DOMAINS)
        code = data.get("domain_code")
        if isinstance(code, str) and code in DOMAIN_FILES:
            expected = DOMAIN_FILES[code]
            if path.stem != expected or data.get("domain") != expected:
                self.error(
                    path,
                    f"Requirement filename, domain, and domain_code do not match: {code} requires {expected}.toml / {expected}.",
                )
        if not isinstance(data.get("domain"), str) or not data["domain"]:
            self.error(path, "Field domain must be a non-empty string.")
        entries = data.get("requirements")
        if not isinstance(entries, list):
            self.error(
                path, "Field requirements must be an array of [[requirements]] tables."
            )
            return
        for entry in entries:
            if not isinstance(entry, dict):
                self.error(path, "Each requirements entry must be a table.")
                continue
            self.required(
                path,
                entry,
                {
                    "id",
                    "title",
                    "kind",
                    "statement",
                    "reason",
                    "priority",
                    "status",
                    "specs",
                    "depends_on",
                    "sources",
                },
            )
            identifier = entry.get("id")
            valid = self.register(path, identifier, "REQ", data.get("domain_code"))
            self.enum(path, entry, "kind", {"functional", "quality", "constraint"})
            self.enum(path, entry, "priority", {"must", "should", "could"})
            self.enum(path, entry, "status", {"draft", "accepted"})
            specs = self.refs(path, entry, "specs", "SPEC")
            if entry.get("kind") != "constraint" and not specs:
                self.error(
                    path,
                    f"Non-constraint requirement has no specifications: {identifier}.",
                )
            self.refs(path, entry, "depends_on", "REQ")
            self.refs(path, entry, "sources", ("DEC", "EVID", "HYP"))
            if valid:
                self.requirements[identifier] = (path, set(specs))

    def specification(self, path, data, body):
        self.enum(path, data, "domain", DOMAINS)
        domain = data.get("domain")
        if (
            isinstance(domain, str)
            and domain in DOMAIN_FILES
            and path.stem != DOMAIN_FILES[domain]
        ):
            self.error(
                path,
                f"Specification filename and domain do not match: {domain} requires {DOMAIN_FILES[domain]}.md.",
            )
        if "id" in data:
            self.error(path, "Specification documents must not have an id.")
        # 通常の説明用見出しは許し、SPEC と名乗る節は必ず検査する。
        sections = re.split(r"^## (SPEC-[^\n]*)$", body, flags=re.MULTILINE)
        for index in range(1, len(sections), 2):
            heading, content = sections[index : index + 2]
            words = heading.split(maxsplit=1)
            identifier = words[0]
            if len(words) != 2:
                self.error(path, f"Specification heading has no name: {identifier}.")
            valid = self.register(path, identifier, "SPEC", data.get("domain"))
            first = content.strip().splitlines()
            related = re.fullmatch(r"関連要件[:：]\s*(.*)", first[0]) if first else None
            if not related:
                self.error(
                    path,
                    f"Section does not start with '関連要件:': {identifier}.",
                )
                requirements = []
            else:
                # 複数 ID はカンマ・読点・空白で区切れる。リンク表記も許す。
                requirements = MENTION.findall(related[1])
                if not requirements:
                    self.error(path, f"'関連要件:' line has no IDs: {identifier}.")
                self.refs(path, {"requirements": requirements}, "requirements", "REQ")
            if valid:
                self.specifications[identifier] = (path, set(requirements))

    def document(self, path):
        relative = path.relative_to(self.root)
        prefixes = ("REQ-", "SPEC-", "DEC-", "Q-", "HYP-", "EVID-", "PLAN-", "TASK-")
        managed = relative.parts[0] in {"meta", "specs"} or path.name.startswith(
            prefixes
        )
        try:
            data, body = self.read(path)
        except (ValueError, yaml.YAMLError, OSError) as exc:
            detail = str(exc).rstrip(".").replace("\n", " | ")
            self.error(path, f"Cannot parse document: {detail}.")
            return
        if not isinstance(data, dict):
            self.error(path, "Front Matter must be a mapping.")
            return
        schema = data.get("schema")
        if not managed and schema is None:
            if relative.as_posix() != "documentation-management.md":
                self.references.extend(
                    (path, identifier) for identifier in set(MENTION.findall(body))
                )
            return
        if not isinstance(schema, str) or schema not in SCHEMAS:
            self.error(path, f"Missing or unknown schema: {schema!r}.")
            return
        directory, prefix, fields = SCHEMAS[schema]
        extension = ".toml" if schema == "requirement-set" else ".md"
        if relative.parent.as_posix() != directory or path.suffix != extension:
            self.error(
                path,
                f"Schema and location do not match: {schema} requires {directory}/*{extension}.",
            )
        common = {"schema"} if schema == "requirement-set" else {"schema", "title"}
        if schema not in {"requirement-set", "specification"}:
            common.add("id")
        self.required(path, data, common | fields)
        if schema == "requirement-set":
            self.requirement_set(path, data)
        elif schema == "specification":
            body = without_fenced_code(body)
            self.specification(path, data, body)
        else:
            identifier = data.get("id")
            self.register(path, identifier, prefix)
            if not isinstance(identifier, str) or not re.fullmatch(
                re.escape(identifier) + r"-[a-z0-9]+(?:-[a-z0-9]+)*\.md", path.name
            ):
                self.error(
                    path,
                    "Filename and id do not match; expected {ID}-{short-english-name}.md.",
                )
            if schema in STATUSES:
                self.enum(path, data, "status", STATUSES[schema])
            for field in REFERENCE_FIELDS & data.keys():
                kinds = ("PLAN",) if schema == "plan" else ("TASK",)
                self.refs(
                    path,
                    data,
                    field,
                    kinds if field == "depends_on" else REFERENCE_KINDS[field],
                )
        # 運用規則自体の説明用 ID は対象外。記録・製品の本文の参照は検査する。
        for identifier in set(MENTION.findall(body)):
            self.references.append((path, identifier))

    def run(self):
        if not self.root.is_dir():
            return [f"{self.root}: Docs directory does not exist."]
        for path in sorted(self.root.rglob("*")):
            if (
                path.is_file()
                and path.suffix in {".md", ".toml"}
                and ".tpl." not in path.name
            ):
                self.document(path)
        for path, identifier in sorted(set(self.references)):
            if identifier not in self.ids:
                self.error(path, f"Referenced ID does not exist: {identifier}.")
        for requirement, (path, specs) in self.requirements.items():
            for spec in specs & self.specifications.keys():
                if requirement not in self.specifications[spec][1]:
                    self.error(
                        path,
                        f"Bidirectional mismatch: {requirement}.specs lists {spec}, but the 関連要件 of {spec} does not include {requirement}.",
                    )
        for spec, (path, requirements) in self.specifications.items():
            for requirement in requirements & self.requirements.keys():
                if spec not in self.requirements[requirement][1]:
                    self.error(
                        path,
                        f"Bidirectional mismatch: {spec} lists related requirement {requirement}, but {requirement}.specs does not include {spec}.",
                    )
        return self.errors


def check_docs(root):
    return Checker(root).run()


def main():
    parser = argparse.ArgumentParser(description="Check document structure and IDs.")
    parser.add_argument(
        "root",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "docs",
    )
    errors = check_docs(parser.parse_args().root)
    if errors:
        print(
            f"Docs check failed: {len(errors)} {'error' if len(errors) == 1 else 'errors'}.",
            file=sys.stderr,
        )
        print("\n".join(f"  {error}" for error in errors), file=sys.stderr)
    else:
        print("Docs check passed.")
    return bool(errors)


if __name__ == "__main__":
    sys.exit(main())
