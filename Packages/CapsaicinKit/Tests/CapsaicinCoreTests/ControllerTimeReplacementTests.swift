@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation
import Testing

@MainActor
struct ControllerTimeReplacementTests {
    @Test("SPEC-BLK-011 SPEC-LCY-007 タイマーの置き換えは要求時刻を起点に記録を書き直し、仕組みに触れない")
    func replaceTimerFromRequestTime() throws {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise {
            $0.blocksManualSleep = true
            $0.blocksDisplaySleep = true
            $0.lidCloseDisplay = .zeroBrightness
        })
        controller.requestStart(from: .menu, override: .timer(minutes(60)))
        controller.lidClosed()
        system.advance(by: 600)
        let previousRecord = system.storedRecord
        let events = EventRecorder(controller)
        system.clearHistory()
        #expect(controller.requestStart(from: .cli, override: .timer(minutes(120))) == .timeLimitReplaced)
        let expected = BlockingSession(timeLimit: TimeLimit(
            date: system.now.addingTimeInterval(7200), source: .timer,
        ))
        #expect(controller.session == expected)
        #expect(system.storedRecord?.session == expected)
        #expect(system.storedRecord?.lastUpdated == system.now)
        #expect(system.storedRecord?.ownsSleepDisabled == previousRecord?.ownsSleepDisabled)
        #expect(system.storedRecord?.savedBrightness == previousRecord?.savedBrightness)
        #expect(system.brightness == 0)
        #expect(system.operations == [.saveRecord])
        #expect(system.sleepDisabled && system.isLEDLit)
        #expect(system.heldAssertions == [.preventUserIdleSystemSleep, .preventUserIdleDisplaySleep])
        #expect(events.events == [.timeLimitReplaced(.cli)])
        system.now = try #require(expected.timeLimit?.date)
        controller.timePassed()
        #expect(!controller.isBlocking)
        #expect(events.stateEvents.last == .released(.timeLimit(.timer)))
    }

    @Test("SPEC-BLK-011 SPEC-BLK-005 指定時刻の置き換えは要求時点の暦で決め、古い期限では解除しない",
          arguments: [time(4, 0), time(23, 5)])
    func replaceSpecifiedTime(specified: TimeOfDay) {
        let tokyo = calendar("Asia/Tokyo")
        let system = FakeSystem(now: tokyo.date(2026, 11, 6, 23, 0), calendar: tokyo)
        let controller = makeController(system)
        controller.requestStart(from: .menu, override: .timer(minutes(60)))
        system.advance(by: 600)
        let events = EventRecorder(controller)
        system.clearHistory()
        #expect(controller.requestStart(from: .menu, override: .specifiedTime(specified)) == .timeLimitReplaced)
        let expectedDate = tokyo.date(2026, 11, 7, specified.hour, specified.minute)
        #expect(controller.session?.timeLimit == TimeLimit(
            date: expectedDate, source: .specifiedTime,
        ))
        #expect(system.storedRecord?.session == controller.session)
        #expect(system.operations == [.saveRecord])
        #expect(events.events == [.timeLimitReplaced(.menu)])
        system.now = tokyo.date(2026, 11, 7, 0, 0)
        controller.timePassed()
        #expect(controller.isBlocking)
        system.now = expectedDate
        controller.timePassed()
        #expect(events.stateEvents.last == .released(.timeLimit(.specifiedTime)))
    }

    @Test("SPEC-BLK-011 SPEC-BLK-006 時間の条件なしへの置き換えはバッテリー条件を残す")
    func removeTimeLimitKeepsBattery() {
        let system = FakeSystem()
        let settings = Settings.premise { $0.batteryConditionEnabled = true }
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu, override: .timer(minutes(60)))
        let battery = controller.status.batteryCondition
        system.clearHistory()
        #expect(controller.requestStart(from: .menu, override: .noTimeLimit) == .timeLimitReplaced)
        #expect(controller.session == BlockingSession(timeLimit: nil))
        #expect(system.storedRecord?.session == controller.session)
        #expect(controller.status.batteryCondition == battery)
        #expect(controller.settings == settings)
        #expect(system.operations == [.saveRecord])
        system.advance(by: 7200)
        controller.timePassed()
        #expect(controller.isBlocking)
        system.powerState = PowerState(batteryLevel: 1, isOnACPower: false)
        controller.powerStateChanged()
        #expect(!controller.isBlocking)
    }

    @Test("SPEC-BLK-003 停止中の時間の条件なしは設定のタイマーと指定時刻を使わない")
    func startWithoutTimeIgnoresDefaults() {
        let system = FakeSystem()
        let settings = Settings.premise {
            $0.timerEnabled = true
            $0.specifiedTimeEnabled = true
        }
        let controller = makeController(system, settings: settings)
        #expect(controller.requestStart(from: .menu, override: .noTimeLimit) == .started)
        #expect(controller.session == BlockingSession(timeLimit: nil))
        #expect(system.storedRecord?.session == controller.session)
        #expect(controller.settings == settings)
    }

    @Test("SPEC-BLK-011 期限以上での置き換えは自動解除を先に行い、開始し直さない",
          arguments: [StartTimeOverride.timer(minutes(30)), .specifiedTime(time(18, 0)), .noTimeLimit],
          [0.0, 1.0])
    func expiredBeforeReplacement(override: StartTimeOverride, delay: Double) throws {
        let system = FakeSystem()
        let controller = makeController(system)
        controller.requestStart(from: .menu, override: .timer(minutes(1)))
        system.now = try #require(controller.session?.timeLimit?.date).addingTimeInterval(delay)
        let events = EventRecorder(controller)
        system.clearHistory()
        #expect(controller.requestStart(from: .cli, override: override) == .released)
        #expect(!controller.isBlocking)
        #expect(system.storedRecord?.session == nil)
        #expect(system.heldAssertions.isEmpty)
        #expect(!system.isLEDLit)
        #expect(events.stateEvents == [.released(.timeLimit(.timer))])
        #expect(!system.operations.contains(.createAssertion(.preventUserIdleSystemSleep)))
    }

    @Test("SPEC-BLK-011 タイマーの置き換えは期限を短くもでき、バッテリー条件を変えない")
    func shortenTimerKeepsBattery() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.batteryConditionEnabled = true })
        controller.requestStart(from: .menu, override: .timer(minutes(120)))
        system.advance(by: 600)
        let battery = controller.status.batteryCondition
        #expect(controller.requestStart(from: .cli, override: .timer(minutes(15))) == .timeLimitReplaced)
        #expect(controller.session?.timeLimit == TimeLimit(date: system.now.addingTimeInterval(900), source: .timer))
        #expect(controller.status.batteryCondition == battery)
    }

    @Test("SPEC-LCY-007 置き換えの保存失敗は抑止を続けて警告し、既存の合わせ直しで再保存する")
    func replacementSaveFailureRetries() {
        let system = FakeSystem()
        let controller = makeController(system)
        controller.requestStart(from: .menu, override: .timer(minutes(60)))
        let stored = system.storedRecord
        system.failing = [.saveRecord]
        let events = EventRecorder(controller)
        system.clearHistory()
        #expect(controller.requestStart(from: .menu, override: .timer(minutes(120))) == .timeLimitReplaced)
        let updated = controller.session
        #expect(controller.isBlocking && controller.isRecordUnsaved)
        #expect(system.storedRecord == stored)
        #expect(system.operations == [.saveRecord])
        #expect(events.events == [.timeLimitReplaced(.menu), .warningsChanged])
        system.failing = []
        system.advance(by: 60)
        controller.timePassed()
        #expect(!controller.isRecordUnsaved)
        #expect(system.storedRecord?.session == updated)
        #expect(system.operations == [.saveRecord, .saveRecord])
    }
}
