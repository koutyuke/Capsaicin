import Foundation
import IOKit.hid

/// IOHIDManager は列挙通知にだけ使い、デバイスもマネージャーも open しない。
@MainActor
final class HIDKeyboardMonitor {
    typealias Change = @MainActor @Sendable () -> Void
    typealias Cancel = @MainActor () -> Void
    typealias Register = @MainActor (@escaping Change) throws -> Cancel

    private let register: Register
    private var cancel: Cancel?
    private var generation: UInt64 = 0
    private var isMonitoring = false

    init(register: @escaping Register = HIDKeyboardMonitor.registerNative) {
        self.register = register
    }

    func start(onChange: @escaping Change) throws {
        guard !isMonitoring else { return }
        generation &+= 1
        let current = generation
        isMonitoring = true
        do {
            cancel = try register { [weak self] in
                guard let self, isMonitoring, generation == current else { return }
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
        cancel?()
        cancel = nil
    }

    isolated deinit {
        stop()
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
