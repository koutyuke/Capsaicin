@testable import CapsaicinPlatform
import Testing

@MainActor
struct VirtualKeyboardMonitorTests {
    @Test("SPEC-LED-005 Transport のないキーボードだけを検出し、LED には書かない",
          arguments: [true, false], [nil, "USB", "Virtual"] as [String?])
    func keyboardServices(keyboard: Bool, transport: String?) {
        let fake = LEDTestFixture()
        fake.devices.append(.init(name: "candidate", keyboard: keyboard, transport: transport))
        let monitor = makeMonitor(fake)
        #expect(fake.creations == 0)
        monitor.start()
        #expect(monitor.state == (keyboard && transport == nil))
        #expect(fake.creations == 1)
        #expect(fake.enumerations == 1)
        #expect(fake.writes.isEmpty)
        #expect(fake.registrations == 0)
    }

    @Test("SPEC-LED-005 実機だけ、Transport が Virtual のキーボードだけ、空の一覧では案内しない",
          arguments: [nil, "USB", "Virtual"] as [String?])
    func noVirtualKeyboard(transport: String?) {
        let fake = LEDTestFixture()
        fake.devices = []
        if let transport {
            fake.devices.append(.init(name: "candidate", transport: transport))
        }
        let monitor = makeMonitor(fake)
        monitor.start()
        #expect(!monitor.state)
        #expect(fake.enumerations == 1)
    }

    @Test("SPEC-LED-005 確認のたびにサービスを列挙し直し、仮想キーボードの出入りを通知する")
    func serviceTransitions() {
        let fake = LEDTestFixture()
        var tick: VirtualKeyboardMonitor.Tick?
        let monitor = makeMonitor(fake, schedule: {
            tick = $0
            return {}
        })
        var states: [Bool] = []
        monitor.onStateChange = { states.append($0) }
        monitor.start()
        fake.devices.append(.init(name: "virtual", transport: nil))
        tick?()
        fake.devices.removeLast()
        tick?()
        #expect(states == [true, false])
        #expect(fake.creations == 3)
        #expect(fake.enumerations == 3)
        #expect(fake.writes.isEmpty)
    }

    @Test("SPEC-LED-005 SPEC-LED-006 関数がないときはクライアントを作らず、検出失敗にも数えない")
    func absentAPI() {
        let fake = LEDTestFixture()
        fake.available = false
        fake.creationFails = true
        let monitor = makeMonitor(fake)
        monitor.onDetectionFailure = { _ in Issue.record("関数の不在は検出失敗ではない") }
        monitor.start()
        #expect(!monitor.state)
        #expect(fake.creations == 0)
        #expect(fake.enumerations == 0)
        #expect(fake.writes.isEmpty)
    }

    @Test("SPEC-LED-005 生成・列挙の失敗は検出失敗として報告し、次の確認で回復する",
          arguments: [CapsLockLEDError.clientCreationFailed, .servicesUnavailable])
    func clientFailure(error: CapsLockLEDError) {
        let fake = LEDTestFixture()
        fake.devices.append(.init(name: "virtual", transport: nil))
        var tick: VirtualKeyboardMonitor.Tick?
        let monitor = makeMonitor(fake, schedule: {
            tick = $0
            return {}
        })
        var failures = 0
        monitor.onDetectionFailure = {
            #expect(($0 as? CapsLockLEDError) == error)
            failures += 1
        }
        monitor.start()
        #expect(monitor.state)
        fake.creationFails = error == .clientCreationFailed
        fake.enumerationFails = error == .servicesUnavailable
        tick?()
        #expect(!monitor.state)
        #expect(failures == 1)
        fake.creationFails = false
        fake.enumerationFails = false
        tick?()
        #expect(monitor.state)
        #expect(fake.writes.isEmpty)
    }

    private func makeMonitor(
        _ fake: LEDTestFixture,
        schedule: @escaping VirtualKeyboardMonitor.Schedule = { _ in {} },
    ) -> VirtualKeyboardMonitor {
        VirtualKeyboardMonitor(symbolAvailable: { fake.available }, makeClient: fake.makeClient, schedule: schedule)
    }

    @Test("SPEC-LED-005 明示的に開始し、仮想キーボードの有無の変化だけを通知する")
    func transitions() {
        let fake = DetectionFixture()
        let monitor = fake.makeMonitor()
        #expect(fake.reads == 0)
        #expect(!monitor.state)
        monitor.start()
        monitor.start()
        fake.ticks[0]()
        fake.result = .success(true)
        fake.ticks[0]()
        fake.ticks[0]()
        fake.result = .success(false)
        fake.ticks[0]()
        #expect(fake.states == [true, false])
        #expect(fake.ticks.count == 1)
        #expect(fake.reads == 5)
    }

    @Test("SPEC-LED-005 検出失敗は仮想キーボードなしとみなし、失敗を報告して次の確認を続ける")
    func detectionFailure() {
        let fake = DetectionFixture()
        let monitor = fake.makeMonitor()
        fake.result = .success(true)
        monitor.start()
        fake.result = .failure(.servicesUnavailable)
        fake.ticks[0]()
        fake.ticks[0]()
        #expect(!monitor.state)
        #expect(fake.states == [true, false])
        #expect(fake.failures == 2)
        fake.result = .success(true)
        fake.ticks[0]()
        #expect(fake.states == [true, false, true])
    }

    @Test("SPEC-LED-005 停止でタイマーを解除し、再開できる")
    func stopAndRestart() {
        let fake = DetectionFixture()
        let monitor = fake.makeMonitor()
        monitor.start()
        monitor.stop()
        monitor.stop()
        fake.ticks[0]()
        #expect(fake.reads == 1)
        #expect(fake.cancellations == 1)
        monitor.start()
        fake.ticks[1]()
        #expect(fake.reads == 3)
    }

    @Test("SPEC-LED-005 初回通知から停止しても監視を残さない")
    func reentrantStop() {
        let fake = DetectionFixture()
        fake.result = .success(true)
        let monitor = fake.makeMonitor()
        monitor.onStateChange = { [weak monitor] _ in monitor?.stop() }
        monitor.start()
        #expect(fake.cancellations == 1)
        fake.ticks[0]()
        #expect(fake.reads == 1)
    }

    @Test("SPEC-LED-005 解放時に監視を止める")
    func deinitCancels() {
        let fake = DetectionFixture()
        var monitor: VirtualKeyboardMonitor? = fake.makeMonitor()
        monitor?.start()
        weak let released = monitor
        monitor = nil
        #expect(released == nil)
        #expect(fake.cancellations == 1)
        fake.ticks[0]()
        #expect(fake.reads == 1)
    }
}

@MainActor
private final class DetectionFixture {
    var result: Result<Bool, CapsLockLEDError> = .success(false)
    var reads = 0
    var cancellations = 0
    var ticks: [VirtualKeyboardMonitor.Tick] = []
    var states: [Bool] = []
    var failures = 0

    func makeMonitor() -> VirtualKeyboardMonitor {
        let monitor = VirtualKeyboardMonitor(detect: {
            self.reads += 1
            return try self.result.get()
        }, schedule: { tick in
            self.ticks.append(tick)
            return { self.cancellations += 1 }
        })
        monitor.onStateChange = { self.states.append($0) }
        monitor.onDetectionFailure = { _ in self.failures += 1 }
        return monitor
    }
}
