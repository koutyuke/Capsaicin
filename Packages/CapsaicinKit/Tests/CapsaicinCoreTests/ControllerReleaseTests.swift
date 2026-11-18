@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation
import Testing

@MainActor
struct ControllerReleaseTests {
    private let manual = Settings.premise { $0.blocksManualSleep = true }

    @Test("SPEC-BLK-007 解除ではセッションを消して、すべての仕組みを停止中のあるべき状態に戻す")
    func releaseRestores() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise {
            $0.blocksManualSleep = true
            $0.blocksDisplaySleep = true
        })
        controller.requestStart(from: .menu)
        #expect(controller.requestStop(from: .menu) == .released)
        #expect(!controller.isBlocking)
        #expect(system.heldAssertions.isEmpty)
        #expect(!system.sleepDisabled)
        #expect(!system.isLEDLit)
        #expect(!controller.ownsSleepDisabled)
    }

    @Test("SPEC-BLK-007 off に失敗しても解除を完了し、戻すべきなのに残っている制御として残す")
    func releaseCompletesDespiteFailure() {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        let events = EventRecorder(controller)
        controller.requestStart(from: .menu)
        system.failing = [.helperOff]
        controller.requestStop(from: .menu)
        #expect(!controller.isBlocking)
        #expect(system.heldAssertions.isEmpty)
        #expect(!system.isLEDLit)
        #expect(controller.misalignments == [.systemSleepDisabled: .leftApplied])
        #expect(controller.ownsSleepDisabled)
        #expect(events.events.contains(.warningsChanged))
    }

    @Test("SPEC-BLK-007 合わせ直しは 1 分ごとに一覧の仕組みだけを操作し、合えば一覧から外す")
    func reconcileEveryMinute() {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        controller.requestStart(from: .menu)
        system.failing = [.helperOff]
        controller.requestStop(from: .menu)
        system.clearHistory()

        system.advance(by: 59)
        controller.timePassed()
        #expect(system.operations.isEmpty)

        system.advance(by: 1)
        controller.timePassed()
        #expect(system.operations == [.readSleepDisabled, .helperOff])
        #expect(controller.misalignments == [.systemSleepDisabled: .leftApplied])

        system.failing = []
        system.advance(by: 60)
        controller.timePassed()
        #expect(controller.misalignments.isEmpty)
        #expect(!system.sleepDisabled)
    }

    @Test("SPEC-BLK-007 SPEC-HLP-005 解除で下ろせなかった disablesleep は、次の開始で on を実行せずに引き継ぐ")
    func nextStartAdopts() {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        controller.requestStart(from: .menu)
        system.failing = [.helperOff]
        controller.requestStop(from: .menu)
        system.clearHistory()
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(!system.operations.contains(.helperOn))
        #expect(controller.misalignments.isEmpty)
        system.failing = []
        system.advance(by: 120)
        controller.timePassed()
        #expect(system.sleepDisabled)
    }

    @Test("SPEC-BLK-007 合わせられていない制御があっても、次の開始は妨げない")
    func leftoverDoesNotBlockStart() {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        controller.requestStart(from: .menu)
        system.failing = [.helperOff]
        controller.requestStop(from: .menu)
        // 手動スリープを止めない開始では、残っている disablesleep を戻そうとして失敗するが、開始はできる。
        controller.changeSettings(.premise())
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(controller.misalignments == [.systemSleepDisabled: .leftApplied])
    }

    @Test("SPEC-BLK-011 停止中の解除は、合わせられていない制御があれば合わせ直しを試み、なければ何もしない")
    func stopWhileStopped() {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        system.clearHistory()
        #expect(controller.requestStop(from: .cli) == .alreadyStopped)
        #expect(system.operations.isEmpty)

        controller.requestStart(from: .menu)
        system.failing = [.helperOff]
        controller.requestStop(from: .menu)
        system.failing = []
        #expect(controller.requestStop(from: .cli) == .alreadyStopped)
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-BLK-004 タイマーの解除の時刻になったら解除し、由来を理由にする")
    func timerRelease() {
        let system = FakeSystem()
        let controller = makeController(system)
        let events = EventRecorder(controller)
        controller.requestStart(from: .menu, override: .timer(minutes(10)))
        system.advance(by: 599)
        controller.timePassed()
        #expect(controller.isBlocking)
        system.advance(by: 1)
        controller.timePassed()
        #expect(!controller.isBlocking)
        #expect(events.stateEvents.last == .released(.timeLimit(.timer)))
    }

    @Test("SPEC-BLK-006 無視する設定で電源につながっている間に下回り、外した時点で解除する")
    func batteryReleaseOnUnplug() {
        let system = FakeSystem()
        system.powerState = PowerState(batteryLevel: 10, isOnACPower: true)
        let controller = makeController(system, settings: Settings())
        let events = EventRecorder(controller)
        #expect(controller.requestStart(from: .menu) == .started)
        system.powerState = PowerState(batteryLevel: 10, isOnACPower: false)
        controller.powerStateChanged()
        #expect(!controller.isBlocking)
        #expect(events.stateEvents.last == .released(.batteryBelowThreshold))
    }

    @Test("SPEC-BLK-007 時間の条件とバッテリー残量の条件が同時に成り立てば、時間の条件で解除する")
    func timeWinsOverBattery() {
        let system = FakeSystem()
        let controller = makeController(system, settings: Settings())
        let events = EventRecorder(controller)
        controller.requestStart(from: .menu, override: .timer(minutes(10)))
        system.advance(by: 600)
        system.powerState = PowerState(batteryLevel: 10, isOnACPower: false)
        controller.timePassed()
        #expect(events.stateEvents.last == .released(.timeLimit(.timer)))
    }

    @Test("SPEC-BLK-007 LED の点灯に失敗した後の解除では、通常の動作に戻す操作を1回試み、失敗したら戻すべきなのに残っている制御にする")
    func ledRestoreAfterFailedLight() {
        let system = FakeSystem()
        system.failing = [.setLEDLit(true)]
        let controller = makeController(system)
        controller.requestStart(from: .menu)
        #expect(controller.misalignments == [.led: .notApplied])
        system.failing = [.setLEDLit(true), .setLEDLit(false)]
        system.clearHistory()
        controller.requestStop(from: .menu)
        #expect(system.operations.count(where: { $0 == .setLEDLit(false) }) == 1)
        #expect(controller.misalignments == [.led: .leftApplied])
    }
}
