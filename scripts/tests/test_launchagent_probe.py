"""専用プローブの準備だけを検査する。生成した実行ファイルは起動しない。"""

import importlib.util
import json
import os
import plistlib
import shlex
import subprocess
import sys
import tempfile
import unittest
import uuid
from pathlib import Path
from unittest.mock import Mock, patch

SOURCE = (
    Path(__file__).resolve().parents[1] / "manual" / "launchagent-probe" / "prepare.py"
)
SPEC = importlib.util.spec_from_file_location("launchagent_probe", SOURCE)
probe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(probe)
REAL_RUN = subprocess.run


def load_operations():
    spec = importlib.util.spec_from_file_location(
        "probe_operations", SOURCE.with_name("operations.py")
    )
    module = importlib.util.module_from_spec(spec)
    with patch.dict(sys.modules, {"prepare": probe}):
        spec.loader.exec_module(module)
    module.print = Mock()
    return module


class LaunchAgentProbeTests(unittest.TestCase):
    def setUp(self):
        project = Path(__file__).resolve().parents[2]
        fixture_root = project / ".build" / "tmp"
        fixture_root.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=fixture_root)
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "space and 'quote 日本語"
        self.root.mkdir()
        self.home = self.root / "home"
        agents = self.home / "Library" / "LaunchAgents"
        agents.mkdir(parents=True)
        (agents / "existing.plist").write_text("keep")
        home_patch = patch.object(probe.Path, "home", return_value=self.home)
        home_patch.start()
        self.addCleanup(home_patch.stop)
        self.calls = []

        def compiler(command, *, check):
            self.assertIs(check, True)
            self.calls.append(command)
            if command[0] == "/usr/bin/xcrun":
                self.assertEqual(command[1:4], ["--sdk", "macosx", "clang"])
                self.assertEqual(command[-2], "-o")
                self.assertTrue(Path(command[-3]).is_file())
                Path(command[-1]).write_bytes(b"inert fixture, never executed")
            elif command[0] == "/usr/bin/codesign":
                self.assertEqual(command[1:3], ["--sign", "-"])
                self.assertTrue(Path(command[3]).is_file())
            else:
                self.fail(f"許可していない subprocess: {command!r}")

        self.compiler = Mock(side_effect=compiler)
        subprocess_patch = patch.object(probe.subprocess, "run", self.compiler)
        subprocess_patch.start()
        self.addCleanup(subprocess_patch.stop)

    def prepared(self):
        workspace = probe.prepare(self.root)
        return workspace, workspace / "manifest.json"

    def start_log(self, workspace, instance="a" * 32, event="start", label=None):
        manifest = json.loads((workspace / "manifest.json").read_text())
        (workspace / "events.log").write_text(
            f"1700000000 123 {instance} {label or manifest['label']} {event}\n"
        )

    def test_exact_plist_and_private_unique_debug_workspace(self):
        workspace, path = self.prepared()
        manifest = probe.load_manifest(path)
        self.assertEqual(workspace.stat().st_mode & 0o777, 0o700)
        self.assertEqual(workspace.parent, self.root / ".build" / "manual")
        self.assertRegex(manifest["label"], rf"^{probe.PREFIX}[0-9a-f]{{32}}$")
        with Path(manifest["plist"]).open("rb") as source:
            job = plistlib.load(source)
        self.assertEqual(
            job,
            {
                "Label": manifest["label"],
                "ProgramArguments": [str(workspace / "probe")],
                "WorkingDirectory": str(workspace),
                "RunAtLoad": False,
                "KeepAlive": {"Crashed": True},
                "StandardErrorPath": str(workspace / "probe-stderr.log"),
            },
        )
        self.assertIs(type(job["RunAtLoad"]), bool)
        self.assertIs(type(job["KeepAlive"]["Crashed"]), bool)
        self.assertEqual((workspace / "events.log").read_bytes(), b"")
        agents = self.home / "Library" / "LaunchAgents"
        self.assertEqual([path.name for path in agents.iterdir()], ["existing.plist"])
        self.assertEqual((agents / "existing.plist").read_text(), "keep")
        second, _ = self.prepared()
        self.assertNotEqual(workspace, second)

    def test_only_compiler_and_signer_subprocesses_and_space_safe_arguments(self):
        workspace, path = self.prepared()
        self.assertEqual(len(self.calls), 2)
        self.assertEqual(
            self.calls[0][-3:],
            [str(workspace / "probe.c"), "-o", str(workspace / "probe")],
        )
        self.assertEqual(
            self.calls[1],
            ["/usr/bin/codesign", "--sign", "-", str(workspace / "probe")],
        )
        manifest = probe.load_manifest(path)
        text = (workspace / "instructions.md").read_text()
        self.assertEqual(text, probe.instructions(manifest, self.root))
        self.assertNotIn("@@", text)
        target = f"gui/{os.getuid()}/{manifest['label']}"
        self.assertIn(f"bootout {shlex.quote(target)}", text)
        self.assertNotIn(f"/bin/launchctl bootout gui/{os.getuid()}\n", text)
        self.assertLess(text.index(" cleanup "), text.index("/bin/launchctl bootstrap"))
        cleanup = next(line for line in text.splitlines() if " cleanup " in line)
        self.assertEqual(shlex.split(cleanup)[-2:], ["cleanup", str(path)])
        self.assertNotIn("/bin/cat " + shlex.quote(manifest["plist"]) + " >", text)
        control = next(line for line in text.splitlines() if " control " in line)
        self.assertEqual(
            shlex.split(control),
            [
                "nix",
                "develop",
                str(self.root),
                "--command",
                "python3",
                str(SOURCE),
                "control",
                str(path),
                "exit",
            ],
        )
        header = (workspace / "config.h").read_text()
        self.assertIn(json.dumps(str(workspace), ensure_ascii=False), header)

    def test_existing_workspace_is_not_clobbered(self):
        fixed = uuid.UUID("0123456789abcdef0123456789abcdef")
        with patch.object(probe.uuid, "uuid4", return_value=fixed):
            workspace, _ = self.prepared()
            before = {p.name: p.read_bytes() for p in workspace.iterdir()}
            with self.assertRaises(FileExistsError):
                self.prepared()
            self.assertEqual(
                before, {p.name: p.read_bytes() for p in workspace.iterdir()}
            )
        self.assertEqual(len(self.calls), 2)

    def test_failed_compile_or_sign_preserves_only_its_partial_workspace(self):
        good, _ = self.prepared()
        sentinel = good / "keep.txt"
        sentinel.write_text("keep")
        for failure in (1, 2):
            with self.subTest(subprocess=failure):
                count = 0

                def fail(command, *, check):
                    nonlocal count
                    count += 1
                    if count == failure:
                        raise subprocess.CalledProcessError(1, command)
                    Path(command[-1]).write_bytes(b"fixture")

                with self.assertRaisesRegex(RuntimeError, "未完了の専用領域") as error:
                    probe.prepare(self.root, runner=fail)
                partial = Path(str(error.exception).split(": ", 1)[1])
                self.assertEqual(partial.parent, good.parent)
                self.assertTrue(partial.is_dir())
                self.assertFalse((partial / "manifest.json").exists())
                self.assertFalse((partial / "instructions.md").exists())
                self.assertEqual(sentinel.read_text(), "keep")

    def test_symlink_build_or_manual_directory_is_rejected(self):
        outside = self.root / "outside"
        outside.mkdir()
        for component in (".build", "manual"):
            with self.subTest(component=component):
                root = self.root / component.replace(".", "")
                root.mkdir()
                target = root / ".build"
                if component == "manual":
                    target.mkdir()
                    target = target / "manual"
                target.symlink_to(outside, target_is_directory=True)
                with self.assertRaises(ValueError):
                    probe.prepare(root, runner=self.compiler)
        self.assertEqual(list(outside.iterdir()), [])
        self.compiler.assert_not_called()

    def test_failed_instruction_generation_has_no_completed_manifest(self):
        with patch.object(probe, "instructions", side_effect=ValueError("fixture")):
            with self.assertRaises(RuntimeError) as error:
                self.prepared()
        partial = Path(str(error.exception).split(": ", 1)[1])
        self.assertFalse((partial / "manifest.json").exists())
        self.assertTrue((partial / "probe").is_file())

    def test_control_is_instance_scoped_exclusive_and_crash_once(self):
        workspace, path = self.prepared()
        self.start_log(workspace)
        probe.control(path, "exit")
        self.assertTrue((workspace / ("exit-" + "a" * 32)).is_file())
        with self.assertRaises(FileExistsError):
            probe.control(path, "exit")
        probe.control(path, "crash")
        self.assertTrue((workspace / ("crash-" + "a" * 32)).is_file())
        self.start_log(workspace, instance="b" * 32)
        (workspace / "crash-used").touch()
        with self.assertRaisesRegex(ValueError, "使用済み"):
            probe.control(path, "crash")
        self.assertFalse((workspace / ("crash-" + "b" * 32)).exists())
        probe.control(path, "exit")
        self.assertTrue((workspace / ("exit-" + "b" * 32)).is_file())
        self.assertEqual(len(self.calls), 2)

    def test_control_rejects_bad_action_missing_start_and_wrong_instance(self):
        workspace, path = self.prepared()
        with self.assertRaises(ValueError):
            probe.control(path, "arbitrary-command")
        with self.assertRaisesRegex(ValueError, "起動記録がない"):
            probe.control(path, "exit")
        for fields in (
            {"instance": "../../escape"},
            {"event": "normal-exit"},
            {"label": "other-job"},
        ):
            with self.subTest(fields=fields):
                self.start_log(workspace, **fields)
                with self.assertRaises(ValueError):
                    probe.control(path, "exit")
        self.assertFalse(any(workspace.glob("exit-*")))

    def test_control_rejects_manifest_escape_symlinks_and_public_workspace(self):
        workspace, path = self.prepared()
        original = json.loads(path.read_text())
        for field in (
            "workspace",
            "label",
            "binary",
            "plist",
            "installed_plist",
            "uid",
        ):
            with self.subTest(field=field):
                changed = dict(original)
                changed[field] = "/escape"
                path.write_text(json.dumps(changed))
                with self.assertRaises(ValueError):
                    probe.control(path, "exit")
        path.write_text(json.dumps(original))
        workspace.chmod(0o755)
        with self.assertRaises(ValueError):
            probe.control(path, "exit")
        workspace.chmod(0o700)
        alias = workspace / "alias.json"
        alias.symlink_to(path)
        with self.assertRaises(ValueError):
            probe.control(alias, "exit")
        log = workspace / "events.log"
        log.rename(workspace / "saved.log")
        log.symlink_to(workspace / "saved.log")
        with self.assertRaises(ValueError):
            probe.control(path, "exit")

    def test_write_new_refuses_existing_file_or_symlink(self):
        original = self.root / "original"
        original.write_text("keep")
        alias = self.root / "alias"
        alias.symlink_to(original)
        for path in (original, alias):
            with self.assertRaises(FileExistsError):
                probe.write_new(path, "replace")
        self.assertEqual(original.read_text(), "keep")

    def test_manual_install_is_atomic_and_never_clobbers(self):
        operations = load_operations()
        workspace, path = self.prepared()
        manifest = probe.load_manifest(path)
        installed = Path(manifest["installed_plist"])
        stage = Path(manifest["staged_plist"])
        runner = self.manual_runner(manifest)
        operations.install(path, runner=runner)
        self.assertEqual(installed.read_bytes(), Path(manifest["plist"]).read_bytes())
        self.assertEqual(installed.stat().st_ino, stage.stat().st_ino)
        with self.assertRaises(FileExistsError):
            operations.install(path, runner=runner)
        self.assertTrue((workspace / "manifest.json").is_file())

    def manual_runner(
        self,
        manifest,
        *,
        registered=False,
        program=None,
        error=None,
        bootout_code=0,
        unregister=True,
        on_print=None,
    ):
        self.manual_calls = []
        prints = 0

        def run(command, **kwargs):
            nonlocal registered, prints
            self.manual_calls.append(command)
            if command[:2] == ["/bin/launchctl", "print"]:
                prints += 1
                if on_print:
                    on_print(prints)
                if error is not None:
                    return subprocess.CompletedProcess(command, 1, "", error)
                if registered:
                    text = (
                        f"gui/{manifest['uid']}/{manifest['label']} = {{\n"
                        f"\tpath = {manifest['installed_plist']}\n"
                        f"\tprogram = {program or manifest['binary']}\n"
                        "\tstate = not running\n\truns = 0\n"
                        "\tlast exit code = (never exited)\n}\n"
                    )
                    return subprocess.CompletedProcess(command, 0, text, "")
                return subprocess.CompletedProcess(
                    command,
                    113,
                    "",
                    f'Could not find service "{manifest["label"]}" in domain for user gui: {manifest["uid"]}\n',
                )
            if command[:2] == ["/bin/launchctl", "bootout"]:
                if unregister:
                    registered = False
                return subprocess.CompletedProcess(command, bootout_code, "", "")
            if command[0] == "/usr/bin/trash":
                # 実環境の trash は呼ばず、隔離 fixture 内へ移す。
                destination = self.root / "trashed"
                destination.mkdir(exist_ok=True)
                Path(command[1]).rename(destination / uuid.uuid4().hex)
                return subprocess.CompletedProcess(command, 0, "", "")
            self.fail(f"許可していない手動 fixture コマンド: {command}")

        return run

    def assert_no_destructive_commands(self):
        self.assertFalse(
            any(c[:2] == ["/bin/launchctl", "bootout"] for c in self.manual_calls)
        )
        self.assertFalse(any(c[0] == "/usr/bin/trash" for c in self.manual_calls))

    def test_existing_install_file_and_symlink_are_never_overwritten(self):
        operations = load_operations()
        for kind in ("file", "symlink"):
            with self.subTest(kind=kind):
                _, path = self.prepared()
                manifest = probe.load_manifest(path)
                installed = Path(manifest["installed_plist"])
                if kind == "file":
                    installed.write_bytes(b"foreign")
                else:
                    installed.symlink_to(self.root / "missing")
                runner = self.manual_runner(manifest)
                with self.assertRaises((ValueError, FileExistsError)):
                    operations.install(path, runner=runner)
                self.assertEqual(installed.is_symlink(), kind == "symlink")
                if kind == "file":
                    self.assertEqual(installed.read_bytes(), b"foreign")
                self.assertFalse(Path(manifest["staged_plist"]).exists())
                self.assert_no_destructive_commands()

    def test_publish_interruption_before_and_after_is_recoverable_without_bootout(self):
        operations = load_operations()
        link = os.link
        for after in (False, True):
            with self.subTest(after_publish=after):
                workspace, path = self.prepared()
                manifest = probe.load_manifest(path)
                installed = Path(manifest["installed_plist"])
                stage = Path(manifest["staged_plist"])
                calls = 0

                def interrupt(source, target, **kwargs):
                    nonlocal calls
                    calls += 1
                    if calls == 2 and not after:
                        raise InterruptedError("before atomic publish")
                    link(source, target, **kwargs)
                    if calls == 2:
                        raise InterruptedError("after atomic publish")

                with patch.object(operations.os, "link", side_effect=interrupt):
                    with self.assertRaises(InterruptedError):
                        operations.install(path, runner=self.manual_runner(manifest))
                expected = Path(manifest["plist"]).read_bytes()
                self.assertEqual(stage.read_bytes(), expected)
                self.assertEqual(installed.exists(), after)
                if after:
                    self.assertEqual(installed.read_bytes(), expected)
                operations.cleanup(path, runner=self.manual_runner(manifest))
                self.assertFalse(installed.exists())
                self.assertFalse(stage.exists())
                self.assertFalse(workspace.exists())
                self.assertFalse(any(c[1] == "bootout" for c in self.manual_calls))
                self.assertEqual(
                    (self.home / "Library/LaunchAgents/existing.plist").read_text(),
                    "keep",
                )

    def test_cleanup_refuses_changed_stage_symlink_partial_or_replaced(self):
        operations = load_operations()
        for kind in ("symlink", "partial", "replacement", "changed"):
            with self.subTest(kind=kind):
                workspace, path = self.prepared()
                manifest = probe.load_manifest(path)
                operations.install(path, runner=self.manual_runner(manifest))
                stage = Path(manifest["staged_plist"])
                content = stage.read_bytes()
                if kind == "partial":
                    stage.write_bytes(content[:10])
                elif kind == "changed":
                    stage.write_bytes(b"foreign")
                else:
                    stage.unlink()
                    if kind == "symlink":
                        stage.symlink_to(manifest["plist"])
                    else:
                        stage.write_bytes(content)
                runner = self.manual_runner(manifest)
                with self.assertRaises(ValueError):
                    operations.cleanup(path, runner=runner)
                self.assertTrue(workspace.exists())
                self.assertTrue(Path(manifest["installed_plist"]).exists())
                self.assert_no_destructive_commands()

    def test_cleanup_refuses_uid_job_mismatch_unknown_or_access_errors(self):
        operations = load_operations()
        workspace, path = self.prepared()
        manifest = probe.load_manifest(path)
        operations.install(path, runner=self.manual_runner(manifest))
        runner = self.manual_runner(manifest, registered=True)
        with patch.object(probe.os, "getuid", return_value=manifest["uid"] + 1):
            with self.assertRaises(ValueError):
                operations.cleanup(path, runner=runner)
        self.assertEqual(self.manual_calls, [])
        for kwargs in (
            {"registered": True, "program": "/foreign/program"},
            {"error": "Operation not permitted"},
            {"error": "Could not find domain"},
            {"error": "Unknown print failure"},
        ):
            with self.subTest(kwargs=kwargs):
                with self.assertRaises(ValueError):
                    operations.cleanup(
                        path, runner=self.manual_runner(manifest, **kwargs)
                    )
                self.assert_no_destructive_commands()
                self.assertTrue(workspace.exists())

    def test_cleanup_rejects_installed_symlink_and_missing_object_before_bootout(self):
        operations = load_operations()
        for kind in ("symlink", "missing", "content"):
            with self.subTest(kind=kind):
                workspace, path = self.prepared()
                manifest = probe.load_manifest(path)
                operations.install(path, runner=self.manual_runner(manifest))
                installed = Path(manifest["installed_plist"])
                if kind == "content":
                    installed.write_bytes(b"changed-in-place")
                else:
                    installed.unlink()
                    if kind == "symlink":
                        installed.symlink_to(manifest["plist"])
                with self.assertRaises(ValueError):
                    operations.cleanup(
                        path, runner=self.manual_runner(manifest, registered=True)
                    )
                self.assertTrue(workspace.exists())
                self.assert_no_destructive_commands()

    def test_install_rejects_symlink_directory_and_cross_device_without_fallback(self):
        operations = load_operations()
        workspace, path = self.prepared()
        manifest = probe.load_manifest(path)
        agents = Path(manifest["installed_plist"]).parent
        saved = agents.with_name("saved-agents")
        agents.rename(saved)
        agents.symlink_to(saved, target_is_directory=True)
        with self.assertRaises(ValueError):
            operations.install(path, runner=self.manual_runner(manifest))
        self.assert_no_destructive_commands()
        agents.unlink()
        saved.rename(agents)
        with patch.object(operations.os, "link", side_effect=OSError(18, "EXDEV")):
            with self.assertRaises(OSError):
                operations.install(path, runner=self.manual_runner(manifest))
        self.assertFalse(Path(manifest["installed_plist"]).exists())
        self.assertFalse(Path(manifest["staged_plist"]).exists())
        self.assertTrue(workspace.exists())

    def test_unknown_print_shape_wrong_uid_path_or_exit_code_never_authorize_cleanup(
        self,
    ):
        operations = load_operations()
        workspace, path = self.prepared()
        manifest = probe.load_manifest(path)
        operations.install(path, runner=self.manual_runner(manifest))
        target = f"gui/{manifest['uid']}/{manifest['label']}"
        for replacement in (
            (manifest["installed_plist"], "/foreign.plist"),
            (target, f"gui/{manifest['uid'] + 1}/{manifest['label']}"),
            ("\tprogram =", "  program ="),
            ("\tprogram =", "\tprogram = /foreign\n\tprogram ="),
        ):
            with self.subTest(replacement=replacement):
                base = self.manual_runner(manifest, registered=True)

                def run(command, **kwargs):
                    result = base(command, **kwargs)
                    result.stdout = result.stdout.replace(*replacement)
                    return result

                with self.assertRaises(ValueError):
                    operations.cleanup(path, runner=run)
                self.assert_no_destructive_commands()
        base = self.manual_runner(manifest)

        def wrong_status(command, **kwargs):
            result = base(command, **kwargs)
            result.returncode = 1
            return result

        with self.assertRaises(ValueError):
            operations.cleanup(path, runner=wrong_status)
        self.assert_no_destructive_commands()
        self.assertTrue(workspace.exists())

    def fixture_snapshot(self):
        return {
            str(path.relative_to(self.root)): (path.stat().st_ino, path.read_bytes())
            for path in self.root.rglob("*")
            if path.is_file()
        }

    def test_cleanup_rejects_malformed_print_structure_without_mutation(self):
        operations = load_operations()
        _, path = self.prepared()
        manifest = probe.load_manifest(path)
        for key in ("installed_plist", "staged_plist"):
            os.link(manifest["plist"], manifest[key])
        target = f"gui/{manifest['uid']}/{manifest['label']}"
        fields = (
            f"\tpath = {manifest['installed_plist']}\n"
            f"\tprogram = {manifest['binary']}\n"
        )
        cases = {
            "unclosed-spoofed-indent": "\tsection = {\n" + fields,
            "unclosed-normal-indent": fields + "\tsection = {\n\t\tvalue = x\n",
            "extra-close": fields + "\t}\n",
            "premature-root-close": "}\n" + fields,
            "nested-only-normal-indent": (
                "\tsection = {\n" + fields.replace("\t", "\t\t") + "\t}\n"
            ),
            "nested-only-spoofed-indent": "\tsection = {\n" + fields + "\t}\n",
            "misindented-open": fields + "\t\tsection = {\n\t}\n",
            "misindented-close": fields + "\tsection = {\n}\n",
            "inline-block": fields + "\tsection = {}\n",
            "unknown-structure": fields + "\tsection {\n\t}\n",
            "brace-in-scalar": fields + "\tvalue = /path/{ambiguous}\n",
            "duplicate-top-field": fields + fields,
        }
        before = self.fixture_snapshot()
        for name, body in cases.items():
            with self.subTest(structure=name):
                runner = Mock(
                    return_value=subprocess.CompletedProcess(
                        [], 0, f"{target} = {{\n{body}}}\n", ""
                    )
                )
                with self.assertRaises(ValueError):
                    operations.cleanup(path, runner=runner)
                self.assertEqual(self.fixture_snapshot(), before)
                self.assertEqual(
                    [call.args[0] for call in runner.call_args_list],
                    [["/bin/launchctl", "print", target]],
                )

    def test_service_accepts_balanced_nested_blocks_with_direct_identity(self):
        operations = load_operations()
        _, path = self.prepared()
        manifest = probe.load_manifest(path)
        target = f"gui/{manifest['uid']}/{manifest['label']}"
        text = (
            f"{target} = {{\n"
            f"\tpath = {manifest['installed_plist']}\n"
            f"\tprogram = {manifest['binary']}\n\n"
            "\targuments = {\n"
            f"\t\t{manifest['binary']}\n\t}}\n"
            "\tenvironment = {\n\t\tPATH => /usr/bin:/bin\n"
            "\t\tnested = {\n\t\t\tprogram = /foreign/program\n\t\t}\n\t}\n"
            "\truns = 0\n}\n"
        )
        runner = Mock(return_value=subprocess.CompletedProcess([], 0, text, ""))
        self.assertEqual(
            operations.service(manifest, runner),
            {
                "path": manifest["installed_plist"],
                "program": manifest["binary"],
                "runs": "0",
            },
        )
        runner.assert_called_once()
        self.assertEqual(runner.call_args.args[0], ["/bin/launchctl", "print", target])

    def assert_euid_mismatch_rejected(self, action):
        operations = load_operations()
        _, path = self.prepared()
        manifest = probe.load_manifest(path)
        if action == "cleanup":
            for key in ("installed_plist", "staged_plist"):
                os.link(manifest["plist"], manifest[key])
        before = self.fixture_snapshot()
        self.assertEqual(os.getuid(), manifest["uid"])
        runner = Mock(side_effect=AssertionError("runner must not be called"))
        with (
            patch.object(probe.os, "geteuid", return_value=manifest["uid"] + 1),
            patch.object(Path, "read_text") as read,
            patch.object(operations.os, "link") as link,
        ):
            with self.assertRaisesRegex(ValueError, "実効 UID"):
                getattr(operations, action)(path, runner=runner)
            read.assert_not_called()
            link.assert_not_called()
            runner.assert_not_called()
        self.assertEqual(self.fixture_snapshot(), before)

    def test_install_rejects_only_euid_mismatch_before_read_or_mutation(self):
        self.assert_euid_mismatch_rejected("install")

    def test_cleanup_rejects_only_euid_mismatch_before_read_or_mutation(self):
        self.assert_euid_mismatch_rejected("cleanup")

    def test_failed_bootout_only_recovers_when_definitely_unregistered(self):
        operations = load_operations()
        for unregister in (False, True):
            with self.subTest(unregister=unregister):
                workspace, path = self.prepared()
                manifest = probe.load_manifest(path)
                operations.install(path, runner=self.manual_runner(manifest))
                runner = self.manual_runner(
                    manifest,
                    registered=True,
                    bootout_code=1,
                    unregister=unregister,
                )
                if unregister:
                    operations.cleanup(path, runner=runner)
                    self.assertFalse(workspace.exists())
                else:
                    with self.assertRaises(ValueError):
                        operations.cleanup(path, runner=runner)
                    self.assertTrue(workspace.exists())
                    self.assertFalse(
                        any(c[0].endswith("trash") for c in self.manual_calls)
                    )
                bootouts = [c for c in self.manual_calls if c[1] == "bootout"]
                self.assertEqual(
                    bootouts,
                    [
                        [
                            "/bin/launchctl",
                            "bootout",
                            f"gui/{manifest['uid']}/{manifest['label']}",
                        ]
                    ],
                )

    def test_change_during_final_print_is_rejected_before_bootout(self):
        operations = load_operations()
        _, path = self.prepared()
        manifest = probe.load_manifest(path)
        operations.install(path, runner=self.manual_runner(manifest))
        installed = Path(manifest["installed_plist"])

        def change(count):
            if count == 2:
                installed.unlink()
                installed.write_bytes(b"foreign")

        runner = self.manual_runner(manifest, registered=True, on_print=change)
        with self.assertRaises(ValueError):
            operations.cleanup(path, runner=runner)
        self.assertEqual(installed.read_bytes(), b"foreign")
        self.assert_no_destructive_commands()

    def test_unregistered_stage_change_during_print_is_not_trashed(self):
        operations = load_operations()
        _, path = self.prepared()
        manifest = probe.load_manifest(path)
        operations.install(path, runner=self.manual_runner(manifest))
        stage = Path(manifest["staged_plist"])

        def change(count):
            if count == 2:
                stage.unlink()
                stage.write_bytes(b"foreign-stage")

        with self.assertRaises(ValueError):
            operations.cleanup(
                path, runner=self.manual_runner(manifest, on_print=change)
            )
        self.assertEqual(stage.read_bytes(), b"foreign-stage")
        self.assert_no_destructive_commands()

    def test_interrupted_cleanup_can_resume_from_same_manifest_in_new_call(self):
        operations = load_operations()
        workspace, path = self.prepared()
        manifest = probe.load_manifest(path)
        operations.install(path, runner=self.manual_runner(manifest))
        stage = Path(manifest["staged_plist"])
        base = self.manual_runner(manifest)

        def fail_stage(command, **kwargs):
            if command == ["/usr/bin/trash", str(stage)]:
                return subprocess.CompletedProcess(
                    command, 1, "", "fixture interruption"
                )
            return base(command, **kwargs)

        with self.assertRaises(ValueError):
            operations.cleanup(path, runner=fail_stage)
        self.assertFalse(Path(manifest["installed_plist"]).exists())
        self.assertTrue(stage.exists())
        self.assertTrue(path.exists())
        operations.cleanup(path, runner=self.manual_runner(manifest))
        self.assertFalse(stage.exists())
        self.assertFalse(workspace.exists())
        self.assertFalse(any(c[1] == "bootout" for c in self.manual_calls))

    def test_cleanup_revalidates_uid_job_and_installed_identity(self):
        operations = load_operations()
        _, path = self.prepared()
        manifest = probe.load_manifest(path)
        operations.install(path, runner=self.manual_runner(manifest))
        installed = Path(manifest["installed_plist"])
        original = installed.read_bytes()
        installed.unlink()
        installed.write_bytes(original)
        runner = self.manual_runner(manifest, registered=True)
        with self.assertRaises(ValueError):
            operations.cleanup(path, runner=runner)
        self.assertEqual(installed.read_bytes(), original)
        self.assertFalse(any(c[1] == "bootout" for c in self.manual_calls))
        self.assertFalse(any(c[0].endswith("trash") for c in self.manual_calls))

    def test_no_events_or_pid_with_launch_attempt_is_not_success(self):
        operations = load_operations()
        self.assertEqual(
            operations.no_start_verdict(
                events_changed=False,
                pid=None,
                runs=1,
                termination="exec failure: 2",
                evidence_complete=True,
            ),
            "unexpected-start",
        )
        self.assertEqual(
            operations.no_start_verdict(
                events_changed=False,
                pid=None,
                runs=None,
                termination=None,
                evidence_complete=False,
            ),
            "inconclusive",
        )

    def test_observe_uses_launchd_attempt_and_error_evidence_not_just_empty_events(
        self,
    ):
        operations = load_operations()
        workspace, path = self.prepared()
        manifest = probe.load_manifest(path)
        for replacement, expected in (
            (("runs = 0", "runs = 1"), "unexpected-start"),
            (("(never exited)", "1"), "unexpected-start"),
            (("runs = 0", "runs = 0\n\tlast spawn error = 2"), "unexpected-start"),
            (("runs = 0", "runs = 0\n\tlast exec error = 2"), "unexpected-start"),
            (
                ("runs = 0", "runs = 0\n\tlast terminating signal = SIGABRT"),
                "unexpected-start",
            ),
            (("runs = 0", "runs = 0"), "inconclusive"),
            (("runs = 0", "runs = 0\n\tlast spawn error = 0"), "no-start-candidate"),
        ):
            with self.subTest(replacement=replacement):
                base = self.manual_runner(manifest, registered=True)

                def run(command, **kwargs):
                    result = base(command, **kwargs)
                    result.stdout = result.stdout.replace(*replacement)
                    return result

                self.assertEqual(operations.observe(path, runner=run), expected)
                self.assertEqual((workspace / "events.log").read_bytes(), b"")
                self.assert_no_destructive_commands()
        (workspace / "baseline.log").write_bytes(b"previous deliberate events\n")
        (workspace / "events.log").write_bytes(b"previous deliberate events\n")
        self.assertEqual(
            operations.observe(
                path, relogin=True, runner=self.manual_runner(manifest, registered=True)
            ),
            "inconclusive",
        )

    def test_record_output_failure_exits_nonzero_in_test_only_shim(self):
        fixture = self.root / "test-only-shim"
        fixture.mkdir()
        (fixture / "probe.c").write_text(SOURCE.with_name("probe.c").read_text())
        (fixture / "config.h").write_text(
            '#define PROBE_LABEL "test-only"\n#define PROBE_WORKSPACE "/never-used"\n'
        )
        shim = fixture / "shim.c"
        shim.write_text(
            "#include <stdio.h>\n#include <errno.h>\n#include <string.h>\n"
            "static int mode;\n"
            "static int test_fprintf(FILE *f, const char *format, ...) {\n"
            " (void)f; (void)format; errno = EIO; return mode == 1 ? -1 : 1; }\n"
            "static int test_fflush(FILE *f) { (void)f; errno = EIO; return mode == 2 ? EOF : 0; }\n"
            "static int test_fclose(FILE *f) { (void)f; errno = EIO; return mode == 3 ? EOF : 0; }\n"
            "#define fprintf test_fprintf\n#define fflush test_fflush\n"
            "#define fclose test_fclose\n"
            '#define main never_run_production_main\n#include "probe.c"\n#undef main\n'
            "int main(int argc, char **argv) {\n"
            ' if (argc > 1 && strcmp(argv[1], "fprintf") == 0) mode = 1;\n'
            ' else if (argc > 1 && strcmp(argv[1], "fflush") == 0) mode = 2;\n'
            ' else if (argc > 1 && strcmp(argv[1], "fclose") == 0) mode = 3;\n'
            ' record(NULL, "test", "start"); return finish(NULL); }\n'
        )
        binary = fixture / "test-only-record-shim"
        REAL_RUN(
            [
                "/usr/bin/xcrun",
                "--sdk",
                "macosx",
                "clang",
                "-std=c11",
                "-Wall",
                "-Wextra",
                "-Werror",
                str(shim),
                "-o",
                str(binary),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        for operation in ("fprintf", "fflush", "fclose"):
            with self.subTest(operation=operation):
                result = REAL_RUN(
                    [str(binary), operation], capture_output=True, text=True
                )
                self.assertNotEqual(result.returncode, 0)
        self.assertEqual(REAL_RUN([str(binary), "success"]).returncode, 0)


if __name__ == "__main__":
    unittest.main()
