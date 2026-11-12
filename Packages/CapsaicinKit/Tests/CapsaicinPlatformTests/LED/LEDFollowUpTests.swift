@testable import CapsaicinPlatform
import Testing

@MainActor
struct LEDFollowUpTests {
    @Test("SPEC-LED-002 通知後に現れたサービスに1秒ごとに5回 On を書き、追いかけを終える")
    func delayedService() throws {
        let fake = LEDTestFixture()
        fake.devices = []
        let controller = fake.makeController()
        try controller.setLit(true)
        fake.changes[0]()
        #expect(fake.enumerations == 2)
        #expect(fake.writes.isEmpty)
        let tick = try #require(fake.ticks.first)
        fake.devices = [.init(name: "late")]
        for _ in 0 ..< 5 {
            tick()
        }
        #expect(fake.writes == Array(repeating: .init(device: "late", mode: "On"), count: 5))
        #expect(fake.creations == 7)
        #expect(fake.enumerations == 7)
        #expect(fake.activeSchedules.isEmpty)
        #expect(fake.scheduleCancellations == 1)
        tick()
        #expect(fake.enumerations == 7)
    }

    @Test("SPEC-LED-002 途中の接続・切断通知で5秒を数え直し、追いかけを重複させない")
    func notificationRestartsFollowUp() throws {
        let fake = LEDTestFixture()
        let controller = fake.makeController()
        try controller.setLit(true)
        fake.changes[0]()
        let oldTick = try #require(fake.ticks.first)
        for _ in 0 ..< 3 {
            oldTick()
        }
        for _ in 0 ..< 3 {
            let attempts = fake.enumerations
            fake.changes[0]()
            #expect(fake.enumerations == attempts + 1)
            #expect(fake.activeSchedules.count == 1)
        }
        #expect(fake.scheduleCancellations == 3)
        let attempts = fake.enumerations
        for tick in fake.ticks.dropLast() {
            tick()
        }
        #expect(fake.enumerations == attempts)
        let tick = try #require(fake.ticks.last)
        for _ in 0 ..< 5 {
            tick()
        }
        #expect(fake.enumerations == attempts + 5)
        #expect(fake.activeSchedules.isEmpty)
        tick()
        #expect(fake.enumerations == attempts + 5)
    }

    @Test("SPEC-LED-001 SPEC-LED-002 解除・監視停止で追いかけを止め、再開後も古い追いかけでは書かない",
          arguments: [true, false])
    func stopAndRestart(stopMonitoring: Bool) throws {
        let fake = LEDTestFixture()
        let controller = fake.makeController()
        try controller.setLit(true)
        fake.changes[0]()
        let oldTick = try #require(fake.ticks.first)
        oldTick()
        if stopMonitoring {
            controller.stopMonitoring()
        } else {
            try controller.setLit(false)
        }
        let attempts = fake.enumerations
        #expect(fake.activeSchedules.isEmpty)
        oldTick()
        fake.changes[0]()
        #expect(fake.enumerations == attempts)
        try controller.setLit(true)
        fake.changes[1]()
        oldTick()
        #expect(fake.enumerations == attempts + 2)
        let tick = try #require(fake.ticks.last)
        tick()
        #expect(fake.enumerations == attempts + 3)
        #expect(fake.activeSchedules.count == 1)
    }

    @Test("SPEC-LED-001 SPEC-LED-002 Auto が失敗しても点灯の意図を取り消し、追いかけを止める")
    func failedRestoreStopsFollowUp() throws {
        let fake = LEDTestFixture()
        let controller = fake.makeController()
        try controller.setLit(true)
        fake.changes[0]()
        let tick = try #require(fake.ticks.first)
        fake.failedDevices = ["internal"]
        #expect(throws: CapsLockLEDError.writeFailed(failedTargets: 1)) { try controller.setLit(false) }
        #expect(fake.activeSchedules.isEmpty)
        let attempts = fake.enumerations
        tick()
        #expect(fake.enumerations == attempts)
        #expect(fake.errors.isEmpty)
    }

