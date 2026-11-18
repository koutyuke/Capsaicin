@testable import CapsaicinCore
import CapsaicinCoreTesting
import Testing

@MainActor
struct ControllerHelperConnectionTests {
    private let manual = Settings.premise { $0.blocksManualSleep = true }

    @Test("SPEC-HLP-002 SPEC-HLP-005 owned の SleepDisabled が 0 なら設定変更で off を送らず接続を閉じる")
    func noOffNeeded() {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(system.hasHelperConnection)
        system.sleepDisabled = false
        system.clearHistory()

        #expect(controller.changeSettings(.premise()) == .applied)
        #expect(controller.isBlocking)
        #expect(!system.hasHelperConnection && !controller.ownsSleepDisabled)
        #expect(system.operations == [.readSleepDisabled])
    }

    @Test("SPEC-HLP-005 中断時は SleepDisabled が 1 のままでも on を送り直して接続を保つ")
    func interruptionResendsOn() {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        #expect(controller.requestStart(from: .menu) == .started)
        let session = controller.session
        system.closeConnection()
        system.clearHistory()

        controller.helperConnectionLost(.interrupted)

        #expect(system.operations == [.helperOn])
        #expect(system.sleepDisabled && system.hasHelperConnection)
        #expect(controller.ownsSleepDisabled && controller.session == session)
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-HLP-005 SPEC-BLK-007 送り直せないか接続が無効なら、値が 1 でも合わせ直しで役目を戻す",
          arguments: [HelperConnectionLoss.interrupted, .invalid])
    func lossReconcilesCleanupRole(loss: HelperConnectionLoss) {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        #expect(controller.requestStart(from: .menu) == .started)
        let events = EventRecorder(controller)
        system.closeConnection()
        system.clearHistory()
        system.failing = [.helperOn]

        controller.helperConnectionLost(loss)

        #expect(system.operations == (loss == .interrupted ? [.helperOn] : []))
        #expect(system.sleepDisabled && !system.hasHelperConnection)
        #expect(controller.misalignments == [.systemSleepDisabled: .notApplied])
        #expect(events.events == [.warningsChanged])
        system.failing = []
        system.clearHistory()
        system.advance(by: 60)
        controller.timePassed()

        #expect(system.operations == [.readSleepDisabled, .helperOn])
        #expect(system.hasHelperConnection && controller.isBlocking)
        #expect(controller.misalignments.isEmpty)
        #expect(events.events == [.warningsChanged, .warningsChanged])
    }

    @Test("SPEC-HLP-004 SPEC-BLK-007 切断と承認待ちで保存値を変えずに抑止を解除し、再送しない",
          arguments: [HelperConnectionLoss.interrupted, .invalid], [false, true])
    func approvalRevocationReleases(loss: HelperConnectionLoss, sleepDisabledRemains: Bool) {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(system.isLEDLit)
        let events = EventRecorder(controller)
        system.isHelperInstalled = false
        system.isHelperAwaitingApproval = true
        system.closeConnection()
        system.sleepDisabled = sleepDisabledRemains
        system.clearHistory()

        controller.helperConnectionLost(loss)

        #expect(!controller.isBlocking && !system.isLEDLit && system.heldAssertions.isEmpty)
        #expect(controller.settings == manual)
        #expect(controller.ownsSleepDisabled == sleepDisabledRemains)
        #expect(controller.misalignments == (sleepDisabledRemains ? [.systemSleepDisabled: .leftApplied] : [:]))
        #expect(events.stateEvents == [.released(.helperApprovalRevoked)])
        #expect(!system.operations.contains(.helperOn) && !system.operations.contains(.helperOff))
    }

    @Test("SPEC-HLP-005 SPEC-BLK-007 読めずに解除しても接続は閉じ、未確認の所有は保つ")
    func releaseClosesConnectionOnUnreadableValue() {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        #expect(controller.requestStart(from: .menu) == .started)
        system.failing = [.readSleepDisabled]
        #expect(controller.requestStop(from: .menu) == .released)
        #expect(!system.hasHelperConnection && controller.ownsSleepDisabled)
        #expect(controller.misalignments == [.systemSleepDisabled: .leftApplied])

        system.failing = []
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(system.hasHelperConnection)
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-HLP-002 SPEC-BLK-009 設定変更の off が失敗したら、元の抑止に後片付けの役目も戻す")
    func failedOffDuringSettingsChangeRestoresCleanupRole() {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        #expect(controller.requestStart(from: .menu) == .started)
        system.failing = [.helperOff]
        system.clearHistory()

        #expect(controller.changeSettings(.premise()) == .reverted(failed: [.systemSleepDisabled]))
        #expect(controller.isBlocking && controller.settings == manual)
        #expect(system.hasHelperConnection && controller.misalignments.isEmpty)
        #expect(system.operations == [.readSleepDisabled, .helperOff, .readSleepDisabled, .helperOn])
    }
}
