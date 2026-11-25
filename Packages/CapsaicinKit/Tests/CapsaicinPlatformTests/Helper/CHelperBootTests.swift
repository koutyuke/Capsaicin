import Foundation
import Testing

struct CHelperBootTests {
    @Test("SPEC-HLP-003 本番の後片付けは初回に記録だけ行い、別の起動と読めない記録で off を行う")
    func bootCleanup() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent(".build/helper-boot/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Sources/capsaicin-helper/boot.c")
        let object = directory.appendingPathComponent("boot.o")
        let harness = directory.appendingPathComponent("harness.c")
        let fixture = directory.appendingPathComponent("helper-boot-fixture")
        let state = directory.appendingPathComponent("state")
        try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try Self.harness.write(to: harness, atomically: true, encoding: .utf8)
        let flags = ["--sdk", "macosx", "clang", "-std=c17", "-fblocks", "-Wall", "-Wextra", "-Werror"]
        // 固定パスの親だけをフィクスチャへ向け、所有者と sysctl と off を置き換える。
        let compile = try CHelperContractTests.run("/usr/bin/xcrun", flags + [
            "-Dopen=fake_open", "-Dfstat=fake_fstat", "-Dsysctlbyname=fake_sysctlbyname",
            "-Dhelper_set_sleep_disabled=fake_off", "-DHELPER_APP_IDENTIFIER=\"test.helper\"",
            "-c", source.path, "-o", object.path,
        ])
        try #require(compile.status == 0, "\(compile.output)")
        let symbols = try CHelperContractTests.run("/usr/bin/xcrun", ["nm", "-u", "-j", object.path])
        try #require(symbols.status == 0)
        let undefined = Set(symbols.output.split(whereSeparator: \.isWhitespace).map(String.init))
        try #require(undefined.isSubset(of: [
            "___error", "___snprintf_chk", "___stack_chk_fail", "___stack_chk_guard", "_arc4random", "_close",
            "_fake_fstat", "_fake_off", "_fake_open", "_fake_sysctlbyname", "_fsync", "_memset", "_mkdirat",
            "_openat", "_read", "_renameat", "_strcmp", "_strlen", "_unlinkat", "_uuid_parse", "_write",
        ]), "\(undefined)")
        try #require(undefined.contains("_fake_off") && undefined.contains("_fake_open"))
        let link = try CHelperContractTests.run(
            "/usr/bin/xcrun",
            flags + [object.path, harness.path, "-o", fixture.path],
        )
        try #require(link.status == 0, "\(link.output)")
        let result = try CHelperContractTests.run(fixture.path, [state.path])
        #expect(result.status == 0, "\(result.output)")
    }

    private static let harness = #"""
    #include <assert.h>
    #include <fcntl.h>
    #include <stdbool.h>
    #include <stdio.h>
    #include <string.h>
    #include <sys/stat.h>
    #include <unistd.h>

    int cleanup_boot(void);
    static const char *parent;
    static const char *boot = "00000000-0000-0000-0000-000000000001";
    static int off_calls;
    static bool off_success = true;
    static bool root_owner = true;

    int fake_open(const char *path, int flags, ...) {
        assert(!strcmp(path, "/Library/Application Support"));
        return open(parent, flags);
    }

    int fake_fstat(int fd, struct stat *info) {
        int result = fstat(fd, info);
        if (!result) info->st_uid = root_owner ? 0 : 501;
        return result;
    }

    int fake_sysctlbyname(const char *name, void *output, size_t *length, void *input, size_t input_length) {
        assert(!strcmp(name, "kern.bootsessionuuid") && !input && !input_length && *length == 37);
        memcpy(output, boot, 37);
        return 0;
    }

    bool fake_off(bool disabled) {
        assert(!disabled);
        ++off_calls;
        return off_success;
    }

    static void record_is(const char *expected) {
        char path[4096];
        snprintf(path, sizeof(path), "%s/test.helper/boot-session-uuid", parent);
        int fd = open(path, O_RDONLY | O_NOFOLLOW);
        assert(fd >= 0);
        struct stat info;
        assert(!fstat(fd, &info) && (info.st_mode & 0777) == 0600);
        char contents[38] = {0};
        assert(read(fd, contents, sizeof(contents) - 1) == 36);
        close(fd);
        assert(!strcmp(contents, expected));
    }

    int main(int argc, char *argv[]) {
        assert(argc == 2);
        parent = argv[1];
        assert(cleanup_boot() == 0 && off_calls == 0);
        record_is(boot);
        assert(cleanup_boot() == 0 && off_calls == 0);
        const char *old = boot;
        boot = "00000000-0000-0000-0000-000000000002";
        off_success = false;
        assert(cleanup_boot() == -1 && off_calls == 1);
        record_is(old);
        off_success = true;
        assert(cleanup_boot() == 0 && off_calls == 2);
        record_is(boot);
        assert(cleanup_boot() == 0 && off_calls == 2);
        root_owner = false;
        assert(cleanup_boot() == -1 && off_calls == 2);
        root_owner = true;
        char path[4096];
        snprintf(path, sizeof(path), "%s/test.helper/boot-session-uuid", parent);
        assert(chmod(path, 0666) == 0);
        assert(cleanup_boot() == 0 && off_calls == 3);
        record_is(boot);
        int file = open(path, O_WRONLY | O_TRUNC);
        assert(file >= 0 && write(file, "invalid", 7) == 7);
        close(file);
        assert(cleanup_boot() == 0 && off_calls == 4);
        record_is(boot);
        assert(unlink(path) == 0);
        assert(symlink("/untrusted", path) == 0);
        assert(cleanup_boot() == 0 && off_calls == 5);
        record_is(boot);
        assert(chmod(parent, 0777) == 0);
        assert(cleanup_boot() == -1 && off_calls == 5);
        assert(chmod(parent, 0700) == 0);
        return 0;
    }
    """#
}
