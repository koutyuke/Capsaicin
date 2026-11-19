import Foundation
import Testing

struct CHelperContractTests {
    @Test("SPEC-HLP-002 本番の辞書検証と固定 posix_spawn を、root も登録もなしに確かめる")
    func commandContract() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent(".build/helper-contract/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Sources/capsaicin-helper/request.c")
        let object = directory.appendingPathComponent("request.o")
        let harness = directory.appendingPathComponent("harness.c")
        let fixture = directory.appendingPathComponent("helper-contract-fixture")
        try Self.harness.write(to: harness, atomically: true, encoding: .utf8)
        // デーモンの入口と後片付けはリンクせず、pmset の起動と waitpid は検証用の関数に置き換える。
        let flags = ["--sdk", "macosx", "clang", "-std=c17", "-fblocks", "-Wall", "-Wextra", "-Werror"]
        let compile = try Self.run("/usr/bin/xcrun", flags + [
            "-Dposix_spawn=fake_posix_spawn", "-Dwaitpid=fake_waitpid", "-c", source.path, "-o", object.path,
        ])
        try #require(compile.status == 0, "\(compile.output)")
        let symbols = try Self.run("/usr/bin/xcrun", ["nm", "-u", "-j", object.path])
        try #require(symbols.status == 0)
        let undefined = Set(symbols.output.split(whereSeparator: \.isWhitespace).map(String.init))
        // 置換されていないプロセス起動が増えた場合は、fixture をリンクする前に止める。
        try #require(undefined.isSubset(of: [
            "___error", "___stack_chk_fail", "___stack_chk_guard", "__xpc_type_dictionary", "__xpc_type_string",
            "_fake_posix_spawn", "_fake_waitpid", "_memcmp", "_xpc_dictionary_get_count", "_xpc_dictionary_get_value",
            "_xpc_get_type", "_xpc_string_get_length", "_xpc_string_get_string_ptr",
        ]), "\(undefined)")
        try #require(undefined.contains("_fake_posix_spawn") && undefined.contains("_fake_waitpid"))
        let link = try Self.run("/usr/bin/xcrun", flags + [
            object.path, harness.path, "-I", source.deletingLastPathComponent().path, "-o", fixture.path,
        ])
        try #require(link.status == 0, "\(link.output)")
        let result = try Self.run(fixture.path, [])
        #expect(result.status == 0, "\(result.output)")
    }

    static func run(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ["PATH": "/untrusted", "IFS": "on", "CAPSAICIN_HELPER_TEST": "inherited"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return try (process.terminationStatus, #require(String(data: data, encoding: .utf8)))
    }

    private static let harness = #"""
    #include "request.h"
    #include <assert.h>
    #include <errno.h>
    #include <spawn.h>
    #include <string.h>
    #include <sys/wait.h>

    static int calls;
    static const char *expected;
    static int spawn_error;
    static int exit_status;
    static int wait_error;
    static int interrupted;

    int fake_posix_spawn(pid_t *pid, const char *path, const posix_spawn_file_actions_t *actions,
                         const posix_spawnattr_t *attributes, char *const argv[], char *const envp[]) {
        assert(expected != NULL);
        ++calls;
        assert(!strcmp(path, "/usr/bin/pmset"));
        assert(actions == NULL && attributes == NULL);
        assert(!strcmp(argv[0], path) && !strcmp(argv[1], "-a") && !strcmp(argv[2], "disablesleep"));
        assert(!strcmp(argv[3], expected) && argv[4] == NULL);
        assert(envp && envp[0] == NULL);
        *pid = 123;
        return spawn_error;
    }

    pid_t fake_waitpid(pid_t pid, int *status, int options) {
        assert(pid == 123 && options == 0);
        if (interrupted) { interrupted = 0; errno = EINTR; return -1; }
        if (wait_error) { errno = ECHILD; return -1; }
        *status = exit_status;
        return pid;
    }

    static void rejected(xpc_object_t request) {
        int before = calls;
        assert(!helper_handle_request(request));
        assert(calls == before);
        xpc_release(request);
    }

    int main(void) {
        xpc_object_t request = xpc_dictionary_create_empty();
        expected = "1";
        xpc_dictionary_set_string(request, "command", "on");
        assert(helper_handle_request(request) && calls == 1);
        expected = "0";
        xpc_dictionary_set_string(request, "command", "off");
        interrupted = 1;
        assert(helper_handle_request(request) && calls == 2);
        spawn_error = EACCES;
        assert(!helper_handle_request(request));
        spawn_error = 0;
        exit_status = 1 << 8;
        assert(!helper_handle_request(request));
        exit_status = SIGTERM;
        assert(!helper_handle_request(request));
        exit_status = 0;
        wait_error = 1;
        assert(!helper_handle_request(request));
        wait_error = 0;
        xpc_release(request);
        expected = NULL;
        const char *invalid[] = {"", "ON", "OFF", "On", "off ", " on", "on\n", "on;off", "$(on)", "--on"};
        for (unsigned i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
            request = xpc_dictionary_create_empty();
            xpc_dictionary_set_string(request, "command", invalid[i]);
            rejected(request);
        }
        request = xpc_dictionary_create_empty();
        rejected(request);
        request = xpc_dictionary_create_empty();
        xpc_dictionary_set_string(request, "command", "on");
        xpc_dictionary_set_string(request, "path", "/untrusted");
        rejected(request);
        xpc_object_t values[] = {xpc_bool_create(true), xpc_int64_create(1), xpc_double_create(1),
                                xpc_data_create("on", 2), xpc_array_create_empty(), xpc_dictionary_create_empty()};
        for (unsigned i = 0; i < sizeof(values) / sizeof(values[0]); ++i) {
            request = xpc_dictionary_create_empty();
            xpc_dictionary_set_value(request, "command", values[i]);
            xpc_release(values[i]);
            rejected(request);
        }
        rejected(xpc_array_create_empty());
        rejected(xpc_string_create("on"));
        return 0;
    }
    """#
}