    @Test("SPEC-LED-001 SPEC-LED-002 関数が使えなくても点灯の意図を取り消したら追いかけを止める")
    func unavailableOffStopsFollowUp() throws {
        let fake = LEDTestFixture()
        let controller = fake.makeController()
        try controller.setLit(true)
        fake.changes[0]()
        let tick = try #require(fake.ticks.first)
        fake.available = false
        try controller.setLit(false)
        #expect(fake.activeSchedules.isEmpty)
        #expect(fake.cancellations == 1)
        tick()
        #expect(fake.enumerations == 2)
    }

    @Test("SPEC-LED-002 通知なしの点灯・復帰では追いかけを始めない")
    func noNotificationDoesNotSchedule() throws {
        let fake = LEDTestFixture()
        let controller = fake.makeController()
        try controller.setLit(true)
        try controller.reapply()
        try controller.setLit(true)
        #expect(fake.ticks.isEmpty)
        #expect(fake.enumerations == 3)
    }

    @Test("SPEC-LED-002 追いかけの生成・列挙・書き込み失敗を通知し、次の追いかけで回復する",
          arguments: [CapsLockLEDError.clientCreationFailed, .servicesUnavailable, .writeFailed(failedTargets: 1)])
    func followUpFailureIsVisible(error: CapsLockLEDError) throws {
        let fake = LEDTestFixture()
        let controller = fake.makeController()
        try controller.setLit(true)
        fake.changes[0]()
        let tick = try #require(fake.ticks.first)
        fake.creationFails = error == .clientCreationFailed
        fake.enumerationFails = error == .servicesUnavailable
        fake.failedDevices = error == .writeFailed(failedTargets: 1) ? ["internal"] : []
        tick()
        #expect(fake.errors == [error])
        #expect(fake.activeSchedules.count == 1)
        fake.creationFails = false
        fake.enumerationFails = false
        fake.failedDevices = []
        fake.writes = []
        tick()
        #expect(fake.writes == ["internal", "external"].map { .init(device: $0, mode: "On") })
        #expect(fake.errors == [error])
    }

    @Test("SPEC-LED-002 通知時の書き込みが失敗しても追いかけで回復する")
    func immediateFailureStillSchedules() throws {
        let fake = LEDTestFixture()
        let controller = fake.makeController()
        try controller.setLit(true)
        fake.creationFails = true
        fake.changes[0]()
        #expect(fake.errors == [.clientCreationFailed])
        let tick = try #require(fake.ticks.first)
        fake.creationFails = false
        tick()
        #expect(fake.enumerations == 2)
    }

    @Test("SPEC-LED-002 即時・追いかけの失敗通知から停止しても追いかけを残さない", arguments: [true, false])
    func failureCallbackStopsFollowUp(immediate: Bool) throws {
        let fake = LEDTestFixture()
        let controller = fake.makeController()
        controller.onReapplyFailure = { [weak controller] _ in controller?.stopMonitoring() }
        try controller.setLit(true)
        if !immediate {
            fake.changes[0]()
        }
        fake.creationFails = true
        if immediate {
            fake.changes[0]()
        } else {
            let tick = try #require(fake.ticks.first)
            tick()
        }
        #expect(fake.activeSchedules.isEmpty)
        let attempts = fake.creations
        for tick in fake.ticks {
            tick()
        }
        #expect(fake.creations == attempts)
    }

    @Test("SPEC-LED-001 SPEC-LED-002 解放時に追いかけを止め、暗黙の LED 書き込みをしない")
    func deinitStopsFollowUp() throws {
        let fake = LEDTestFixture()
        var controller: CapsLockLEDController? = fake.makeController()
        try controller?.setLit(true)
        fake.changes[0]()
        let tick = try #require(fake.ticks.first)
        weak let released = controller
        controller = nil
        #expect(released == nil)
        #expect(fake.activeSchedules.isEmpty)
        #expect(fake.scheduleCancellations == 1)
        tick()
        #expect(fake.enumerations == 2)
    }
}
