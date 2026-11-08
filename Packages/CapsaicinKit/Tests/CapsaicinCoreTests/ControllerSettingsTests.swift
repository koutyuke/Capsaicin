@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation
import Testing

@MainActor
struct ControllerSettingsTests {
    @Test("SPEC-BLK-009 抑止中にタイマーを変えても、解除の時刻とその由来は変えずに設定は受け入れる")
    func timeSettingsDoNotAffectSession() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.timerEnabled = true })
        controller.requestStart(from: .menu)
        let session = controller.session
        let changed = Settings.premise {
            $0.timerEnabled = true
            $0.timerDuration = minutes(10)
        }
        #expect(controller.changeSettings(changed) == .applied)
        #expect(controller.session == session)
        #expect(controller.settings == changed)
        system.advance(by: 600)
        controller.timePassed()
        #expect(controller.isBlocking)
    }

    @Test("SPEC-BLK-009 止めるスリープの変更は、その場でいまの抑止に反映する")
    func sleepSettingsApplyImmediately() {
        let system = FakeSystem()
        let controller = makeController(system)
        controller.requestStart(from: .menu)
        let events = EventRecorder(controller)
        #expect(controller.changeSettings(.premise { $0.blocksDisplaySleep = true }) == .applied)
        #expect(system.heldAssertions == [.preventUserIdleSystemSleep, .preventUserIdleDisplaySleep])
        #expect(events.events.isEmpty)
    }

    @Test("SPEC-BLK-009 反映できない変更は設定を変更前に戻し、抑止はそのまま続く")
    func failedChangeReverts() {
        let system = FakeSystem()
        system.failing = [.helperOn]
        let original = Settings.premise()
        let controller = makeController(system, settings: original)
        controller.requestStart(from: .menu)
        let result = controller.changeSettings(.premise { $0.blocksManualSleep = true })
        #expect(result == .reverted(failed: [.systemSleepDisabled]))
        #expect(controller.settings == original)
        #expect(controller.isBlocking)
        #expect(system.heldAssertions == [.preventUserIdleSystemSleep])
        #expect(controller.misalignments.isEmpty)
        #expect(system.storedRecord?.ownsSleepDisabled == false)
    }

    @Test("SPEC-BLK-009 巻き戻しでも合わせられなかった仕組みは、合わせられていない制御になり、次の合わせ直しで直る")
    func revertFailureBecomesMisalignment() {
        let system = FakeSystem()
        let controller = makeController(system)
        controller.requestStart(from: .menu)
        system.failing = [.createAssertion(.preventUserIdleDisplaySleep),
                          .releaseAssertion(.preventUserIdleDisplaySleep)]
        let result = controller.changeSettings(.premise {
            $0.blocksDisplaySleep = true
        })
        #expect(result == .reverted(failed: [.displaySleepAssertion]))
        #expect(!controller.settings.blocksDisplaySleep)
        #expect(controller.misalignments == [.displaySleepAssertion: .leftApplied])

        system.failing = []
        system.advance(by: 60)
        controller.timePassed()
        #expect(controller.misalignments.isEmpty)
        #expect(system.heldAssertions == [.preventUserIdleSystemSleep])
    }

    @Test("SPEC-BLK-009 抑止中に LED で知らせるをオンにして点灯できなければ、設定を戻す")
    func ledChangeReverts() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.notifiesWithLED = false })
        controller.requestStart(from: .menu)
        system.failing = [.setLEDLit(true)]
        #expect(controller.changeSettings(.premise()) == .reverted(failed: [.led]))
        #expect(!controller.settings.notifiesWithLED)
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-BLK-009 SPEC-HLP-005 抑止中に手動スリープをオフにしたら、自分が立てた disablesleep を下ろす")
    func manualOffLowers() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        #expect(controller.changeSettings(.premise()) == .applied)
        #expect(!system.sleepDisabled)
        #expect(system.storedRecord?.ownsSleepDisabled == false)
    }

    @Test("SPEC-BLK-009 バッテリー残量の条件の変更はその場で効き、成り立てば解除する")
    func batteryChangeReleases() throws {
        let system = FakeSystem()
        system.powerState = PowerState(batteryLevel: 30, isOnACPower: false)
        let controller = makeController(system, settings: Settings())
        controller.requestStart(from: .menu)
        var raised = Settings()
        raised.batteryThreshold = try #require(BatteryThreshold(percent: 40))
        #expect(controller.changeSettings(raised) == .applied)
        #expect(!controller.isBlocking)
    }

    @Test("SPEC-BLK-009 停止中の設定の変更は仕組みに触れず、常に受け入れる")
    func stoppedChangeAlwaysApplies() {
        let system = FakeSystem()
        system.failing = [.helperOn]
        let controller = makeController(system)
        system.clearHistory()
        let changed = Settings.premise { $0.blocksManualSleep = true }
        #expect(controller.changeSettings(changed) == .applied)
        #expect(controller.settings == changed)
        #expect(system.operations.isEmpty)
    }

    @Test("SPEC-BLK-002 SPEC-BLK-009 閉じたときの画面を変えても仕組みは触らず保存値だけ更新する")
    func lidCloseDisplayDoesNotChangeMechanisms() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        system.clearHistory()
        var changed = controller.settings
        changed.lidCloseDisplay = .keepOn
        #expect(controller.changeSettings(changed) == .applied)
        #expect(controller.settings == changed)
        #expect(system.operations == [.saveRecord])
        #expect(controller.misalignments.isEmpty)
        #expect(controller.isBlocking)
    }

    @Test("SPEC-BLK-007 SPEC-BLK-009 あるべき状態が変わらない合わせられていない仕組みは、設定の変更で操作せずに引き継ぐ")
    func unchangedMisalignmentIsCarried() {
        let system = FakeSystem()
        system.failing = [.setLEDLit(true)]
        let controller = makeController(system)
        controller.requestStart(from: .menu)
        #expect(controller.misalignments == [.led: .notApplied])
        system.clearHistory()
        #expect(controller.changeSettings(.premise { $0.blocksDisplaySleep = true }) == .applied)
        #expect(!system.operations.contains {
            if case .setLEDLit = $0 {
                true
            } else {
                false
            }
        })
        #expect(controller.misalignments == [.led: .notApplied])
    }

    @Test(
        "SPEC-BLK-007 SPEC-BLK-009 無関係な設定変更を繰り返しても、未試行の制御は元の期限で合わせ直す",
        arguments: [false, true],
    )
    func unrelatedChangesDoNotPostponeRetry(changesMechanism: Bool) {
        let system = FakeSystem()
        system.failing = [.setLEDLit(true)]
        let controller = makeController(system)
        controller.requestStart(from: .menu)
        #expect(controller.misalignments == [.led: .notApplied])
        system.failing = []
        system.clearHistory()

        for _ in 0 ..< 2 {
            system.advance(by: 20)
            var changed = controller.settings
            if changesMechanism {
                changed.blocksDisplaySleep.toggle()
            } else {
                changed.showsHUD.toggle()
            }
            #expect(controller.changeSettings(changed) == .applied)
            controller.timePassed()
            #expect(!system.operations.contains(.setLEDLit(true)))
        }

        system.advance(by: 20)
        controller.timePassed()
        #expect(system.isLEDLit)
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-HUD-001 SPEC-BLK-009 設定の変更でバッテリー残量の条件が成り立った解除は、バッテリー残量による解除として通知する")
    func batteryReleaseBySettingsChangeIsNotified() throws {
        let system = FakeSystem()
        system.powerState = PowerState(batteryLevel: 30, isOnACPower: false)
        let controller = makeController(system, settings: Settings())
        controller.requestStart(from: .menu)
        let events = EventRecorder(controller)
        var raised = Settings()
        raised.batteryThreshold = try #require(BatteryThreshold(percent: 40))
        controller.changeSettings(raised)
        #expect(events.stateEvents == [.released(.batteryBelowThreshold)])
    }
}
