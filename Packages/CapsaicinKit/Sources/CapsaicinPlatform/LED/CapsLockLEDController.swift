import CapsaicinCore
import CapsaicinLEDShim
import Foundation
import IOKit.hidsystem
import os

public enum CapsLockLEDError: Error, Equatable, Sendable {
    case clientCreationFailed
    case servicesUnavailable
    case writeFailed(failedTargets: Int)
    case keyboardMonitorCreationFailed
}

/// LED の表示だけを操作する。生成時には HID に接続せず、終了時の復旧は明示的に行う。
@MainActor
public final class CapsLockLEDController: CapsLockLEDControlling {
    public var isAvailable: Bool {
        symbolAvailable()
    }

    /// 接続・切断による再適用の失敗。復帰やロックでの再適用の失敗は reapply() が throw する。
    public var onReapplyFailure: (@MainActor @Sendable (any Error) -> Void)?

    private let symbolAvailable: () -> Bool
    private let makeClient: () throws -> LEDClient
    private let monitor: HIDKeyboardMonitor
    private let logger = Logger(subsystem: "io.github.koutyuke.capsaicin", category: "LED")
    private var desiredLit = false
    /// 初回の false でも前プロセスの設定を復旧する。成功するまでは不明として残す。
    private var needsAutomaticRestore = true

    public convenience init() {
        self.init(
            symbolAvailable: { CapsaicinLEDClientSymbolAvailable() },
            makeClient: { try LEDClient.native() },
            monitor: HIDKeyboardMonitor(),
        )
    }

    init(
        symbolAvailable: @escaping () -> Bool,
        makeClient: @escaping () throws -> LEDClient,
        monitor: HIDKeyboardMonitor,
    ) {
        self.symbolAvailable = symbolAvailable
        self.makeClient = makeClient
        self.monitor = monitor
    }

    /// 初回の false は起動時の復旧として Auto を試み、成功後の false は何もしない。
    /// 途中まで失敗したときも、false は先に点灯の意図を取り消す。
    public func setLit(_ lit: Bool) throws {
        desiredLit = lit
        if !lit {
            monitor.stop()
        }
        guard isAvailable else { return }
        if lit {
            needsAutomaticRestore = true
            try monitor.start { [weak self] in
                guard let self, desiredLit else { return }
                do {
                    try apply(mode: "On")
                } catch {
                    onReapplyFailure?(error)
                }
            }
            try apply(mode: "On")
        } else {
            guard needsAutomaticRestore else { return }
            try apply(mode: "Auto")
            needsAutomaticRestore = false
        }
    }

    /// アプリが、Mac と画面の復帰、画面のロック（スクリーンセーバーを含む）の開始と終了で呼ぶ。
    /// どれも OS が "Auto" に戻しうるため。定期的な書き直しは行わない。
    public func reapply() throws {
        guard isAvailable, desiredLit else { return }
        try apply(mode: "On")
    }

    /// 通知だけを止める。LED を復旧するには setLit(false) を明示的に呼ぶ。
    public func stopMonitoring() {
        monitor.stop()
    }

    private func apply(mode: String) throws {
        let client = try makeClient()
        let services = try client.services()
        var targets: [String] = []
        var failedTargets: [String] = []
        for service in services where service.isKeyboard() {
            // Transport がないのはキー配列を変えるアプリの、"Virtual" は OS の仮想キーボードである。
            guard let transport = service.transport(), transport as? String != "Virtual" else { continue }
            let registryID = service.registryID.map { String($0) } ?? "nil"
            targets.append(registryID)
            if !service.setMode(mode) {
                failedTargets.append(registryID)
            }
        }
        // WindowServer のログには成功した書き込みしか残らないため、対象と失敗をここで残す。
        logger.log(
            level: failedTargets.isEmpty ? .default : .error,
            "LED 書き込み: mode=\(mode, privacy: .public) targets=\(targets.description, privacy: .public) failedTargets=\(failedTargets.description, privacy: .public)",
        )
        if !failedTargets.isEmpty {
            throw CapsLockLEDError.writeFailed(failedTargets: failedTargets.count)
        }
    }
}

/// 配列から取り出したサービスは、書き込みが終わるまで各クロージャーが保持する。
@MainActor
struct LEDService {
    var registryID: UInt64?
    var isKeyboard: () -> Bool
    var transport: () -> CFTypeRef?
    var setMode: (String) -> Bool
}

@MainActor
struct LEDClient {
    var services: () throws -> [LEDService]

    static func native() throws -> LEDClient {
        guard let client = CapsaicinLEDCreatePassiveClient() else {
            throw CapsLockLEDError.clientCreationFailed
        }
        return LEDClient {
            guard let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] else {
                throw CapsLockLEDError.servicesUnavailable
            }
            return services.map { service in
                LEDService(
                    registryID: (IOHIDServiceClientGetRegistryID(service) as? NSNumber)?.uint64Value,
                    isKeyboard: { IOHIDServiceClientConformsTo(service, 1, 6) != 0 },
                    transport: { IOHIDServiceClientCopyProperty(service, kIOHIDTransportKey as CFString) },
                    setMode: { IOHIDServiceClientSetProperty(service, "HIDCapsLockLED" as CFString, $0 as CFString) },
                )
            }
        }
    }
}
