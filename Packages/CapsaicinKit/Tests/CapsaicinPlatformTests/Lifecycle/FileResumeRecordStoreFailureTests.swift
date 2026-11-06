import CapsaicinCore
@testable import CapsaicinPlatform
import Darwin
import Foundation
import Testing

@MainActor
struct FileResumeRecordStoreFailureTests {
    @Test("SPEC-LCY-007 短い write と EINTR の後も全バイトを書いてから置換する")
    func shortWritesAndInterruption() throws {
        try withStorageFixture { fixture in
            var operations = ResumeRecordFileOperations()
            var calls = 0
            operations.write = { descriptor, pointer, count in
                calls += 1
                if calls == 1 {
                    errno = EINTR
                    return -1
                }
                return Darwin.write(descriptor, pointer, min(count, 7))
            }
            let store = try fixture.store(operations: operations)
            #expect(store.save(fixture.record))
            #expect(calls > 2)
            #expect(store.load() == fixture.record)
        }
    }

    @Test("SPEC-LCY-007 置換前の失敗では旧記録と無関係なファイルを保ち、自分の一時記録だけを消す", arguments: [
        "write", "zeroWrite", "close", "closeInterrupted", "rename",
    ])
    func failurePreservesOldRecord(point: String) throws {
        try withStorageFixture { fixture in
            let originalStore = try fixture.store()
            #expect(originalStore.save(fixture.record))
            let original = try Data(contentsOf: fixture.file)
            let unrelated = fixture.directory.appendingPathComponent(".resume-record-unrelated.tmp")
            try Data("not ours".utf8).write(to: unrelated)
            var operations = ResumeRecordFileOperations()
            var capturedFD: Int32 = -1
            var writes = 0
            operations.write = { descriptor, pointer, count in
                capturedFD = descriptor
                writes += 1
                if point == "write" {
                    if writes == 1 {
                        return Darwin.write(descriptor, pointer, min(5, count))
                    }
                    errno = ENOSPC
                    return -1
                }
                if point == "zeroWrite" {
                    return 0
                }
                return Darwin.write(descriptor, pointer, count)
            }
            operations.closeTemporary = { descriptor in
                let result = Darwin.close(descriptor)
                guard point == "close" || point == "closeInterrupted" else { return result }
                errno = point == "close" ? EIO : EINTR
                return -1
            }
            operations.rename = { _, _, _, _ in
                #expect(point == "rename")
                #expect((try? Data(contentsOf: fixture.file)) == original)
                errno = EACCES
                return -1
            }
            let store = try fixture.store(operations: operations)
            let replacement = ResumeRecord(lastUpdated: fixture.record.lastUpdated.addingTimeInterval(1))
            #expect(!store.save(replacement))
            #expect(capturedFD >= 0)
            #expect(fcntl(capturedFD, F_GETFD) == -1)
            #expect(errno == EBADF)
            #expect(try Data(contentsOf: fixture.file) == original)
            #expect(store.load() == fixture.record)
            #expect(try Data(contentsOf: unrelated) == Data("not ours".utf8))
            #expect(try Set(FileManager.default.contentsOfDirectory(atPath: fixture.directory.path)) == [
                "resume-record.json", ".resume-record-unrelated.tmp",
            ])
        }
    }

    @Test("SPEC-LCY-007 rename の直前には旧記録と完全な新記録が同じディレクトリにある")
    func commitBoundary() throws {
        try withStorageFixture { fixture in
            let originalStore = try fixture.store()
            #expect(originalStore.save(fixture.record))
            let original = try Data(contentsOf: fixture.file)
            let replacement = ResumeRecord(lastUpdated: fixture.record.lastUpdated.addingTimeInterval(1))
            var operations = ResumeRecordFileOperations()
            var commits = 0
            operations.rename = { fromDirectory, name, toDirectory, destination in
                commits += 1
                #expect(fromDirectory == toDirectory)
                #expect((try? Data(contentsOf: fixture.file)) == original)
                let temporary = fixture.directory.appendingPathComponent(name)
                let data = try? Data(contentsOf: temporary)
                #expect(data.flatMap { try? JSONDecoder().decode(ResumeRecord.self, from: $0) } == replacement)
                #expect((try? fixture.mode(of: temporary)) == 0o600)
                return renameat(fromDirectory, name, toDirectory, destination)
            }
            let store = try fixture.store(operations: operations)
            #expect(store.save(replacement))
            #expect(commits == 1)
            #expect(store.load() == replacement)
            #expect(try FileManager.default
                .contentsOfDirectory(atPath: fixture.directory.path) == ["resume-record.json"])
        }
    }
}
