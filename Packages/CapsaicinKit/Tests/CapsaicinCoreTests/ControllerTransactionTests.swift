@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation
import Testing

@MainActor
struct ControllerTransactionTests {
    @Test(
        "SPEC-BLK-009 SPEC-BLK-007 仕組みを外せない設定変更はセッションと解除時刻を保って戻し、巻き戻しの合わせ直し後に変更を再試行できる",
        arguments: [false, true],
    )
    func failedMechanismRemovalRevertsAndCanRetry(rollbackFails: Bool) throws {
        let system = FakeSystem()
        let original = Settings.premise {
            $0.blocksDisplaySleep = true
            $0.timerEnabled = true
            $0.timerDuration = minutes(60)
        }
        let controller = makeController(system, settings: original)
        controller.requestStart(from: .menu)
        let session = try #require(controller.session)
        let events = EventRecorder(controller)
        var changed = original
        changed.blocksDisplaySleep = false
        changed.timerDuration = minutes(5)
        system.clearHistory()
        system.failing = [.releaseAssertion(.preventUserIdleDisplaySleep)]
        if rollbackFails {
            system.failing.insert(.createAssertion(.preventUserIdleDisplaySleep))
        }
        #expect(controller.changeSettings(changed) == .reverted(failed: [.displaySleepAssertion]))
        #expect(controller.settings == original)
        #expect(controller.session == session)
        #expect(system.operations == [
            .releaseAssertion(.preventUserIdleDisplaySleep),
            .createAssertion(.preventUserIdleDisplaySleep),
        ])
        #expect(controller.misalignments == (rollbackFails ? [.displaySleepAssertion: .notApplied] : [:]))
        #expect(system.heldAssertions == [.preventUserIdleSystemSleep, .preventUserIdleDisplaySleep])

        system.failing = []
        if rollbackFails {
            system.clearHistory()
            system.advance(by: 60)
            controller.timePassed()
            #expect(system.operations == [.createAssertion(.preventUserIdleDisplaySleep)])
            #expect(controller.misalignments.isEmpty)
            #expect(controller.settings == original)
            #expect(controller.session == session)
        }
        #expect(controller.changeSettings(changed) == .applied)
        #expect(controller.settings == changed)
        #expect(controller.session == session)
        #expect(system.heldAssertions == [.preventUserIdleSystemSleep])
        #expect(controller.misalignments.isEmpty)
        #expect(events.stateEvents.isEmpty)
    }
}
