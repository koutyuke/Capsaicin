import CapsaicinCore
import Foundation
import os

/// bundle ID ごとの専用ディレクトリに、再開用の記録を置く。
/// 置換による原子的な公開を保証し、電源断後の永続性までは保証しない。
@MainActor
public final class FileResumeRecordStore: ResumeRecordStoring {
    private let directory: URL
    private let file: URL
    private let logger = Logger(subsystem: "io.github.koutyuke.capsaicin", category: "ResumeRecordStore")

    public convenience init(bundleID: String) throws {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true,
        )
        self.init(bundleID: bundleID, applicationSupportDirectory: root)
    }

    /// テストは所有する一時ルートを渡し、実際のアプリの保存先を使わない。
    init(bundleID: String, applicationSupportDirectory: URL) {
        directory = applicationSupportDirectory.appendingPathComponent(bundleID)
        file = directory.appendingPathComponent("resume-record.json")
    }

    public func load() -> ResumeRecord? {
        do {
            return try JSONDecoder().decode(ResumeRecord.self, from: Data(contentsOf: file))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        } catch {
            logger.error("再開用の記録を読み込めません。")
            return nil
        }
    }

    public func save(_ record: ResumeRecord) -> Bool {
        do {
            let data = try JSONEncoder().encode(record)
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700],
            )
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            return true
        } catch {
            logger.error("再開用の記録を保存できません。")
            return false
        }
    }
}
