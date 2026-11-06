import Darwin
import Foundation
import OSLog

enum KarabinerDetectionError: Error {
    case processListUnavailable
}

struct KarabinerProcessSource {
    var listPIDs: () throws -> [Int32]
    var path: (Int32) -> String?

    static let daemonPaths: Set<String> = [
        "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_grabber",
        "/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Core-Service.app/Contents/MacOS/Karabiner-Core-Service",
        "/Applications/Karabiner-Elements.app/Contents/Helpers/Karabiner-Core-Service.app/Contents/MacOS/Karabiner-Core-Service",
    ]

    func isRunning() throws -> Bool {
        try listPIDs().contains { pid in
            path(pid).map { Self.daemonPaths.contains($0) } ?? false
        }
    }

    static var native: Self {
        Self(listPIDs: readPIDs, path: readPath)
    }

    private static func readPIDs() throws -> [Int32] {
        let required = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard required > 0 else { throw KarabinerDetectionError.processListUnavailable }
        var pids = [Int32](repeating: 0, count: Int(required) / MemoryLayout<Int32>.stride)
        let bytes = pids.withUnsafeMutableBytes {
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, $0.baseAddress, Int32($0.count))
        }
        guard bytes > 0 else { throw KarabinerDetectionError.processListUnavailable }
        return pids.prefix(Int(bytes) / MemoryLayout<Int32>.stride).filter { $0 > 0 }
    }

    private static func readPath(pid: Int32) -> String? {
        // PROC_PIDPATHINFO_MAXSIZE は Swift に取り込まれないため展開する。
        var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let bytes = buffer.withUnsafeMutableBytes { proc_pidpath(pid, $0.baseAddress, UInt32($0.count)) }
        guard bytes > 0, let path = String(bytes: buffer.prefix { $0 != 0 }, encoding: .utf8) else {
            Logger(subsystem: "io.github.koutyuke.capsaicin", category: "KarabinerElements")
                .debug("プロセスのパスを取得できない: pid=\(pid)")
            return nil
        }
        return path
    }
}
