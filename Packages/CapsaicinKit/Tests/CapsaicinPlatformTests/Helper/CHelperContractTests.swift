import Foundation
import Testing

struct CHelperContractTests {
    @Test("SPEC-HLP-002 本番 C は固定 execve と空の環境だけを使い、不正引数を副作用なく拒否する")
    func commandContract() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent(".build/task006-c-helper/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("専用フィクスチャの削除に失敗: \(error)")
            }
        }
        let source = root.appendingPathComponent("Sources/capsaicin-helper/main.c")
        let object = directory.appendingPathComponent("helper-test.o")
        let harness = directory.appendingPathComponent("harness.c")
        let fixture = directory.appendingPathComponent("helper-contract-fixture")
        try Self.harness.write(to: harness, atomically: true, encoding: .utf8)

        // 本番バイナリを有効引数で起動しない。置換済みオブジェクトだけを別名の fixture にリンクする。
        let definitions = ["-Dmain=helper_test_main", "-Dexecve=fake_execve"]
        try #require(definitions == ["-Dmain=helper_test_main", "-Dexecve=fake_execve"])
        let flags = ["--sdk", "macosx", "clang", "-std=c17", "-Wall", "-Wextra", "-Werror"]
        let compile = try Self.run("/usr/bin/xcrun", flags + definitions + [
            "-c", source.path, "-o", object.path,
        ])
        try #require(compile.status == 0, "\(compile.output)")
        let symbols = try Self.run("/usr/bin/xcrun", ["--sdk", "macosx", "nm", "-u", "-j", object.path])
        try #require(symbols.status == 0, "\(symbols.output)")
        let undefined = Set(symbols.output.split(whereSeparator: \.isWhitespace).map(String.init))
        // 実 execve への参照が残れば、リンクも実行もしない。
        try #require(undefined.isSubset(of: [
            "_fake_execve", "_strcmp", "___stack_chk_fail", "___stack_chk_guard",
        ]), "\(undefined)")
        let link = try Self.run("/usr/bin/xcrun", flags + [object.path, harness.path, "-o", fixture.path])
        try #require(link.status == 0, "\(link.output)")

        for command in ["on", "off"] {
            for name in ["capsaicin-helper", "/untrusted/pmset;$(ignored)"] {
                let result = try Self.run(fixture.path, [name, command])
                #expect(result.status == 71)
                #expect(result.output == "fixed execve verified\n")
            }
        }
        for arguments in Self.invalidArguments {
            let result = try Self.run(fixture.path, ["untrusted argv0"] + arguments)
            #expect(result.status == 64, "\(arguments)")
            #expect(result.output.isEmpty, "不正引数で execve が呼ばれた: \(arguments)")
        }
        let zero = try Self.run(fixture.path, ["--argc-zero"])
        #expect(zero.status == 64)
        #expect(zero.output.isEmpty)
    }

    private static func run(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ["CAPSAICIN_HELPER_TEST": "inherited", "PATH": "/untrusted", "IFS": "on"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return try (process.terminationStatus, #require(String(data: data, encoding: .utf8)))
    }

    private static let invalidArguments: [[String]] = [
        [], ["--help"], ["unexpected", "argument"], ["on", "extra"], ["off", "extra"],
        [""], ["ON"], ["OFF"], ["On"], ["off "], [" on"], ["on\n"],
        ["on;off"], ["$(on)"], ["on && off"], ["--on"],
    ]

    private static let harness = #"""
    #include <assert.h>
    #include <errno.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    int helper_test_main(int argc, char *argv[]);
    static const char *expected_value;
    static int calls;

    int fake_execve(const char *path, char *const argv[], char *const envp[]) {
        assert(expected_value != NULL);
        assert(++calls == 1);
        assert(strcmp(path, "/usr/bin/pmset") == 0);
        assert(argv != NULL);
        assert(argv[0] != NULL && strcmp(argv[0], "/usr/bin/pmset") == 0);
        assert(argv[1] != NULL && strcmp(argv[1], "-a") == 0);
        assert(argv[2] != NULL && strcmp(argv[2], "disablesleep") == 0);
        assert(argv[3] != NULL && strcmp(argv[3], expected_value) == 0);
        assert(argv[4] == NULL);
        assert(envp != NULL && envp[0] == NULL);
        puts("fixed execve verified");
        errno = EACCES;
        return -1;
    }

    int main(int argc, char *argv[]) {
        assert(getenv("CAPSAICIN_HELPER_TEST") != NULL);
        if (argc == 2 && strcmp(argv[1], "--argc-zero") == 0) {
            char *empty[] = {NULL};
            return helper_test_main(0, empty);
        }
        assert(argc >= 2);
        if (argc == 3 && strcmp(argv[2], "on") == 0) {
            expected_value = "1";
        } else if (argc == 3 && strcmp(argv[2], "off") == 0) {
            expected_value = "0";
        }
        return helper_test_main(argc - 1, argv + 1);
    }
    """#
}
