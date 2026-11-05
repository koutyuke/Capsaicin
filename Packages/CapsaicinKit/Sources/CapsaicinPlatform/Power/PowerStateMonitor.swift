import CapsaicinCore
import Foundation
import IOKit.ps

/// 読み取りは生成時にも行う。監視中は状態が変わったときだけメインアクターで通知する。
@MainActor
public final class PowerStateMonitor: PowerStateProviding {
    public private(set) var powerState: PowerState
    private let read: () -> PowerState
    private let observe: (@escaping @MainActor () -> Void) throws -> @MainActor () -> Void
    private var cancelObservation: (@MainActor () -> Void)?
    private var onChange: (@MainActor (PowerState) -> Void)?
    private var generation = 0

    public convenience init() {
        self.init(read: { PowerSnapshot.read().powerState }, observe: PowerSourceObservation.register)
    }

    init(
        read: @escaping () -> PowerState,
        observe: @escaping (@escaping @MainActor () -> Void) throws -> @MainActor () -> Void,
    ) {
        self.read = read
        self.observe = observe
        powerState = read()
    }

    /// 二重の開始は登録済みの監視を保つ。停止後は再び開始できる。
    public func start(onChange: @escaping @MainActor (PowerState) -> Void) throws {
        guard cancelObservation == nil else { return }
        generation &+= 1
        let currentGeneration = generation
        self.onChange = onChange
        do {
            cancelObservation = try observe { [weak self] in
                guard let self, generation == currentGeneration else { return }
                refresh()
            }
        } catch {
            self.onChange = nil
            generation &+= 1
            throw error
        }
        refresh()
    }

    public func stop() {
        generation &+= 1
        onChange = nil
        let cancel = cancelObservation
        cancelObservation = nil
        cancel?()
    }

    private func refresh() {
        let newState = read()
        guard newState != powerState else { return }
        powerState = newState
        onChange?(newState)
    }

    isolated deinit {
        cancelObservation?()
    }
}

/// C の context は登録から解除まで生存し、Main RunLoop の common modes だけで使う。
@MainActor
private final class PowerSourceObservation {
    let notify: @MainActor () -> Void
    var active = true

    init(notify: @escaping @MainActor () -> Void) {
        self.notify = notify
    }

    static func register(_ notify: @escaping @MainActor () -> Void) throws -> @MainActor () -> Void {
        let context = PowerSourceObservation(notify: notify)
        guard let source = IOPSNotificationCreateRunLoopSource({ pointer in
            MainActor.assumeIsolated {
                guard let pointer else { return }
                let context = Unmanaged<PowerSourceObservation>.fromOpaque(pointer).takeUnretainedValue()
                if context.active {
                    context.notify()
                }
            }
        }, Unmanaged.passUnretained(context).toOpaque())?.takeRetainedValue() else {
            throw PowerPlatformError.unavailable("IOPSNotificationCreateRunLoopSource")
        }
        let runLoop = CFRunLoopGetMain()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        return {
            guard context.active else { return }
            context.active = false
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFRunLoopSourceInvalidate(source)
            withExtendedLifetime(context) {}
        }
    }
}
