import CapsaicinCore
import CapsaicinLEDShim
import Foundation
import IOKit.hidsystem

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

    /// 接続・切断による再適用の失敗。復帰時の失敗は reapplyAfterWake() が throw する。
    public var onReapplyFailure: (@MainActor @Sendable (any Error) -> Void)?

    private let symbolAvailable: () -> Bool
    private let makeClient: () throws -> LEDClient
    private let monitor: HIDKeyboardMonitor
    private var client: LEDClient?
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
            monitor.stop()
            guard needsAutomaticRestore else { return }
            try apply(mode: "Auto")
            needsAutomaticRestore = false
        }
    }

    /// アプリが Mac か画面の復帰通知を受けて呼ぶ。画面のスリープで OS が "Auto" に戻すため。定期的な書き直しは行わない。
    public func reapplyAfterWake() throws {
        guard isAvailable, desiredLit else { return }
        try apply(mode: "On")
    }

    /// 通知だけを止める。LED を復旧するには setLit(false) を明示的に呼ぶ。
    public func stopMonitoring() {
        monitor.stop()
    }

    private func apply(mode: String) throws {
        let client = try client ?? makeClient()
        self.client = client
        let services = try client.services()
        var failures = 0
        for service in services where service.isKeyboard() {
            if !service.setMode(mode) {
                failures += 1
            }
        }
        if failures > 0 {
            throw CapsLockLEDError.writeFailed(failedTargets: failures)
        }
    }
}

/// 配列から取り出したサービスは、書き込みが終わるまで各クロージャーが保持する。
@MainActor
struct LEDService {
    var isKeyboard: () -> Bool
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
                    isKeyboard: { IOHIDServiceClientConformsTo(service, 1, 6) != 0 },
                    setMode: { IOHIDServiceClientSetProperty(service, "HIDCapsLockLED" as CFString, $0 as CFString) },
                )
            }
        }
    }
}
