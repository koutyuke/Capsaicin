import Foundation
import IOKit.hid

/// IOHIDManager は列挙通知にだけ使い、デバイスもマネージャーも open しない。
@MainActor
final class HIDKeyboardMonitor {
    typealias Change = @MainActor @Sendable () -> Void
    typealias Cancel = @MainActor () -> Void
    typealias Register = @MainActor (@escaping Change) throws -> Cancel
    typealias Schedule = @MainActor (@escaping Change) -> Cancel

    private let register: Register
    private let schedule: Schedule
    private var cancel: Cancel?
    private var cancelFollowUp: Cancel?
    private var generation: UInt64 = 0
    private var followUpGeneration: UInt64 = 0
    private var remainingFollowUps = 0
    private var isMonitoring = false

    init(
        register: @escaping Register = HIDKeyboardMonitor.registerNative,
        schedule: @escaping Schedule = HIDKeyboardMonitor.scheduleNative,
    ) {
        self.register = register
        self.schedule = schedule
    }

    func start(onChange: @escaping Change) throws {
        guard !isMonitoring else { return }
        generation &+= 1
        let current = generation
        isMonitoring = true
        do {
            cancel = try register { [weak self] in
                guard let self, isMonitoring, generation == current else { return }
                // 接続通知よりサービスの列挙が遅れるため、通知後だけ追いかける。
                startFollowUp(onChange: onChange)
                onChange()
            }
        } catch {
            isMonitoring = false
            throw error
        }
    }

    func stop() {
        isMonitoring = false
        generation &+= 1
        stopFollowUp()
        cancel?()
        cancel = nil
    }

    isolated deinit {
        stop()
    }

    private func startFollowUp(onChange: @escaping Change) {
        stopFollowUp()
        let current = followUpGeneration
        remainingFollowUps = 5
        cancelFollowUp = schedule { [weak self] in
            // 解除済みでも MainActor に届くことがあるため、古い追いかけは無視する。
            guard let self, followUpGeneration == current else { return }
            remainingFollowUps -= 1
            if remainingFollowUps == 0 {
                stopFollowUp()
            }
            onChange()
        }
    }

    private func stopFollowUp() {
        followUpGeneration &+= 1
        cancelFollowUp?()
        cancelFollowUp = nil
    }

    private static func scheduleNative(tick: @escaping Change) -> Cancel {
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return { timer.invalidate() }
    }

    private static func registerNative(onChange: @escaping Change) throws -> Cancel {
        guard let runLoop = CFRunLoopGetMain() else {
            throw CapsLockLEDError.keyboardMonitorCreationFailed
        }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOHIDManagerOptions.independentDevices.rawValue)
        let context = HIDKeyboardCallback(onChange: onChange)
        let pointer = Unmanaged.passUnretained(context).toOpaque()
        let matching = [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 6] as CFDictionary
        IOHIDManagerSetDeviceMatching(manager, matching)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, keyboardChanged, pointer)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, keyboardChanged, pointer)
        IOHIDManagerScheduleWithRunLoop(manager, runLoop, CFRunLoopMode.commonModes.rawValue)
        return {
            // context は両方の登録解除と unschedule が終わるまで保持する。
            withExtendedLifetime(context) {
                IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
                IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
                IOHIDManagerUnscheduleFromRunLoop(manager, runLoop, CFRunLoopMode.commonModes.rawValue)
            }
        }
    }
}

private final class HIDKeyboardCallback: Sendable {
    let onChange: HIDKeyboardMonitor.Change

    init(onChange: @escaping HIDKeyboardMonitor.Change) {
        self.onChange = onChange
    }
}

private let keyboardChanged: IOHIDDeviceCallback = { context, _, _, _ in
    guard let context else { return }
    // 生のポインターと借用デバイスは Task に渡さず、変更時点の意図もここでは読まない。
    let onChange = Unmanaged<HIDKeyboardCallback>.fromOpaque(context).takeUnretainedValue().onChange
    Task { @MainActor in onChange() }
}
