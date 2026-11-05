import CapsaicinCore
import Foundation
import IOKit
import IOKit.pwr_mgt

/// IOPMrootDomain のユーザークライアント。テストでは各呼び出しだけを差し替える。
@MainActor
struct LidSleepCalls {
    var find: () -> io_service_t
    var open: (io_service_t, UnsafeMutablePointer<io_connect_t>) -> IOReturn
    var call: (io_connect_t, UInt32, UInt64) -> IOReturn
    var close: (io_connect_t) -> IOReturn
    var release: (io_service_t) -> Void

    static var live: Self {
        Self(
            find: { IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain")) },
            open: { IOServiceOpen($0, mach_task_self_, 0, $1) },
            call: { connection, selector, value in
                var input = value
                return IOConnectCallScalarMethod(connection, selector, &input, 1, nil, nil)
            },
            close: { IOServiceClose($0) },
            release: { _ = IOObjectRelease($0) },
        )
    }
}

/// プロセスを越えて残りうる制御なので、同じ値でも毎回 OS に渡す。
@MainActor
public final class LidSleepControl: LidSleepControlling {
    private let calls: LidSleepCalls

    public convenience init() {
        self.init(calls: .live)
    }

    init(calls: LidSleepCalls) {
        self.calls = calls
    }

    public func setLidSleepDisabled(_ disabled: Bool) throws {
        let service = calls.find()
        guard service != 0 else { throw PowerPlatformError.unavailable("IOPMrootDomain") }
        defer { calls.release(service) }
        var connection: io_connect_t = 0
        let openResult = calls.open(service, &connection)
        guard openResult == kIOReturnSuccess else {
            throw PowerPlatformError.ioKit(operation: "IOServiceOpen", code: openResult)
        }
        // selector の入力はマスクではなく真偽値。カーネル側が powerd 用のビットを選ぶ。
        let result = calls.call(connection, UInt32(kPMSetClamshellSleepState), disabled ? 1 : 0)
        let closeResult = calls.close(connection)
        guard result == kIOReturnSuccess else {
            throw PowerPlatformError.ioKit(operation: "kPMSetClamshellSleepState", code: result)
        }
        guard closeResult == kIOReturnSuccess else {
            throw PowerPlatformError.ioKit(operation: "IOServiceClose", code: closeResult)
        }
    }
}
