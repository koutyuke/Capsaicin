import Foundation
import IOKit

/// 開いていると分かっている状態から閉じたときだけ通知する。初期状態不明は開いたとみなさない。
@MainActor
public final class LidStateMonitor {
    public private(set) var isClosed: Bool?
    private let read: () -> Bool?
    private let observe: (@escaping @MainActor (UInt32, UInt) -> Void) throws -> @MainActor () -> Void
    private var cancelObservation: (@MainActor () -> Void)?
    private var onClose: (@MainActor () -> Void)?
    private var generation = 0

    /// IOPM.h の iokit_family_msg(sub_iokit_powermanagement, 0x100)。Swift にマクロが取り込まれない。
    static let clamshellMessage: UInt32 = 0xE003_4100

    public convenience init() {
        self.init(read: { clamshellIsClosed(readClamshellProperty()) }, observe: LidObservation.register)
    }

    init(
        read: @escaping () -> Bool?,
        observe: @escaping (@escaping @MainActor (UInt32, UInt) -> Void) throws -> @MainActor () -> Void,
    ) {
        self.read = read
        self.observe = observe
        isClosed = read()
    }

    public func start(onClose: @escaping @MainActor () -> Void) throws {
        guard cancelObservation == nil else { return }
        generation &+= 1
        let currentGeneration = generation
        self.onClose = onClose
        do {
            cancelObservation = try observe { [weak self] message, argument in
                guard let self, generation == currentGeneration, message == Self.clamshellMessage else { return }
                receive(closed: argument & 1 != 0)
            }
        } catch {
            self.onClose = nil
            generation &+= 1
            throw error
        }
        // 停止中の変化で閉じた通知を出さず、登録後の読み取りを新しい基準にする。
        isClosed = read()
    }

    public func stop() {
        generation &+= 1
        onClose = nil
        let cancel = cancelObservation
        cancelObservation = nil
        cancel?()
    }

    private func receive(closed: Bool) {
        let wasOpen = isClosed == false
        isClosed = closed
        if wasOpen, closed {
            onClose?()
        }
    }

    isolated deinit {
        cancelObservation?()
    }
}

@MainActor
private final class LidObservation {
    let notify: @MainActor (UInt32, UInt) -> Void
    var active = true

    init(notify: @escaping @MainActor (UInt32, UInt) -> Void) {
        self.notify = notify
    }

    static func register(_ notify: @escaping @MainActor (UInt32, UInt) -> Void) throws -> @MainActor () -> Void {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { throw PowerPlatformError.unavailable("IOPMrootDomain") }
        defer { IOObjectRelease(service) }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            throw PowerPlatformError.unavailable("IONotificationPortCreate")
        }
        guard let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() else {
            IONotificationPortDestroy(port)
            throw PowerPlatformError.unavailable("IONotificationPortGetRunLoopSource")
        }
        let context = LidObservation(notify: notify)
        var notification: io_object_t = 0
        let result = IOServiceAddInterestNotification(
            port,
            service,
            kIOGeneralInterest,
            { pointer, _, message, argument in
                MainActor.assumeIsolated {
                    guard let pointer else { return }
                    let context = Unmanaged<LidObservation>.fromOpaque(pointer).takeUnretainedValue()
                    // messageArgument は参照先ではなく、ポインター値そのものがビットの組である。
                    if context.active {
                        context.notify(message, UInt(bitPattern: argument))
                    }
                }
            },
            Unmanaged.passUnretained(context).toOpaque(),
            &notification,
        )
        guard result == kIOReturnSuccess else {
            if notification != 0 {
                IOObjectRelease(notification)
            }
            IONotificationPortDestroy(port)
            throw PowerPlatformError.ioKit(operation: "IOServiceAddInterestNotification", code: result)
        }
        let runLoop = CFRunLoopGetMain()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        return {
            guard context.active else { return }
            context.active = false
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            IOObjectRelease(notification)
            IONotificationPortDestroy(port)
            withExtendedLifetime(context) {}
        }
    }
}
