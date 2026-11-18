@testable import CapsaicinCore
import CapsaicinCoreTesting
import Testing

@MainActor
struct ControllerLifecycleTests {
    @Test("SPEC-LCY-006 SPEC-HLP-005 起動は停止中で、外部の disablesleep に触れず LED を通常の連動に戻す")
    func launchLeavesExternalSleepDisabledUntouched() throws {
        let system = FakeSystem()
        system.sleepDisabled = true
        try system.setLit(true)
        system.clearHistory()
        let controller = makeController(system, settings: .premise {
            $0.blocksManualSleep = true
            $0.notifiesWithLED = false
        })
        #expect(!controller.isBlocking)
        #expect(!controller.ownsSleepDisabled)
        #expect(system.sleepDisabled)
        #expect(!system.isLEDLit)
        #expect(system.operations == [.setLEDLit(false)])
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-LCY-006 SPEC-BLK-007 起動時に LED を戻せない場合はメモリー上の一覧に残し、合わせ直せる")
    func launchReevaluatesLED() throws {
        let system = FakeSystem()
        try system.setLit(true)
        system.failing = [.setLEDLit(false)]
        let controller = makeController(system)
        #expect(controller.misalignments == [.led: .leftApplied])
        #expect(system.brightnessRecord == nil)
        system.failing = []
        controller.reconcile()
        #expect(!system.isLEDLit)
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-HLP-005 起動後の on と off は所有をメモリー上だけで更新する")
    func claimsAndLowersWithoutPersistence() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        system.clearHistory()
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(controller.ownsSleepDisabled)
        #expect(system.operations == [
            .readSleepDisabled, .helperOn, .createAssertion(.preventUserIdleSystemSleep), .setLEDLit(true),
        ])
        #expect(controller.requestStop(from: .menu) == .released)
        #expect(!controller.ownsSleepDisabled)
        #expect(!system.sleepDisabled)
        #expect(system.brightnessRecord == nil)
    }

    @Test("SPEC-HLP-005 SPEC-BLK-007 次のプロセスは前の所有や合わせられていない制御を引き継がない")
    func newProcessDoesNotInheritOwnershipOrWarnings() {
        let system = FakeSystem()
        let settings = Settings.premise { $0.blocksManualSleep = true }
        let first = makeController(system, settings: settings)
        first.requestStart(from: .menu)
        system.failing = [.helperOff]
        first.requestStop(from: .menu)
        #expect(first.misalignments == [.systemSleepDisabled: .leftApplied])
        system.clearHistory()
        let second = makeController(system, settings: settings)
        #expect(!second.isBlocking)
        #expect(!second.ownsSleepDisabled)
        #expect(second.misalignments.isEmpty)
        #expect(system.sleepDisabled)
        #expect(system.operations == [.setLEDLit(false)])
    }

    @Test("SPEC-BLK-013 SPEC-LCY-006 起動時は輝度が 0 のときだけ復元し、どちらも記録は削除する",
          arguments: [Float(0), 0.3])
    func launchRestoresOnlyFromZero(current: Float) {
        let system = FakeSystem()
        system.brightnessRecord = BrightnessRecord(savedBrightness: 0.6)
        system.brightness = current
        let controller = makeController(system)
        #expect(system.operations ==
            [.readBrightness] + (current == 0 ? [.setBrightness(0.6)] : []) + [
                .removeBrightnessRecord,
                .setLEDLit(false),
            ])
        #expect(system.brightnessRecord == nil)
        #expect(system.brightness == (current == 0 ? 0.6 : current))
        #expect(!controller.isBlocking)
    }

    @Test("SPEC-BLK-013 起動時に輝度を読めない・書けないときは記録を残し、次に開いたときに復元する",
          arguments: [FakeSystem.Operation.readBrightness, .setBrightness(0.6)])
    func launchKeepsRecordOnFailure(failure: FakeSystem.Operation) {
        let system = FakeSystem()
        system.brightnessRecord = BrightnessRecord(savedBrightness: 0.6)
        system.brightness = 0
        system.failing = [failure]
        let controller = makeController(system)
        #expect(system.brightnessRecord?.savedBrightness == 0.6)
        #expect(!controller.status.hasWarnings)
        system.failing = []
        controller.lidOpened()
        #expect(system.brightness == 0.6)
        #expect(system.brightnessRecord == nil)
    }

    @Test("SPEC-LCY-008 輝度を含まない旧記録はディスプレイに触れずに削除する")
    func legacyRecordWithoutBrightness() {
        let system = FakeSystem()
        system.brightnessRecord = BrightnessRecord(savedBrightness: nil)
        _ = makeController(system)
        #expect(system.operations == [.removeBrightnessRecord, .setLEDLit(false)])
        #expect(system.brightnessRecord == nil)
    }
}
