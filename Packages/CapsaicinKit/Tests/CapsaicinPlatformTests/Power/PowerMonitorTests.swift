import CapsaicinCore
@testable import CapsaicinPlatform
import Testing

@MainActor
struct PowerPlatformMonitorTests {
    @Test("SPEC-BLK-006 電源は初期読み取りし、変化だけを通知、停止は冪等")
    func powerChangesAndStop() throws {
        var state = PowerState(batteryLevel: 60, isOnACPower: true)
        var callbacks: [@MainActor () -> Void] = []
        var cancels = 0
        var changes: [PowerState] = []
        let monitor = PowerStateMonitor(read: { state }, observe: { callback in
            callbacks.append(callback)
            return { cancels += 1 }
        })
        #expect(monitor.powerState == state)
        state.batteryLevel = 59
        try monitor.start { changes.append($0) }
        #expect(changes == [state])
        callbacks[0]()
        #expect(changes.count == 1)
        try monitor.start { _ in Issue.record("二重開始でハンドラーが置き換わった") }
        #expect(callbacks.count == 1)
        state.isOnACPower = false
        callbacks[0]()
        #expect(changes == [PowerState(batteryLevel: 59, isOnACPower: true), state])
        monitor.stop()
        monitor.stop()
        #expect(cancels == 1)
        state.batteryLevel = 58
        callbacks[0]()
        #expect(monitor.powerState.batteryLevel == 59)
        try monitor.start { changes.append($0) }
        #expect(changes.count == 3)
        state.batteryLevel = 57
        callbacks[0]()
        #expect(changes.count == 3)
        callbacks[1]()
        #expect(changes.count == 4)
        monitor.stop()
        #expect(cancels == 2)
    }

    @Test("SPEC-BLK-006 電源監視の登録失敗は再試行でき、破棄で登録を解除")
    func powerRegistrationFailureAndDeinit() throws {
        var fails = true
        var cancelled = 0
        var monitor: PowerStateMonitor? = PowerStateMonitor(
            read: { PowerState(batteryLevel: nil, isOnACPower: false) },
            observe: { _ in
                if fails {
                    throw PowerPlatformError.unavailable("fake")
                }
                return { cancelled += 1 }
            },
        )
        #expect(throws: PowerPlatformError.unavailable("fake")) { try monitor?.start { _ in } }
        fails = false
        try monitor?.start { _ in }
        monitor = nil
        #expect(cancelled == 1)
    }

    @Test("SPEC-BLK-002 蓋は開→閉だけを通知し、重複・bit1・別メッセージを無視")
    func lidTransitionsAndStop() throws {
        var initial: Bool? = false
        var callbacks: [@MainActor (UInt32, UInt) -> Void] = []
        var closes = 0
        var cancels = 0
        let monitor = LidStateMonitor(read: { initial }, observe: { callback in
            callbacks.append(callback)
            return { cancels += 1 }
        })
        try monitor.start(onClose: { closes += 1 }, onOpen: {})
        try monitor.start(onClose: { Issue.record("二重開始でハンドラーが置き換わった") }, onOpen: {})
        #expect(callbacks.count == 1)
        let message = LidStateMonitor.clamshellMessage
        callbacks[0](message &+ 1, 1)
        #expect(monitor.isClosed == false)
        callbacks[0](message, 2)
        callbacks[0](message, 1)
        callbacks[0](message, 1)
        callbacks[0](message, 3)
        #expect(closes == 1)
        callbacks[0](message, 0)
        callbacks[0](message, 3)
        #expect(closes == 2)
        monitor.stop()
        monitor.stop()
        #expect(cancels == 1)
        callbacks[0](message, 0)
        #expect(monitor.isClosed == true)
        initial = false
        try monitor.start(onClose: { closes += 1 }, onOpen: {})
        callbacks[0](message, 1)
        #expect(closes == 2)
        callbacks[1](message, 1)
        #expect(closes == 3)
        monitor.stop()
        #expect(cancels == 2)
    }

    @Test("SPEC-BLK-002 初期の閉状態・不明状態では消灯イベントを捏造しない")
    func lidUnknownAndClosedBaseline() throws {
        for initial: Bool? in [nil, true] {
            var callback: (@MainActor (UInt32, UInt) -> Void)?
            var closes = 0
            let monitor = LidStateMonitor(read: { initial }, observe: {
                callback = $0
                return {}
            })
            try monitor.start(onClose: { closes += 1 }, onOpen: {})
            callback?(LidStateMonitor.clamshellMessage, 1)
            #expect(closes == 0)
            callback?(LidStateMonitor.clamshellMessage, 0)
            callback?(LidStateMonitor.clamshellMessage, 1)
            #expect(closes == 1)
            monitor.stop()
        }
    }

    @Test("SPEC-BLK-002 蓋監視の登録失敗は再試行でき、破棄で登録を解除")
    func lidRegistrationFailureAndDeinit() throws {
        var fails = true
        var cancelled = 0
        var monitor: LidStateMonitor? = LidStateMonitor(read: { false }, observe: { _ in
            if fails {
                throw PowerPlatformError.unavailable("fake")
            }
            return { cancelled += 1 }
        })
        #expect(throws: PowerPlatformError.unavailable("fake")) { try monitor?.start(onClose: {}, onOpen: {}) }
        fails = false
        try monitor?.start(onClose: {}, onOpen: {})
        monitor = nil
        #expect(cancelled == 1)
    }

    @Test("SPEC-BLK-013 閉じたと分かっている状態から開いたときだけ通知する",
          arguments: [Bool?.none, false, true])
    func lidOpenTransitions(initial: Bool?) throws {
        var callbacks: [@MainActor (UInt32, UInt) -> Void] = []
        var opens = 0
        var closes = 0
        let monitor = LidStateMonitor(read: { initial }, observe: {
            callbacks.append($0)
            return {}
        })
        try monitor.start(onClose: { closes += 1 }, onOpen: { opens += 1 })
        try monitor.start(onClose: { Issue.record("ハンドラーの上書き") },
                          onOpen: { Issue.record("ハンドラーの上書き") })
        #expect(opens == 0 && closes == 0)
        let message = LidStateMonitor.clamshellMessage
        callbacks[0](message &+ 1, 0)
        callbacks[0](message, 0)
        callbacks[0](message, 2)
        #expect(opens == (initial == true ? 1 : 0))
        callbacks[0](message, 1)
        callbacks[0](message, 3)
        callbacks[0](message, 0)
        #expect(opens == (initial == true ? 2 : 1))
        #expect(closes == 1)
        monitor.stop()
        callbacks[0](message, 1)
        callbacks[0](message, 0)
        #expect(opens == (initial == true ? 2 : 1))
        try monitor.start(onClose: {}, onOpen: { opens += 1 })
        callbacks[0](message, 1)
        callbacks[0](message, 0)
        #expect(opens == (initial == true ? 2 : 1))
        callbacks[1](message, 1)
        callbacks[1](message, 0)
        #expect(opens == (initial == true ? 3 : 2))
        monitor.stop()
    }
}
