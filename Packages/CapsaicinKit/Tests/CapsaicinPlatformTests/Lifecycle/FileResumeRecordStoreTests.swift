import CapsaicinCore
@testable import CapsaicinPlatform
import Darwin
import Foundation
import Testing

@MainActor
struct FileResumeRecordStoreTests {
    @Test("SPEC-LCY-007 全項目と渡した最終更新時刻を専用ファイルで往復する")
    func roundTrip() throws {
        try withStorageFixture { fixture in
            let store = try fixture.store()
            #expect(store.load() == nil)
            #expect(!FileManager.default.fileExists(atPath: fixture.directory.path))
            #expect(store.save(fixture.record))
            let reloadedStore = try fixture.store()
            #expect(reloadedStore.load() == fixture.record)
            let raw = try Data(contentsOf: fixture.file)
            #expect(try JSONDecoder().decode(ResumeRecord.self, from: raw) == fixture.record)
            #expect(try fixture.mode(of: fixture.directory) == 0o700)
            #expect(try fixture.mode(of: fixture.file) == 0o600)
        }
    }

    @Test("SPEC-LCY-007 欠損・未知のキーと null の扱いを Core に委ねる")
    func decodingCompatibility() throws {
        try withStorageFixture { fixture in
            let store = try fixture.store()
            #expect(store.save(fixture.record))
            try Data(#"{"lastUpdated":0,"future":{"nested":null},"session":null,"exitReason":null}"#.utf8)
                .write(to: fixture.file)
            let expected = ResumeRecord(lastUpdated: Date(timeIntervalSinceReferenceDate: 0))
            #expect(store.load() == expected)
            #expect(store.save(expected))
            let fields = try #require(JSONSerialization
                .jsonObject(with: Data(contentsOf: fixture.file)) as? [String: Any])
            #expect(fields["future"] == nil)
        }
    }

    @Test("SPEC-LCY-007 壊れた記録は読み込まず、読み取りで上書きしない", arguments: [
        "not json", "[]", "{}", #"{"lastUpdated":null}"#,
        #"{"lastUpdated":0,"isRunning":null}"#,
        #"{"lastUpdated":0,"session":{"timeLimit":{"date":0,"source":"invalid"}}}"#,
    ])
    func corruptRecords(json: String) throws {
        try withStorageFixture { fixture in
            let store = try fixture.store()
            #expect(store.save(fixture.record))
            let bytes = Data(json.utf8)
            try bytes.write(to: fixture.file)
            #expect(store.load() == nil)
            #expect(try Data(contentsOf: fixture.file) == bytes)
        }
    }

    @Test("SPEC-LCY-007 Debug と Release は bundle ID で分かれる")
    func bundleIsolation() throws {
        try withStorageFixture { fixture in
            let release = try fixture.store()
            let debug = try FileResumeRecordStore(
                bundleID: fixture.bundleID + ".debug", applicationSupportDirectory: fixture.root,
            )
            #expect(release.save(fixture.record))
            #expect(debug.load() == nil)
            let other = ResumeRecord(lastUpdated: fixture.record.lastUpdated.addingTimeInterval(5))
            #expect(debug.save(other))
            #expect(release.load() == fixture.record)
            #expect(debug.load() == other)
        }
    }

    @Test("SPEC-LCY-007 bundle ID は単一の安全なパス要素だけを許す", arguments: [
        "", ".", "..", "../outside", "a/b", "a\u{0}b", "/absolute", "a\\b",
    ])
    func invalidBundleIDs(bundleID: String) throws {
        try withStorageFixture { fixture in
            #expect(throws: (any Error).self) {
                try FileResumeRecordStore(bundleID: bundleID, applicationSupportDirectory: fixture.root)
            }
            let entries = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
            #expect(entries.isEmpty)
        }
    }

    @Test("SPEC-LCY-007 置換では旧ファイルを変更せず、完全な新ファイルだけを公開する")
    func atomicReplacement() throws {
        try withStorageFixture { fixture in
            let store = try fixture.store()
            #expect(store.save(fixture.record))
            let oldFD = open(fixture.file.path, O_RDONLY | O_NOFOLLOW)
            #expect(oldFD >= 0)
            defer {
                if oldFD >= 0 {
                    _ = close(oldFD)
                }
            }
            var oldInfo = stat()
            #expect(fstat(oldFD, &oldInfo) == 0)
            let oldData = try Data(contentsOf: fixture.file)
            let replacement = ResumeRecord(lastUpdated: fixture.record.lastUpdated.addingTimeInterval(10))
            #expect(store.save(replacement))
            var newInfo = stat()
            #expect(lstat(fixture.file.path, &newInfo) == 0)
            #expect(oldInfo.st_ino != newInfo.st_ino)
            var buffer = [UInt8](repeating: 0, count: oldData.count + 1)
            let count = read(oldFD, &buffer, buffer.count)
            #expect(count == oldData.count)
            #expect(Data(buffer.prefix(max(0, count))) == oldData)
            #expect(store.load() == replacement)
            #expect(try FileManager.default
                .contentsOfDirectory(atPath: fixture.directory.path) == ["resume-record.json"])
        }
    }
}

@MainActor
struct ResumeRecordStorageFixture {
    let root: URL
    let bundleID = "io.github.capsaicin.storage-test"
    var directory: URL {
        root.appendingPathComponent(bundleID)
    }

    var file: URL {
        directory.appendingPathComponent("resume-record.json")
    }

    var record: ResumeRecord {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000.25)
        var record = ResumeRecord(lastUpdated: now)
        record.session = BlockingSession(timeLimit: TimeLimit(date: now.addingTimeInterval(60), source: .timer))
        record.ownsSleepDisabled = true
        record.isRunning = true
        record.exitReason = .sessionEnd
        record.misalignments = [.led: .notApplied, .systemSleepDisabled: .leftApplied]
        record.crashLaunches = [now.addingTimeInterval(-20), now.addingTimeInterval(-10)]
        return record
    }

    func store(operations: ResumeRecordFileOperations = .init()) throws -> FileResumeRecordStore {
        try FileResumeRecordStore(
            bundleID: bundleID, applicationSupportDirectory: root, operations: operations,
        )
    }

    func mode(of url: URL) throws -> mode_t {
        var info = stat()
        try #require(lstat(url.path, &info) == 0)
        #expect(info.st_uid == geteuid())
        return info.st_mode & 0o7777
    }
}

@MainActor
func withStorageFixture(_ body: (ResumeRecordStorageFixture) throws -> Void) throws {
    let base = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../../../../.build/task008-storage-fixtures").standardizedFileURL
    let root = base.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700],
    )
    defer { try? FileManager.default.removeItem(at: root) }
    try body(ResumeRecordStorageFixture(root: root))
}
