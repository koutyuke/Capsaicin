import Darwin
import Foundation

public enum KarabinerElementsState: Equatable, Sendable {
    case unknown
    case notRunning
    case running
}

public enum KarabinerDetectionError: Error, Equatable, Sendable {
    case processListUnavailable
    case processInspectionFailed
}

/// 既知の root デーモンの起動だけを検出する。LED の上書きや設定の有効性を断定しない。
/// GUI の終了や仮想デバイスの存在だけでは判定しない。生成時には監視を始めない。
@MainActor
public final class KarabinerElementsMonitor {
    public private(set) var state: KarabinerElementsState = .unknown
    public var onStateChange: (@MainActor @Sendable (KarabinerElementsState) -> Void)?
    public var onDetectionFailure: (@MainActor @Sendable (any Error) -> Void)?

    typealias Tick = @MainActor @Sendable () -> Void
    typealias Cancel = @MainActor () -> Void
    typealias Schedule = @MainActor (@escaping Tick) -> Cancel

    private let detect: () throws -> Bool
    private let schedule: Schedule
    private var cancel: Cancel?
    private var generation: UInt64 = 0
    private var isMonitoring = false

    public convenience init() {
        self.init(detect: { try KarabinerProcessSource.native.isRunning() }, schedule: Self.scheduleNative)
    }

    init(detect: @escaping () throws -> Bool, schedule: @escaping Schedule) {
        self.detect = detect
        self.schedule = schedule
    }

    public func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        generation &+= 1
        let current = generation
        poll()
        // 状態通知の受け手が同期で stop() した場合も再開しない。
        guard isMonitoring, generation == current else { return }
        cancel = schedule { [weak self] in
            guard let self, isMonitoring, generation == current else { return }
            poll()
        }
    }

    public func stop() {
        isMonitoring = false
        generation &+= 1
        cancel?()
        cancel = nil
    }

    isolated deinit {
        stop()
    }

    private func poll() {
        do {
            try update(detect() ? .running : .notRunning)
        } catch {
            update(.unknown)
            onDetectionFailure?(error)
        }
    }

    private func update(_ next: KarabinerElementsState) {
        guard state != next else { return }
        state = next
        onStateChange?(next)
    }

    private static func scheduleNative(tick: @escaping Tick) -> Cancel {
        // このタイマーは検出専用で、LED を書き直す経路には接続しない。
        let timer = Timer(timeInterval: 5, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        return { timer.invalidate() }
    }
}

struct KarabinerProcessIdentity: Equatable {
    var name: String
    var effectiveUID: uid_t
    var startSeconds: UInt64
    var startMicroseconds: UInt64
}

/// libproc の読み取り境界。取得失敗を「終了」に変換せず、PID の消滅だけを通常の競合として扱う。
struct KarabinerProcessSource {
    var listPIDs: () throws -> [Int32]
    var identity: (Int32) throws -> KarabinerProcessIdentity?
    var path: (Int32) throws -> String?

    /// v15.6.0、v16.3.0 と、配置変更後の公式ソースで確認した実行ファイルだけを扱う。
    static let daemonPaths: Set<String> = [
        "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_grabber",
        "/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Core-Service.app/Contents/MacOS/Karabiner-Core-Service",
        "/Applications/Karabiner-Elements.app/Contents/Helpers/Karabiner-Core-Service.app/Contents/MacOS/Karabiner-Core-Service",
    ]
    private static let daemonNames = Set(daemonPaths.map { URL(fileURLWithPath: $0).lastPathComponent })

    func isRunning() throws -> Bool {
        var inspectionFailed = false
        for pid in try listPIDs() {
            do {
                guard let process = try identity(pid), process.effectiveUID == 0 else { continue }
                // 名前を取得できない root プロセスは、パスで判定する。
                guard process.name.isEmpty || Self.daemonNames.contains(process.name) else { continue }
                if let executable = try path(pid), Self.daemonPaths.contains(executable) {
                    // PID の再利用で別プロセスの UID とパスを組み合わせない。
                    guard let confirmed = try identity(pid), confirmed == process else {
                        throw KarabinerDetectionError.processInspectionFailed
                    }
                    return true
                }
            } catch {
                inspectionFailed = true
            }
        }
        guard !inspectionFailed else { throw KarabinerDetectionError.processInspectionFailed }
        return false
    }

    static var native: KarabinerProcessSource {
        KarabinerProcessSource(listPIDs: readPIDs, identity: readIdentity, path: readPath)
    }

    private static func readPIDs() throws -> [Int32] {
        let required = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard required > 0 else { throw KarabinerDetectionError.processListUnavailable }
        // 列挙中の増加に余裕を持たせ、なお満杯なら不完全な一覧で終了を断定しない。
        var pids = [Int32](repeating: 0, count: Int(required) / MemoryLayout<Int32>.stride + 128)
        let bytes = pids.withUnsafeMutableBytes {
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, $0.baseAddress, Int32($0.count))
        }
        guard bytes > 0, Int(bytes) < pids.count * MemoryLayout<Int32>.stride else {
            throw KarabinerDetectionError.processListUnavailable
        }
        return pids.prefix(Int(bytes) / MemoryLayout<Int32>.stride).filter { $0 > 0 }
    }

    private static func readIdentity(pid: Int32) throws -> KarabinerProcessIdentity? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        errno = 0
        let bytes = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard bytes == size else {
            if bytes == 0, errno == ESRCH || errno == ENOENT {
                return nil
            }
            throw KarabinerDetectionError.processInspectionFailed
        }
        guard let name = withUnsafeBytes(of: info.pbi_name, { String(bytes: $0.prefix { $0 != 0 }, encoding: .utf8) })
        else {
            throw KarabinerDetectionError.processInspectionFailed
        }
        return KarabinerProcessIdentity(
            name: name,
            effectiveUID: info.pbi_uid,
            startSeconds: info.pbi_start_tvsec,
            startMicroseconds: info.pbi_start_tvusec,
        )
    }

    private static func readPath(pid: Int32) throws -> String? {
        // PROC_PIDPATHINFO_MAXSIZE の式。Swift がこのマクロを取り込めないため展開する。
        var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        errno = 0
        let bytes = buffer.withUnsafeMutableBytes { proc_pidpath(pid, $0.baseAddress, UInt32($0.count)) }
        guard bytes > 0, Int(bytes) < buffer.count else {
            if bytes == 0, errno == ESRCH || errno == ENOENT {
                return nil
            }
            throw KarabinerDetectionError.processInspectionFailed
        }
        guard let path = String(bytes: buffer.prefix { $0 != 0 }, encoding: .utf8) else {
            throw KarabinerDetectionError.processInspectionFailed
        }
        return path
    }
}
