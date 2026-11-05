@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation
import Testing

@MainActor
struct ControllerTransactionTests {
    @Test(
        "SPEC-LCY-007 SPEC-BLK-010 所有の保存と on が成功した後にセッションを保存できなければ巻き戻し、off の失敗は再試行する",
        arguments: [false, true],
    )
    func sessionSaveFailureRollsBackOwnedFlag(offFails: Bool) throws {
        let system = FakeSystem()
        let records = SessionSaveFailingStore(system)
        var ports = system.ports
        ports.records = records
        let controller = BlockingController(
            settings: .premise { $0.blocksManualSleep = true }, capabilities: .laptop, ports: ports,
        )
        controller.launch()
        let events = EventRecorder(controller)
        system.clearHistory()
        system.failing = offFails ? [.helperOff] : []
        #expect(controller.requestStart(from: .menu, override: .timer(minutes(60))) == .rejected(.recordNotSaved))
        let operations = system.operations
        let ownershipSave = try #require(operations.firstIndex(of: .saveRecord))
        let turnOn = try #require(operations.firstIndex(of: .helperOn))
        let turnOff = try #require(operations.firstIndex(of: .helperOff))
        #expect(ownershipSave < turnOn && turnOn < turnOff)
        #expect(system.savedRecords.first?.ownsSleepDisabled == true)
        #expect(system.savedRecords.first?.session == nil)
        #expect(records.failedRecord?.ownsSleepDisabled == true)
        #expect(records.failedRecord?.session == BlockingSession(
            timeLimit: TimeLimit(date: system.now.addingTimeInterval(3600), source: .timer),
        ))
        #expect(!controller.isBlocking)
        #expect(system.storedRecord?.session == nil)
        #expect(system.storedRecord?.ownsSleepDisabled == offFails)
        #expect(system.sleepDisabled == offFails)
        #expect(system.heldAssertions.isEmpty)
        #expect(!system.isLEDLit)
        #expect(controller.misalignments == (offFails ? [.systemSleepDisabled: .leftApplied] : [:]))
        #expect(system.storedRecord?.misalignments == controller.misalignments)
        #expect(!controller.isRecordUnsaved)
        #expect(events.stateEvents == [.startRejected(.user(.menu), .recordNotSaved)])

        if offFails {
            system.failing = []
            system.clearHistory()
            system.advance(by: 60)
            controller.timePassed()
            #expect(system.operations.contains(.helperOff))
            #expect(!system.sleepDisabled)
            #expect(system.storedRecord?.ownsSleepDisabled == false)
            #expect(controller.misalignments.isEmpty)
        }
    }

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
        #expect(system.storedRecord?.session == session)
        #expect(system.operations == [
            .releaseAssertion(.preventUserIdleDisplaySleep),
            .createAssertion(.preventUserIdleDisplaySleep),
            .saveRecord,
        ])
        #expect(controller.misalignments == (rollbackFails ? [.displaySleepAssertion: .notApplied] : [:]))
        #expect(system.storedRecord?.misalignments == controller.misalignments)
        #expect(system.heldAssertions == [.preventUserIdleSystemSleep, .preventUserIdleDisplaySleep])

        system.failing = []
        if rollbackFails {
            system.clearHistory()
            system.advance(by: 60)
            controller.timePassed()
            #expect(system.operations == [.createAssertion(.preventUserIdleDisplaySleep), .saveRecord])
            #expect(controller.misalignments.isEmpty)
            #expect(controller.settings == original)
            #expect(controller.session == session)
        }
        #expect(controller.changeSettings(changed) == .applied)
        #expect(controller.settings == changed)
        #expect(controller.session == session)
        #expect(system.storedRecord?.session == session)
        #expect(system.heldAssertions == [.preventUserIdleSystemSleep])
        #expect(controller.misalignments.isEmpty)
        #expect(events.stateEvents.isEmpty)
    }
}

@MainActor
private final class SessionSaveFailingStore: ResumeRecordStoring {
    let system: FakeSystem
    private(set) var failedRecord: ResumeRecord?

    init(_ system: FakeSystem) {
        self.system = system
    }

    func load() -> ResumeRecord? {
        system.load()
    }

    func save(_ record: ResumeRecord) -> Bool {
        guard record.session == nil else {
            failedRecord = record
            return false
        }
        return system.save(record)
    }
}
