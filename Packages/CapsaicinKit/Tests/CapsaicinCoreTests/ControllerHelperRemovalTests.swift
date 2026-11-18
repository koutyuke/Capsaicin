@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation
import Testing

@MainActor
struct ControllerHelperRemovalTests {
    @Test("SPEC-HLP-004 SPEC-HLP-005 ヘルパーの削除では、自分が立てた 1 のときだけ off で戻す")
    func helperRemovalReset() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        #expect(controller.prepareHelperRemoval())
        controller.requestStart(from: .menu)
        #expect(controller.prepareHelperRemoval())
        #expect(!system.sleepDisabled)
        #expect(system.operations.filter { $0 == .helperOff }.count == 1)
        #expect(system.storedRecord?.ownsSleepDisabled == false)
    }

    @Test("SPEC-HLP-004 削除に成功したら、所有を外してから手動スリープをオフにし、off を実行しない")
    func helperRemovalSucceeded() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        system.clearHistory()
        // 削除の処理が disablesleep を 0 に戻し、ヘルパーはなくなった。
        system.sleepDisabled = false
        system.isHelperInstalled = false
        system.failing = [.helperOff, .helperOn]
        controller.helperRemovalSucceeded()
        #expect(!controller.settings.blocksManualSleep)
        #expect(controller.isBlocking)
        #expect(!system.operations.contains(.helperOff))
        #expect(system.savedRecords.first?.ownsSleepDisabled == false)
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-HLP-004 削除に失敗したら、SleepDisabled を読み直して所有と合わせられていない制御を更新する")
    func helperRemovalFailed() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        system.failing = [.helperOff]
        controller.requestStop(from: .menu)
        #expect(controller.misalignments == [.systemSleepDisabled: .leftApplied])
        // 削除の処理の途中で disablesleep が 0 に戻った。
        system.sleepDisabled = false
        controller.helperRemovalFailed()
        #expect(controller.misalignments.isEmpty)
        #expect(system.storedRecord?.ownsSleepDisabled == false)
    }

    @Test("SPEC-HLP-004 SPEC-HLP-005 自分が立てた disablesleep を読めないときは削除せず所有を保つ")
    func helperRemovalResetsUnreadable() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        system.failing = [.readSleepDisabled]
        system.clearHistory()
        #expect(!controller.prepareHelperRemoval())
        #expect(!system.operations.contains(.helperOff))
        #expect(system.storedRecord?.ownsSleepDisabled == true)
    }

    @Test("SPEC-HLP-004 停止中に削除に成功したら、残っていた disablesleep を合わせられていない制御から外す")
    func helperRemovalSucceededWhileStopped() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        system.failing = [.helperOff]
        controller.requestStop(from: .menu)
        #expect(controller.misalignments == [.systemSleepDisabled: .leftApplied])
        system.sleepDisabled = false
        controller.helperRemovalSucceeded()
        #expect(controller.misalignments.isEmpty)
        #expect(system.storedRecord?.ownsSleepDisabled == false)
    }

    @Test("SPEC-HLP-004 削除に失敗して SleepDisabled が 1 のまま残れば、所有を保ち off しない")
    func helperRemovalFailedKeepsOwnership() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        system.failing = [.helperOff]
        controller.requestStop(from: .menu)
        system.clearHistory()
        controller.helperRemovalFailed()
        #expect(!system.operations.contains(.helperOff))
        #expect(system.storedRecord?.ownsSleepDisabled == true)
        #expect(controller.misalignments == [.systemSleepDisabled: .leftApplied])
    }

    @Test("SPEC-HLP-004 SPEC-BLK-007 削除失敗後に読み直せなければ、抑止中の見込みを不明にして所有を保ち、1 分後に適用し直す")
    func unreadableRemovalWhileBlockingReconciles() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        let session = controller.session
        let events = EventRecorder(controller)
        system.clearHistory()
        // 削除の処理で 0 に戻した後に失敗し、読み直しも失敗する。
        system.sleepDisabled = false
        system.failing = [.readSleepDisabled]
        controller.helperRemovalFailed()
        #expect(controller.observed[.systemSleepDisabled] == nil)
        #expect(controller.session == session)
        #expect(controller.settings.blocksManualSleep)
        #expect(controller.misalignments == [.systemSleepDisabled: .notApplied])
        #expect(system.storedRecord?.misalignments == controller.misalignments)
        #expect(system.storedRecord?.ownsSleepDisabled == true)
        #expect(system.operations == [.readSleepDisabled, .saveRecord])
        #expect(events.events == [.warningsChanged])

        system.failing = []
        system.clearHistory()
        system.advance(by: 60)
        controller.timePassed()
        #expect(system.operations.contains(.helperOn))
        #expect(!system.operations.contains(.helperOff))
        #expect(system.sleepDisabled)
        #expect(controller.observed[.systemSleepDisabled] == true)
        #expect(controller.misalignments.isEmpty)
        #expect(system.storedRecord?.misalignments.isEmpty == true)
        #expect(system.storedRecord?.ownsSleepDisabled == true)
        #expect(controller.session == session)
        #expect(events.events == [.warningsChanged, .warningsChanged])
    }

    @Test("SPEC-HLP-004 SPEC-BLK-007 停止中の削除失敗後も、読めない間は所有を保ち、1 分後に 0 を読めたら off せずに所有を外す")
    func unreadableRemovalWhileStoppedReconciles() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        system.failing = [.helperOff]
        controller.requestStop(from: .menu)
        system.sleepDisabled = false
        system.failing = [.readSleepDisabled]
        controller.helperRemovalFailed()
        #expect(controller.observed[.systemSleepDisabled] == nil)
        #expect(!controller.isBlocking)
        #expect(system.storedRecord?.ownsSleepDisabled == true)
        #expect(controller.misalignments == [.systemSleepDisabled: .leftApplied])
        #expect(system.storedRecord?.misalignments == controller.misalignments)

        system.failing = []
        system.clearHistory()
        system.advance(by: 60)
        controller.timePassed()
        #expect(!system.operations.contains(.helperOn))
        #expect(!system.operations.contains(.helperOff))
        #expect(system.storedRecord?.ownsSleepDisabled == false)
        #expect(controller.misalignments.isEmpty)
        #expect(system.storedRecord?.misalignments.isEmpty == true)
    }
}
