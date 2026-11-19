import CapsaicinCore
@testable import CapsaicinPlatform
import Foundation
import Testing

@MainActor
struct FileBrightnessRecordStoreTests {
    @Test("SPEC-BLK-013 保存・置換する JSON は輝度だけを持ち、削除後は同じファイルから読めない")
    func roundTrip() throws {
        try withStorageFixture { fixture in
            #expect(fixture.store().save(0.5))
            #expect(fixture.store().load()?.savedBrightness == 0.5)
            #expect(fixture.store().save(0.25))
            #expect(fixture.store().load()?.savedBrightness == 0.25)
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: fixture.file))
            #expect(object as? [String: Double] == ["savedBrightness": 0.25])
            #expect(fixture.store().remove())
            #expect(fixture.store().load() == nil)
            #expect(!FileManager.default.fileExists(atPath: fixture.file.path))
        }
    }

    @Test("SPEC-BLK-013 ファイルがなくても削除は成功し、読み込みも削除もファイルを作らない", arguments: [false, true])
    func missingRecord(directoryExists: Bool) throws {
        try withStorageFixture { fixture in
            if directoryExists {
                try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
            }
            #expect(fixture.store().load() == nil)
            #expect(fixture.store().remove())
            #expect(!FileManager.default.fileExists(atPath: fixture.file.path))
            #expect(FileManager.default.fileExists(atPath: fixture.directory.path) == directoryExists)
        }
    }

    @Test("SPEC-LCY-008 旧形式は輝度だけを読み、ほかのキーの値と型は問わない", arguments: [false, true])
    func readsLegacyRecord(hasBrightness: Bool) throws {
        try withStorageFixture { fixture in
            try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
            let brightness = hasBrightness ? #""savedBrightness":0.5,"# : ""
            let json = """
            {\(brightness)"session":{"timeLimit":{"date":700000000,"source":"timer"}},
             "ownsSleepDisabled":true,"isRunning":true,"exitReason":null,
             "misalignments":[],"lastUpdated":"invalid date","crashLaunches":[699999900]}
            """
            try Data(json.utf8).write(to: fixture.file)
            #expect(fixture.store().load() == BrightnessRecord(savedBrightness: hasBrightness ? 0.5 : nil))
        }
    }

    @Test("SPEC-BLK-013 壊れた記録は読み込まず、読み取りで上書きしない", arguments: [
        "not json", "[]", #"{"savedBrightness":"invalid"}"#,
    ])
    func corruptRecords(json: String) throws {
        try withStorageFixture { fixture in
            #expect(fixture.store().save(0.5))
            let bytes = Data(json.utf8)
            try bytes.write(to: fixture.file)
            #expect(fixture.store().load() == nil)
            #expect(try Data(contentsOf: fixture.file) == bytes)
        }
    }

    @Test("SPEC-BLK-013 新規保存と置換の後のファイルの権限は 0600 になる")
    func privatePermissions() throws {
        try withStorageFixture { fixture in
            #expect(fixture.store().save(0.5))
            #expect(try fixture.permissions() == 0o600)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fixture.file.path)
            #expect(fixture.store().save(0.25))
            #expect(try fixture.permissions() == 0o600)
        }
    }
}

@MainActor
private struct BrightnessRecordStorageFixture {
    let root: URL
    let bundleID = "io.github.capsaicin.storage-test"
    var directory: URL {
        root.appendingPathComponent(bundleID)
    }

    var file: URL {
        directory.appendingPathComponent("resume-record.json")
    }

    func store() -> FileBrightnessRecordStore {
        FileBrightnessRecordStore(bundleID: bundleID, applicationSupportDirectory: root)
    }

    func permissions() throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        return try #require(attributes[.posixPermissions] as? NSNumber).intValue
    }
}

@MainActor
private func withStorageFixture(_ body: (BrightnessRecordStorageFixture) throws -> Void) throws {
    let base = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../../../../.build/task121-storage-fixtures").standardizedFileURL
    let root = base.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700],
    )
    defer { try? FileManager.default.removeItem(at: root) }
    try body(BrightnessRecordStorageFixture(root: root))
}
