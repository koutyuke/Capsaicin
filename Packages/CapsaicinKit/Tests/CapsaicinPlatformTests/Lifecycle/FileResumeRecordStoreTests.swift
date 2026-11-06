import CapsaicinCore
@testable import CapsaicinPlatform
import Foundation
import Testing

@MainActor
struct FileResumeRecordStoreTests {
    @Test("SPEC-LCY-007 全項目と渡した最終更新時刻を専用ファイルで往復する")
    func roundTrip() throws {
        try withStorageFixture { fixture in
            #expect(fixture.store().save(fixture.record))
            #expect(fixture.store().load() == fixture.record)
            let replacement = ResumeRecord(lastUpdated: fixture.record.lastUpdated.addingTimeInterval(10))
            #expect(fixture.store().save(replacement))
            #expect(fixture.store().load() == replacement)
        }
    }

    @Test("SPEC-LCY-007 ファイルがなければ nil を返し、記録を作らない", arguments: [false, true])
    func missingRecord(directoryExists: Bool) throws {
        try withStorageFixture { fixture in
            if directoryExists {
                try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
            }
            #expect(fixture.store().load() == nil)
            #expect(!FileManager.default.fileExists(atPath: fixture.file.path))
            #expect(FileManager.default.fileExists(atPath: fixture.directory.path) == directoryExists)
        }
    }

    @Test("SPEC-LCY-007 壊れた記録は読み込まず、読み取りで上書きしない", arguments: [
        "not json", "[]", "{}", #"{"lastUpdated":null}"#,
        #"{"lastUpdated":0,"isRunning":null}"#,
        #"{"lastUpdated":0,"session":{"timeLimit":{"date":0,"source":"invalid"}}}"#,
    ])
    func corruptRecords(json: String) throws {
        try withStorageFixture { fixture in
            #expect(fixture.store().save(fixture.record))
            let bytes = Data(json.utf8)
            try bytes.write(to: fixture.file)
            #expect(fixture.store().load() == nil)
            #expect(try Data(contentsOf: fixture.file) == bytes)
        }
    }

    @Test("SPEC-LCY-007 新規保存と置換の後のファイルの権限は 0600 になる")
    func privatePermissions() throws {
        try withStorageFixture { fixture in
            #expect(fixture.store().save(fixture.record))
            #expect(try fixture.permissions() == 0o600)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fixture.file.path)
            #expect(fixture.store().save(fixture.record))
            #expect(try fixture.permissions() == 0o600)
        }
    }
}

@MainActor
private struct ResumeRecordStorageFixture {
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

    func store() -> FileResumeRecordStore {
        FileResumeRecordStore(bundleID: bundleID, applicationSupportDirectory: root)
    }

    func permissions() throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        return try #require(attributes[.posixPermissions] as? NSNumber).intValue
    }
}

@MainActor
private func withStorageFixture(_ body: (ResumeRecordStorageFixture) throws -> Void) throws {
    let base = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../../../../.build/task010-storage-fixtures").standardizedFileURL
    let root = base.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700],
    )
    defer { try? FileManager.default.removeItem(at: root) }
    try body(ResumeRecordStorageFixture(root: root))
}
