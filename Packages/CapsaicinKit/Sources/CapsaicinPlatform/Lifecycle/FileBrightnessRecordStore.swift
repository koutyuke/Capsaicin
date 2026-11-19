import CapsaicinCore
import Foundation
import os

/// bundle ID ごとの専用ディレクトリに輝度の記録を置く。
/// 置換による原子的な公開を保証し、電源断後の永続性までは保証しない。
@MainActor
public final class FileBrightnessRecordStore: BrightnessRecordStoring {
    private let directory: URL
    private let file: URL
    private let logger = Logger(subsystem: "io.github.koutyuke.capsaicin", category: "BrightnessRecordStore")

    public convenience init(bundleID: String) {
        self.init(bundleID: bundleID, applicationSupportDirectory: .applicationSupportDirectory)
    }

    /// テストは所有する一時ルートを渡し、実際のアプリの保存先を使わない。
    init(bundleID: String, applicationSupportDirectory: URL) {
        directory = applicationSupportDirectory.appendingPathComponent(bundleID)
        // 前の版のファイルを同じ場所で読み、輝度以外のキーは無視する。
        file = directory.appendingPathComponent("resume-record.json")
    }

    public func load() -> BrightnessRecord? {
        do {
            return try JSONDecoder().decode(BrightnessRecord.self, from: Data(contentsOf: file))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        } catch {
            logger.error("輝度の記録を読み込めません。")
            return nil
        }
    }

    public func save(_ brightness: Float) -> Bool {
        do {
            let data = try JSONEncoder().encode(BrightnessRecord(savedBrightness: brightness))
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700],
            )
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            return true
        } catch {
            logger.error("輝度の記録を保存できません。")
            return false
        }
    }

    public func remove() -> Bool {
        do {
            try FileManager.default.removeItem(at: file)
            return true
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return true
        } catch {
            logger.error("輝度の記録を削除できません。")
            return false
        }
    }
}
