"""実際の docs/ に触れず、検査規則を一時フィクスチャで確かめる。"""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

from scripts.check_docs import DOMAIN_FILES, SCHEMAS, STATUSES, check_docs

REQUIREMENTS = """schema = "requirement-set"
domain = "menu"
domain_code = "MENU"

[[requirements]]
id = "REQ-MENU-001"
title = "名前"
kind = "functional"
statement = "振る舞い"
reason = "理由"
priority = "must"
status = "accepted"
specs = ["SPEC-MENU-001"]
depends_on = []
sources = []
"""
SPECIFICATION = """---
schema: specification
title: メニュー
domain: MENU
---

## SPEC-MENU-001 名前

関連要件: `REQ-MENU-001`

振る舞い。
"""


class CheckDocsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write("meta/requirements/menu.toml", REQUIREMENTS)
        self.write("specs/menu.md", SPECIFICATION)

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def record(self, schema, **overrides):
        directory, prefix, fields = SCHEMAS[schema]
        identifier = "TASK-001" if prefix == "TASK" else f"{prefix}-MENU-001"
        data = {field: [] for field in fields}
        data.update(schema=schema, id=identifier, title="名前")
        if schema in STATUSES:
            data["status"] = sorted(STATUSES[schema])[0]
        if schema == "evidence":
            data.update(observed_on="2026-11-06", environment="macOS", sources=[])
        if schema == "task":
            data["assignee"] = "engineer"
        data.update(overrides)
        text = "---\n" + yaml.safe_dump(data, allow_unicode=True) + "---\n\n本文。\n"
        return self.write(f"{directory}/{identifier}-sample.md", text)

    def assert_error(self, message):
        errors = check_docs(self.root)
        self.assertTrue(any(message in error for error in errors), errors)

    def test_all_schemas_and_allowed_statuses(self):
        for schema in SCHEMAS.keys() - {"requirement-set", "specification"}:
            for status in STATUSES.get(schema, {None}):
                with self.subTest(schema=schema, status=status):
                    self.record(schema, **({"status": status} if status else {}))
                    self.assertEqual(check_docs(self.root), [])

    def test_all_requirement_enum_values(self):
        enums = {
            "kind": ["functional", "quality", "constraint"],
            "priority": ["must", "should", "could"],
            "status": ["draft", "accepted"],
        }
        for field, values in enums.items():
            original = {"kind": "functional", "priority": "must", "status": "accepted"}[
                field
            ]
            for value in values:
                with self.subTest(field=field, value=value):
                    text = REQUIREMENTS.replace(
                        f'{field} = "{original}"', f'{field} = "{value}"'
                    )
                    self.write("meta/requirements/menu.toml", text)
                    self.assertEqual(check_docs(self.root), [])

    def test_missing_and_unknown_schemas(self):
        for text in [
            "# no schema",
            "---\nschema: typo\n---\n",
            "---\nschema: []\n---\n",
        ]:
            with self.subTest(text=text):
                self.write("meta/tasks/TASK-001-sample.md", text)
                self.assert_error("Missing or unknown schema")

    def test_missing_toml_schema(self):
        self.write(
            "meta/requirements/menu.toml",
            REQUIREMENTS.replace('schema = "requirement-set"\n', ""),
        )
        self.assert_error("Missing or unknown schema")

    def test_misplaced_record_without_schema_is_not_silently_skipped(self):
        self.write("TASK-002-misplaced.md", "# schema なし")
        self.assert_error("TASK-002-misplaced.md: Missing or unknown schema")

    def test_schema_placement_and_extension(self):
        for name in [
            "product/wrong.md",
            "meta/tasks/nested/wrong.md",
            "meta/requirements/wrong.md",
        ]:
            with self.subTest(name=name):
                self.write(name, SPECIFICATION)
                self.assert_error("Schema and location do not match")

    def test_missing_required_fields(self):
        self.record("task")
        self.write(
            "meta/tasks/TASK-001-sample.md", "---\nschema: task\nid: TASK-001\n---\n"
        )
        self.assert_error("Missing required field: title")
        self.assert_error("Missing required field: depends_on")
        self.write(
            "meta/requirements/menu.toml", REQUIREMENTS.replace('reason = "理由"\n', "")
        )
        self.assert_error("Missing required field: reason")

    def test_id_formats_prefixes_domains_and_filenames(self):
        for identifier in [
            "TASK-1",
            "TASK-MENU-001",
            "DEC-NOPE-001",
            "REQ-MENU-001",
            "TASK-002",
        ]:
            with self.subTest(identifier=identifier):
                self.record("task", id=identifier)
                self.assertTrue(check_docs(self.root))
        self.record("task", id="TASK-001")
        path = self.root / "meta/tasks/TASK-001-sample.md"
        path.rename(path.with_name("TASK-001.md"))
        self.assert_error("Filename and id do not match")

    def test_duplicate_record_and_requirement_ids(self):
        path = self.record("task")
        self.write("meta/tasks/TASK-001-other.md", path.read_text())
        self.assert_error("Duplicate ID: TASK-001")
        self.write("meta/requirements/other.toml", REQUIREMENTS)
        self.assert_error("Duplicate ID: REQ-MENU-001")

    def test_duplicate_specification_ids(self):
        self.write(
            "specs/menu.md",
            SPECIFICATION + "\n## SPEC-MENU-001 再定義\n\n関連要件: REQ-MENU-001\n",
        )
        self.assert_error("Duplicate ID: SPEC-MENU-001")

    def test_all_reference_fields_and_types(self):
        fields = [
            "requirements",
            "based_on",
            "affects",
            "evidence",
            "blocks",
            "depends_on",
            "supersedes",
            "superseded_by",
        ]
        cases = [
            (["TASK-999"], "Referenced ID does not exist"),
            (["TASK-1"], "Invalid ID format"),
            ("TASK-001", "must be an array of IDs"),
            ([None], "must be an array of IDs"),
        ]
        for field in fields:
            for value, expected in cases:
                with self.subTest(field=field, value=value):
                    self.record("task", **{field: value})
                    self.assert_error(expected)

    def test_requirement_reference_fields(self):
        cases = [
            ('["REQ-MENU-999"]', "Referenced ID does not exist"),
            ('["TASK-1"]', "Invalid ID format"),
            ('"TASK-001"', "must be an array of IDs"),
            ("[1]", "must be an array of IDs"),
        ]
        for field in ["specs", "sources", "depends_on"]:
            for value, expected in cases:
                with self.subTest(field=field, value=value):
                    old = '["SPEC-MENU-001"]' if field == "specs" else "[]"
                    text = REQUIREMENTS.replace(
                        f"{field} = {old}", f"{field} = {value}"
                    )
                    self.write("meta/requirements/menu.toml", text)
                    self.assert_error(expected)

    def test_body_references(self):
        path = self.record("task")
        self.write(
            path.relative_to(self.root), path.read_text() + "参照: `DEC-MENU-999`。\n"
        )
        self.assert_error("Referenced ID does not exist: DEC-MENU-999")

    def test_requirement_to_specification_consistency(self):
        self.write(
            "specs/menu.md", SPECIFICATION.replace("REQ-MENU-001", "REQ-MENU-002")
        )
        self.assert_error("Bidirectional mismatch: REQ-MENU-001.specs")

    def test_specification_to_requirement_consistency(self):
        self.write(
            "meta/requirements/menu.toml",
            REQUIREMENTS.replace('["SPEC-MENU-001"]', "[]"),
        )
        self.assert_error("Bidirectional mismatch: SPEC-MENU-001")

    def test_related_requirements_must_be_at_start(self):
        self.write(
            "specs/menu.md", SPECIFICATION.replace("関連要件:", "説明。\n\n関連要件:")
        )
        self.assert_error("Section does not start with '関連要件:'")

    def test_specification_document_id_and_domain(self):
        self.write(
            "specs/menu.md",
            SPECIFICATION.replace("domain: MENU", "domain: BLK\nid: SPEC-MENU-999"),
        )
        self.assert_error("Specification documents must not have an id")
        self.assert_error("ID kind or domain does not match")

    def test_requirement_domain_and_reference_kinds(self):
        text = REQUIREMENTS.replace('domain_code = "MENU"', 'domain_code = "BLK"')
        text = text.replace('specs = ["SPEC-MENU-001"]', 'specs = ["REQ-MENU-001"]')
        self.write("meta/requirements/menu.toml", text)
        self.assert_error("ID kind or domain does not match")
        self.assert_error("Invalid ID kind in specs")

    def test_requirement_file_domain_and_code_must_match(self):
        self.write(
            "meta/requirements/menu.toml",
            REQUIREMENTS.replace('domain = "menu"', 'domain = "blocking"'),
        )
        self.assert_error("Requirement filename, domain, and domain_code do not match")
        self.write(
            "meta/requirements/menu.toml",
            REQUIREMENTS.replace('domain_code = "MENU"', 'domain_code = "BLK"'),
        )
        self.assert_error("Requirement filename, domain, and domain_code do not match")
        self.write("meta/requirements/menu.toml", REQUIREMENTS)
        self.write("meta/requirements/wrong.toml", REQUIREMENTS)
        self.assert_error(
            "wrong.toml: Requirement filename, domain, and domain_code do not match"
        )

    def test_all_domain_file_names(self):
        for code, name in DOMAIN_FILES.items():
            with self.subTest(domain=code):
                requirement = REQUIREMENTS.replace(
                    'domain = "menu"', f'domain = "{name}"'
                ).replace("MENU", code)
                self.write(f"meta/requirements/{name}.toml", requirement)
                self.write(f"specs/{name}.md", SPECIFICATION.replace("MENU", code))
                self.assertEqual(check_docs(self.root), [])

    def test_specification_filename_must_match_domain(self):
        self.write("specs/wrong.md", SPECIFICATION)
        self.assert_error("wrong.md: Specification filename and domain do not match")

    def test_specification_headings_in_fenced_examples_are_ignored(self):
        for opening, closing in [
            ("```markdown", "```"),
            ("~~~", "~~~~"),
            ("````", "````"),
            ("   ```", "   ```"),
        ]:
            with self.subTest(fence=opening):
                example = f"{opening}\n## SPEC-MENU-999 例\n関連要件: REQ-MENU-999\n```text\n{closing}\n"
                self.write(
                    "specs/menu.md",
                    SPECIFICATION.replace("振る舞い。", example + "\n振る舞い。"),
                )
                self.assertEqual(check_docs(self.root), [])

    def test_reference_layers_even_when_id_exists(self):
        for field in [
            "based_on",
            "evidence",
            "supersedes",
            "superseded_by",
            "depends_on",
        ]:
            with self.subTest(field=field):
                self.record("task", **{field: ["REQ-MENU-001"]})
                self.assert_error(f"Invalid ID kind in {field}")
        self.record("task")
        self.record("plan", depends_on=["TASK-001"])
        self.assert_error("Invalid ID kind in depends_on")
        self.write(
            "meta/requirements/menu.toml",
            REQUIREMENTS.replace("sources = []", 'sources = ["REQ-MENU-001"]'),
        )
        self.assert_error("Invalid ID kind in sources")

    def test_only_constraints_may_have_no_specs(self):
        text = REQUIREMENTS.replace('specs = ["SPEC-MENU-001"]', "specs = []")
        # 無関係な仕様を残さず、空の仕様集合を許す条件だけを検査する。
        self.write("specs/menu.md", SPECIFICATION.split("## SPEC-")[0])
        for kind in ["functional", "quality"]:
            self.write(
                "meta/requirements/menu.toml",
                text.replace('kind = "functional"', f'kind = "{kind}"'),
            )
            self.assert_error("Non-constraint requirement has no specifications")
        self.write(
            "meta/requirements/menu.toml",
            text.replace('kind = "functional"', 'kind = "constraint"'),
        )
        self.assertEqual(check_docs(self.root), [])

    def test_requirement_prose_references(self):
        self.write(
            "meta/requirements/menu.toml",
            REQUIREMENTS.replace('reason = "理由"', 'reason = "DEC-MENU-999 を参照"'),
        )
        self.assert_error("Referenced ID does not exist: DEC-MENU-999")

    def test_invalid_enums_including_non_scalar_values(self):
        for schema in STATUSES:
            self.record(schema, status=["bad"])
            self.assert_error("Invalid value for status")
            self.record(schema)
        for field in ["kind", "priority", "status"]:
            original = {"kind": "functional", "priority": "must", "status": "accepted"}[
                field
            ]
            text = REQUIREMENTS.replace(f'{field} = "{original}"', f'{field} = "bad"')
            self.write("meta/requirements/menu.toml", text)
            self.assert_error(f"Invalid value for {field}")

    def test_invalid_yaml_toml_and_containers(self):
        for text in [
            "---\nid: [\n---\n",
            "---\n[]\n---\n",
            "---\nschema: task",
            "---\nnull\n---\n",
        ]:
            self.write("meta/tasks/TASK-001-sample.md", text)
            self.assertTrue(check_docs(self.root))
        self.write("meta/requirements/menu.toml", "schema = [")
        self.assert_error("Cannot parse document")
        text = 'schema = "requirement-set"\ndomain = "menu"\ndomain_code = "MENU"\nrequirements = "not a list"\n'
        self.write("meta/requirements/menu.toml", text)
        self.assert_error("must be an array of [[requirements]] tables")

    def test_templates_and_unmanaged_documents_are_excluded(self):
        self.write("meta/tasks/task.tpl.md", "invalid yaml: [")
        self.write("meta/requirements/requirement-set.tpl.toml", "invalid = [")
        self.write("documentation-management.md", "例: REQ-MENU-999")
        self.write("product/overview.md", "# 製品")
        self.assertEqual(check_docs(self.root), [])

    def test_product_body_references_are_checked(self):
        self.write("product/overview.md", "参照: `REQ-MENU-999`。")
        self.assert_error("Referenced ID does not exist: REQ-MENU-999")

    def test_root_readme_body_references_are_checked(self):
        self.write("README.md", "参照: `REQ-MENU-999`。")
        self.assert_error("README.md: Referenced ID does not exist: REQ-MENU-999")

    def test_cli_exit_codes_and_missing_root(self):
        script = Path(__file__).resolve().parents[1] / "check_docs.py"
        result = subprocess.run(
            [sys.executable, str(script), str(self.root)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "Docs check passed.\n")
        self.assertEqual(result.stderr, "")
        self.record("task", status="bad")
        result = subprocess.run(
            [sys.executable, str(script), str(self.root)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertEqual(
            result.stderr,
            "Docs check failed: 1 error.\n"
            "  meta/tasks/TASK-001-sample.md: Invalid value for status: 'bad'.\n",
        )
        self.record("hypothesis", status="bad")
        result = subprocess.run(
            [sys.executable, str(script), str(self.root)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertEqual(
            result.stderr,
            "Docs check failed: 2 errors.\n"
            "  meta/hypotheses/HYP-MENU-001-sample.md: Invalid value for status: 'bad'.\n"
            "  meta/tasks/TASK-001-sample.md: Invalid value for status: 'bad'.\n",
        )
        self.assertIn(
            "Docs directory does not exist", check_docs(self.root / "missing")[0]
        )


if __name__ == "__main__":
    unittest.main()
