import CapsaicinCore
@testable import CapsaicinPlatform
import Darwin
import Foundation
import Testing

@MainActor
struct FileResumeRecordStoreSafetyTests {
    @Test("SPEC-LCY-007 不正な既存ファイルを開いて待たず、修復も置換もしない", arguments: [
        "symlink", "directory", "fifo", "hardlink", "public", "unreadable",
    ])
    func rejectsUnsafeFiles(kind: String) throws {
        try withStorageFixture { fixture in
            let store = try fixture.store()
            #expect(store.save(fixture.record))
            let original = try Data(contentsOf: fixture.file)
            let outside = fixture.root.appendingPathComponent("outside.json")
            try original.write(to: outside)
            if kind == "public" || kind == "unreadable" {
                #expect(chmod(fixture.file.path, kind == "public" ? 0o644 : 0) == 0)
                defer { _ = chmod(fixture.file.path, 0o600) }
                #expect(store.load() == nil)
                #expect(!store.save(fixture.record))
                #expect(try fixture.mode(of: fixture.file) == (kind == "public" ? 0o644 : 0))
            } else {
                try FileManager.default.removeItem(at: fixture.file)
                switch kind {
                case "symlink":
                    #expect(symlink(outside.path, fixture.file.path) == 0)
                case "directory":
                    #expect(mkdir(fixture.file.path, 0o700) == 0)
                case "fifo":
                    #expect(mkfifo(fixture.file.path, 0o600) == 0)
                default:
                    #expect(chmod(outside.path, 0o600) == 0)
                    #expect(link(outside.path, fixture.file.path) == 0)
                }
                var before = stat()
                #expect(lstat(fixture.file.path, &before) == 0)
                #expect(store.load() == nil)
                #expect(!store.save(fixture.record))
                var after = stat()
                #expect(lstat(fixture.file.path, &after) == 0)
                #expect(before.st_ino == after.st_ino)
                #expect(before.st_mode == after.st_mode)
            }
            #expect(try Data(contentsOf: outside) == original)
            #expect(try FileManager.default
                .contentsOfDirectory(atPath: fixture.directory.path) == ["resume-record.json"])
        }
    }

    @Test("SPEC-LCY-007 不正な専用ディレクトリは追跡せず権限も変えない", arguments: [
        "symlink", "file", "fifo", "public", "unreadable",
    ])
    func rejectsUnsafeDirectory(kind: String) throws {
        try withStorageFixture { fixture in
            let store = try fixture.store()
            if kind == "public" || kind == "unreadable" {
                #expect(mkdir(fixture.directory.path, kind == "public" ? 0o755 : 0) == 0)
            } else if kind == "symlink" {
                let outside = fixture.root.appendingPathComponent("outside")
                try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
                #expect(symlink(outside.path, fixture.directory.path) == 0)
            } else if kind == "fifo" {
                #expect(mkfifo(fixture.directory.path, 0o700) == 0)
            } else {
                try Data("untouched".utf8).write(to: fixture.directory)
            }
            var before = stat()
            #expect(lstat(fixture.directory.path, &before) == 0)
            defer {
                if kind == "unreadable" {
                    _ = chmod(fixture.directory.path, 0o700)
                }
            }
            #expect(store.load() == nil)
            #expect(!store.save(fixture.record))
            var after = stat()
            #expect(lstat(fixture.directory.path, &after) == 0)
            #expect(before.st_ino == after.st_ino)
            #expect(before.st_mode == after.st_mode)
            if kind == "symlink" {
                let entries = try FileManager.default.contentsOfDirectory(
                    atPath: fixture.root.appendingPathComponent("outside").path,
                )
                #expect(entries.isEmpty)
            }
        }
    }

    @Test("SPEC-LCY-007 注入したルート自体が symlink なら保存先を追跡しない")
    func rejectsSymlinkRoot() throws {
        try withStorageFixture { fixture in
            let alias = fixture.root.appendingPathComponent("alias")
            #expect(symlink(fixture.root.path, alias.path) == 0)
            let store = try FileResumeRecordStore(bundleID: fixture.bundleID, applicationSupportDirectory: alias)
            #expect(store.load() == nil)
            #expect(!store.save(fixture.record))
            #expect(!FileManager.default.fileExists(atPath: fixture.directory.path))
        }
    }

    @Test("SPEC-LCY-007 所有 UID や特殊な権限をメタデータ境界で拒否する")
    func validatesOwner() throws {
        try withStorageFixture { fixture in
            let store = try fixture.store()
            #expect(store.save(fixture.record))
            var info = stat()
            #expect(lstat(fixture.file.path, &info) == 0)
            #expect(FileResumeRecordStore.isPrivate(info, type: S_IFREG, permissions: 0o600))
            info.st_uid = geteuid() == 0 ? 1 : 0
            #expect(!FileResumeRecordStore.isPrivate(info, type: S_IFREG, permissions: 0o600))
            info.st_uid = geteuid()
            info.st_mode |= 0o4000
            #expect(!FileResumeRecordStore.isPrivate(info, type: S_IFREG, permissions: 0o600))
        }
    }

    @Test("SPEC-LCY-007 エンコード失敗は記録もディレクトリも変更しない")
    func encodingFailure() throws {
        try withStorageFixture { fixture in
            let store = try fixture.store()
            let invalid = ResumeRecord(lastUpdated: Date(timeIntervalSinceReferenceDate: .infinity))
            #expect(!store.save(invalid))
            #expect(!FileManager.default.fileExists(atPath: fixture.directory.path))
            #expect(store.save(fixture.record))
            let original = try Data(contentsOf: fixture.file)
            #expect(!store.save(invalid))
            #expect(try Data(contentsOf: fixture.file) == original)
        }
    }
}
