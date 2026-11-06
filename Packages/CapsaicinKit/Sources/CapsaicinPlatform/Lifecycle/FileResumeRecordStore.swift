import CapsaicinCore
import Darwin
import Foundation
import os

/// bundle ID ごとの専用ディレクトリに、再開用の記録を置く。
/// 置換による原子的な公開を保証し、電源断後の永続性までは保証しない。
@MainActor
public final class FileResumeRecordStore: ResumeRecordStoring {
    private let root: URL
    private let bundleID: String
    private let operations: ResumeRecordFileOperations
    private let fileName = "resume-record.json"
    private let logger = Logger(subsystem: "io.github.koutyuke.capsaicin", category: "ResumeRecordStore")

    public convenience init(bundleID: String) throws {
        try Self.validateBundleID(bundleID)
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true,
        )
        try self.init(bundleID: bundleID, applicationSupportDirectory: root)
    }

    /// テストは所有する一時ルートを渡し、実際のアプリの保存先を使わない。
    init(
        bundleID: String,
        applicationSupportDirectory: URL,
        operations: ResumeRecordFileOperations = .init(),
    ) throws {
        try Self.validateBundleID(bundleID)
        self.bundleID = bundleID
        root = applicationSupportDirectory
        self.operations = operations
    }

    private static func validateBundleID(_ bundleID: String) throws {
        guard !bundleID.isEmpty, bundleID != ".", bundleID != "..", bundleID.utf8.count <= Int(NAME_MAX),
              bundleID.utf8.allSatisfy({ byte in
                  (65 ... 90).contains(byte) || (97 ... 122).contains(byte)
                      || (48 ... 57).contains(byte) || byte == 45 || byte == 46
              })
        else { throw StorageError.invalidBundleID }
    }

    public func load() -> ResumeRecord? {
        do {
            let directory = try openDirectory(create: false)
            defer { closeOwned(directory) }
            // FIFO を開いた場合も、型の検査に到達するまで待たせない。
            let descriptor = openat(directory, fileName, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard descriptor >= 0 else { throw currentError() }
            defer { closeOwned(descriptor) }
            try validate(descriptor, type: S_IFREG, permissions: 0o600)
            let data = try readAll(descriptor)
            do {
                return try JSONDecoder().decode(ResumeRecord.self, from: data)
            } catch {
                logger.error("再開用の記録の形式が不正です。")
                return nil
            }
        } catch StorageError.missing {
            return nil
        } catch {
            logger.error("再開用の記録を読み込めません。")
            return nil
        }
    }

    public func save(_ record: ResumeRecord) -> Bool {
        do {
            // エンコードに失敗しても、既存の記録やディレクトリを変更しない。
            let data = try JSONEncoder().encode(record)
            let directory = try openDirectory(create: true)
            defer { closeOwned(directory) }
            try validateDestination(in: directory)
            try replace(data, in: directory)
            return true
        } catch {
            logger.error("再開用の記録を保存できません。")
            return false
        }
    }

    private func openDirectory(create: Bool) throws -> Int32 {
        let parent = open(root.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard parent >= 0 else { throw currentError() }
        defer { closeOwned(parent) }
        var info = stat()
        guard fstat(parent, &info) == 0, info.st_uid == geteuid() else { throw StorageError.unsafeEntry }
        if create, mkdirat(parent, bundleID, 0o700) != 0, errno != EEXIST {
            throw StorageError.ioFailure
        }
        let directory = openat(parent, bundleID, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard directory >= 0 else { throw currentError() }
        do {
            try validate(directory, type: S_IFDIR, permissions: 0o700)
            return directory
        } catch {
            closeOwned(directory)
            throw error
        }
    }

    private func validate(_ descriptor: Int32, type: mode_t, permissions: mode_t) throws {
        var info = stat()
        guard fstat(descriptor, &info) == 0,
              Self.isPrivate(info, type: type, permissions: permissions)
        else { throw StorageError.unsafeEntry }
    }

    static func isPrivate(_ info: stat, type: mode_t, permissions: mode_t) -> Bool {
        info.st_mode & S_IFMT == type && info.st_uid == geteuid()
            && info.st_mode & 0o7777 == permissions && (type != S_IFREG || info.st_nlink == 1)
    }

    private func validateDestination(in directory: Int32) throws {
        var info = stat()
        if fstatat(directory, fileName, &info, AT_SYMLINK_NOFOLLOW) == 0 {
            guard Self.isPrivate(info, type: S_IFREG, permissions: 0o600) else {
                throw StorageError.unsafeEntry
            }
        } else if errno != ENOENT {
            throw StorageError.ioFailure
        }
    }

    private func readAll(_ descriptor: Int32) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = read(descriptor, &buffer, buffer.count)
            if count == 0 {
                return data
            }
            if count < 0 {
                if errno == EINTR {
                    continue
                }
                throw StorageError.ioFailure
            }
            data.append(contentsOf: buffer.prefix(count))
        }
    }

    private func replace(_ data: Data, in directory: Int32) throws {
        let temporaryName = ".resume-record-\(UUID().uuidString).tmp"
        var descriptor = openat(
            directory, temporaryName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600,
        )
        guard descriptor >= 0 else { throw StorageError.ioFailure }
        var committed = false
        defer {
            if descriptor >= 0 {
                closeOwned(descriptor)
            }
            if !committed, unlinkat(directory, temporaryName, 0) != 0 {
                logger.error("作成した一時記録を削除できません。")
            }
        }
        try validate(descriptor, type: S_IFREG, permissions: 0o600)
        try writeAll(data, to: descriptor)
        let closeResult = operations.closeTemporary(descriptor)
        // Darwin の close は再試行しない。再利用された別の FD を閉じないため。
        descriptor = -1
        guard closeResult == 0 else { throw StorageError.ioFailure }
        try validateDestination(in: directory)
        guard operations.rename(directory, temporaryName, directory, fileName) == 0 else {
            throw StorageError.ioFailure
        }
        // rename 成功がコミット点。これ以降の後片付けの失敗で false にしない。
        committed = true
    }

    private func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            var offset = 0
            while offset < bytes.count {
                let count = operations.write(descriptor, base.advanced(by: offset), bytes.count - offset)
                if count < 0, errno == EINTR {
                    continue
                }
                guard count > 0 else { throw StorageError.ioFailure }
                offset += count
            }
        }
    }

    private func closeOwned(_ descriptor: Int32) {
        if close(descriptor) != 0 {
            logger.error("記録用のファイル記述子を閉じられません。")
        }
    }

    private func currentError() -> StorageError {
        errno == ENOENT ? .missing : .ioFailure
    }

    private enum StorageError: Error {
        case invalidBundleID, missing, unsafeEntry, ioFailure
    }
}

/// 実ファイルを使ったまま、保存の失敗箇所だけをテストで制御する。
struct ResumeRecordFileOperations {
    var write: (Int32, UnsafeRawPointer, Int) -> Int = { Darwin.write($0, $1, $2) }
    var closeTemporary: (Int32) -> Int32 = { Darwin.close($0) }
    var rename: (Int32, String, Int32, String) -> Int32 = { renameat($0, $1, $2, $3) }
}
