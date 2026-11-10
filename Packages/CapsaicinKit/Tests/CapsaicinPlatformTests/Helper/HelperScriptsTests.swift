@testable import CapsaicinPlatform
import Foundation
import Testing

struct HelperScriptsTests {
    @Test("SPEC-HLP-001 SPEC-HLP-004 外から受け取るパスと uid を検証する")
    func invalidInputs() {
        for path in ["", "relative/helper", "/bad\0/helper"] {
            #expect(throws: HelperError.invalidInstallerInput) {
                try HelperScripts.install(paths: .current, bundledHelperPath: path, uid: 501)
            }
        }
        #expect(throws: HelperError.invalidInstallerInput) {
            try HelperScripts.install(
                paths: .current,
                bundledHelperPath: "/App/Contents/Helpers/capsaicin-helper",
                uid: 0,
            )
        }
    }

    @Test("SPEC-HLP-001 引用したパスはシェルと AppleScript の両方で元の文字列を保つ", arguments: [
        "/Applications/Capsaicin.app/Contents/Helpers/capsaicin-helper",
        "/space and 'single' and \"double\"/capsaicin-helper",
        "/line\nreturn\rtab\t$HOME\\backslash/$(printf INJECTED); echo INJECTED/capsaicin-helper",
    ])
    func quoting(path: String) throws {
        let command = "/usr/bin/printf '%s' " + HelperScripts.shellQuote(path)
        let runner = CommandRunner(executable: "/bin/sh", arguments: ["-c", command], outputLimit: 4096)
        #expect(try runner.run(timeout: 2) == Data(path.utf8))
        let install = try HelperScripts.install(paths: .current, bundledHelperPath: path, uid: 501)
        #expect(install.contains("source=" + HelperScripts.shellQuote(path)))
        let wrapped = HelperScripts.appleScript(install)
        let prefix = "    do shell script "
        let line = try #require(wrapped.split(separator: "\n").first { $0.hasPrefix(prefix) })
        let literal = line.dropFirst(prefix.count).dropLast(" with administrator privileges".count)
        // 両言語で共通の文字列エスケープを、別のデコーダーで確かめる。
        let decoded = try JSONSerialization.jsonObject(with: Data(literal.utf8), options: .fragmentsAllowed)
        #expect(decoded as? String == install)
        try checkShellSyntax(install)
    }

    @Test("SPEC-HLP-001 SPEC-HLP-003 設置の順序、所有者、権限と起動時 off を固定する")
    func installationOrder() throws {
        for debug in [false, true] {
            let paths = HelperPaths(debug: debug)
            let script = try HelperScripts.install(
                paths: paths,
                bundledHelperPath: "/App/Contents/Helpers/capsaicin-helper",
                uid: 501,
            )
            try expectOrder(script, [
                "source_hash=", "/usr/bin/install -o root -g wheel -m 755", "installed_hash=",
                "/bin/test \"$source_hash\" = \"$installed_hash\"", "rules=$(/usr/bin/mktemp",
                "/usr/sbin/chown root:wheel \"$rules\"", "/bin/chmod 440 \"$rules\"",
                "/usr/sbin/visudo -c -f \"$rules\"", "/bin/mv -f \"$rules\"",
                "<key>Label</key>", "/bin/chmod 644",
            ])
            // 引数なしの visudo -c はほかのツールの sudoers の権限でも失敗するので、自分のルールだけを検証する。
            #expect(script.components(separatedBy: "/usr/sbin/visudo").count == 2)
            #expect(script.contains(HelperScripts.shellQuote(paths.sudoers + ".XXXXXX")))
            #expect(script.contains("trap '/bin/rm -f \"$rules\"' EXIT"))
            #expect(!script.contains("launchctl"))
            #expect(HelperScripts.sudoers(paths: paths, uid: 501) ==
                "#501 ALL=(root) NOPASSWD: \(paths.helper) on, \(paths.helper) off")
            let data = Data(HelperScripts.daemonPlist(paths: paths).utf8)
            let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
            #expect(plist["Label"] as? String == paths.label)
            #expect(plist["ProgramArguments"] as? [String] == [paths.helper, "off"])
            #expect(plist["RunAtLoad"] as? Bool == true)
            #expect(plist["KeepAlive"] == nil)
            try checkShellSyntax(script)
        }
    }

    @Test("SPEC-HLP-004 SPEC-HLP-005 削除は選択時だけ最初に戻し、設置の逆順に行う")
    func removalOrder() throws {
        let paths = HelperPaths(debug: true)
        for restore in [false, true] {
            let script = HelperScripts.remove(paths: paths, restoreSleep: restore)
            #expect(script
                .hasPrefix("set -eu\n" + (restore ? "/usr/bin/pmset -a disablesleep 0\n" : "if /bin/launchctl")))
            #expect(script.contains("/usr/bin/pmset") == restore)
            try expectOrder(script, [
                "/bin/launchctl print system/\(paths.label)", "/bin/launchctl bootout system/\(paths.label)",
                "/bin/rm -f '\(paths.daemon)'", "/bin/rm -f '\(paths.sudoers)'",
                "/bin/rm -f '\(paths.helper)'",
            ])
            #expect(!script.contains("visudo"))
            try checkShellSyntax(script)
        }
    }

    @Test("SPEC-HLP-001 SPEC-HLP-004 Debug は3つの設置先とラベルを Release から分離する")
    func debugSeparation() {
        let debug = HelperPaths(debug: true)
        let release = HelperPaths(debug: false)
        #expect(Set(debug.files).isDisjoint(with: release.files))
        #expect(debug.label != release.label)
        #expect(debug.helper.hasSuffix(".debug"))
        for paths in [debug, release] {
            #expect(!URL(fileURLWithPath: paths.sudoers).lastPathComponent.contains("."))
        }
        #if DEBUG
            #expect(HelperPaths.current.files == debug.files)
        #else
            #expect(HelperPaths.current.files == release.files)
        #endif
    }

    @Test("SPEC-HLP-001 SPEC-HLP-006 管理者認証は1回で -128 だけを取り消しにする")
    func authorizationWrapper() {
        let script = HelperScripts.appleScript("exit 1")
        #expect(script.components(separatedBy: "with administrator privileges").count == 2)
        #expect(script.contains("if errorNumber is -128 then return \"cancelled\""))
        #expect(script.contains("return \"failed:\" & errorNumber & \":\" & messageText"))
    }

    @Test("SPEC-HLP-001 sudoers を一般ユーザーで検証し、AppleScript はコンパイルだけ行う")
    func nativeSyntaxValidation() throws {
        try #require(geteuid() != 0, "root ではこの検証を実行しない")
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent(".build/task006-helper-scripts/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record("専用フィクスチャの削除に失敗: \(error)") }
        }
        for debug in [false, true] {
            let paths = HelperPaths(debug: debug)
            let rules = directory.appendingPathComponent("rules")
            try HelperScripts.sudoers(paths: paths, uid: 501).appending("\n")
                .write(to: rules, atomically: true, encoding: .utf8)
            let visudo = CommandRunner(executable: "/usr/sbin/visudo", arguments: ["-c", "-f", rules.path])
            #expect(try visudo.run(timeout: 5).isEmpty)
            let install = try HelperScripts.install(paths: paths, bundledHelperPath: "/'\"\n$\\/helper", uid: 501)
            for script in [install, HelperScripts.remove(paths: paths, restoreSleep: true)] {
                let compiler = CommandRunner(executable: "/usr/bin/osacompile", arguments: [
                    "-o", directory.appendingPathComponent("compiled.scpt").path,
                    "-e", HelperScripts.appleScript(script),
                ])
                #expect(try compiler.run(timeout: 5).isEmpty)
            }
        }
    }

    private func checkShellSyntax(_ script: String) throws {
        // -n で構文解析するだけで、生成した設置・削除コマンドは一切実行しない。
        let runner = CommandRunner(executable: "/bin/sh", arguments: ["-n", "-c", script])
        #expect(try runner.run(timeout: 2).isEmpty)
    }

    private func expectOrder(_ script: String, _ parts: [String]) throws {
        var remaining = script[...]
        for part in parts {
            let range = try #require(remaining.range(of: part), "順序が違うか、見つからない: \(part)")
            remaining = remaining[range.upperBound...]
        }
    }
}
