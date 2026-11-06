@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation
import Testing

@MainActor
struct ControllerUnknownTerminationTests {
    @Test(
        "SPEC-LCY-002 SPEC-LCY-004 SPEC-LCY-007 理由不明の終了は全再開設定でセッションを消し、通常起動でも Mac 再起動後でも再開しない",
        arguments: [ResumePolicy.never, .afterAppRestart, .afterAppOrMacRestart],
    )
    func unknownTerminationDoesNotResume(policy: ResumePolicy) throws {
        let system = FakeSystem()
        let settings = Settings.premise {
            $0.resumePolicy = policy
            $0.blocksManualSleep = true
        }
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        let events = EventRecorder(controller)
        controller.terminateForUnknownReason()

        #expect(controller.session == nil)
        #expect(controller.record.session == nil)
        #expect(controller.record.crashLaunches.isEmpty)
        #expect(!system.sleepDisabled)
        #expect(system.heldAssertions.isEmpty)
        #expect(!system.isLEDLit)
        #expect(controller.misalignments.isEmpty)
        #expect(events.events.isEmpty)
        let stopped = try #require(system.storedRecord)
        #expect(stopped.session == nil)
        #expect(stopped.exitReason == nil)
        #expect(!stopped.isRunning)
        // nil の既存保存形式も、そのまま復号して次の起動に使える。
        let encoded = try JSONEncoder().encode(stopped)
        let decoded = try JSONDecoder().decode(ResumeRecord.self, from: encoded)
        #expect(decoded == stopped)
        for rebooted in [false, true] {
            system.storedRecord = decoded
            system.advance(by: 60)
            if rebooted {
                system.bootTime = system.now
            }
            let next = makeController(system, settings: settings, launch: false)
            #expect(next.launch() == .normal)
            #expect(!next.isBlocking)
        }
    }

    @Test("SPEC-LCY-007 理由不明の終了はメモリーと記録のセッションを後片付けのポート呼び出しより先に消す")
    func clearsSessionBeforeCleanup() {
        let system = FakeSystem()
        let helper = InspectingHelper(system)
        var ports = system.ports
        ports.helper = helper
        let controller = BlockingController(
            settings: .premise { $0.blocksManualSleep = true }, capabilities: .laptop, ports: ports,
        )
        controller.launch()
        controller.requestStart(from: .menu)
        var inspected = false
        helper.beforeOff = {
            inspected = true
            #expect(controller.session == nil)
            #expect(controller.record.session == nil)
            #expect(system.storedRecord?.session == nil)
        }
        system.clearHistory()
        controller.terminateForUnknownReason()
        #expect(inspected)
        #expect(system.operations.first == .saveRecord)
    }

    @Test("SPEC-LCY-002 SPEC-LCY-007 理由不明の終了で後片付けに失敗しても所有と未整合を残し、ダイアログや HUD の通知を出さない")
    func cleanupFailureRetainsOwnership() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        let events = EventRecorder(controller)
        system.failing = [.helperOff, .setLEDLit(false)]
        controller.terminateForUnknownReason()
        #expect(controller.session == nil)
        #expect(system.storedRecord?.session == nil)
        #expect(system.storedRecord?.exitReason == nil)
        #expect(system.storedRecord?.isRunning == false)
        #expect(system.storedRecord?.ownsSleepDisabled == true)
        #expect(controller.misalignments == [.systemSleepDisabled: .leftApplied, .led: .leftApplied])
        #expect(system.storedRecord?.misalignments == controller.misalignments)
        #expect(system.heldAssertions.isEmpty)
        #expect(events.events == [.warningsChanged])
        system.failing = []
        let next = makeController(system, launch: false)
        #expect(next.launch() == .normal)
        #expect(!next.isBlocking)
        #expect(!system.sleepDisabled)
        #expect(system.storedRecord?.ownsSleepDisabled == false)
        #expect(next.misalignments.isEmpty)
    }

    @Test("SPEC-LCY-007 理由不明の終了で保存に失敗したらメモリーを正とし、警告と古い記録の制約を保つ")
    func saveFailureKeepsMemoryAndWarning() throws {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise {
            $0.resumePolicy = .afterAppOrMacRestart
            $0.blocksManualSleep = true
        })
        controller.requestStart(from: .menu)
        let oldRecord = try #require(system.storedRecord)
        let events = EventRecorder(controller)
        system.failing = [.saveRecord]
        controller.terminateForUnknownReason()
        #expect(controller.session == nil)
        #expect(controller.record.session == nil)
        #expect(controller.record.exitReason == nil)
        #expect(!controller.record.isRunning)
        #expect(!controller.record.ownsSleepDisabled)
        #expect(controller.isRecordUnsaved)
        #expect(events.events == [.warningsChanged])
        #expect(!system.sleepDisabled)
        #expect(system.storedRecord == oldRecord)
        #expect(LaunchRules.launchReason(record: oldRecord, bootTime: system.bootTime) == .afterCrash)
        #expect(LaunchRules.shouldResume(
            reason: .afterCrash, policy: .afterAppOrMacRestart, session: oldRecord.session,
            isCrashLimitReached: false, now: system.now,
        ))
    }

    @Test("SPEC-LCY-002 SPEC-LCY-007 停止中でも理由不明の終了は古い終了理由を消す")
    func unknownTerminationWhileStopped() {
        let system = FakeSystem()
        let controller = makeController(system)
        controller.record.exitReason = .sessionEnd
        controller.terminateForUnknownReason()
        #expect(system.storedRecord?.exitReason == nil)
        #expect(system.storedRecord?.isRunning == false)
        #expect(system.storedRecord?.session == nil)
    }
}

@MainActor
private final class InspectingHelper: HelperSleepControlling {
    let system: FakeSystem
    var beforeOff: (() -> Void)?

    init(_ system: FakeSystem) {
        self.system = system
    }

    var isHelperInstalled: Bool {
        system.isHelperInstalled
    }

    func readSleepDisabled() throws -> Bool {
        try system.readSleepDisabled()
    }

    func turnOn() throws {
        try system.turnOn()
    }

    func turnOff() throws {
        beforeOff?()
        try system.turnOff()
    }
}
