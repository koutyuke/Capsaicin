@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation
import Testing

@MainActor
struct ControllerBootTimeTests {
    private func storeOwnedSession(_ system: FakeSystem, running: Bool) {
        var record = ResumeRecord(lastUpdated: system.now)
        record.session = BlockingSession(timeLimit: TimeLimit(
            date: system.now.addingTimeInterval(3600),
            source: .timer,
        ))
        record.ownsSleepDisabled = true
        record.isRunning = running
        record.exitReason = running ? nil : .sessionEnd
        record.misalignments = [.systemSleepDisabled: .leftApplied]
        record.crashLaunches = [system.now]
        system.storedRecord = record
        system.sleepDisabled = true
        system.advance(by: 60)
    }

    private func settings(_ policy: ResumePolicy) -> Settings {
        .premise {
            $0.blocksManualSleep = true
            $0.resumePolicy = policy
        }
    }

    @Test(
        "SPEC-LCY-007 SPEC-HLP-005 起動時刻が取得不能なら、再開の設定にかかわらずセッションと所有を捨て、後片付けでも外部の 1 を下ろさない",
        arguments: [true, false], [ResumePolicy.never, .afterAppRestart, .afterAppOrMacRestart],
    )
    func unknownBootDropsSessionAndOwnership(running: Bool, policy: ResumePolicy) {
        let system = FakeSystem()
        storeOwnedSession(system, running: running)
        let crashLaunches = system.storedRecord?.crashLaunches
        system.bootTime = .distantPast
        let controller = makeController(system, settings: settings(policy), launch: false)
        let events = EventRecorder(controller)
        #expect(controller.launch() == .normal)
        #expect(!controller.isBlocking)
        #expect(system.savedRecords.first?.session == nil)
        #expect(system.savedRecords.first?.ownsSleepDisabled == false)
        #expect(system.storedRecord?.session == nil)
        #expect(system.storedRecord?.ownsSleepDisabled == false)
        #expect(system.storedRecord?.crashLaunches == crashLaunches)
        #expect(controller.misalignments.isEmpty)
        #expect(events.stateEvents.isEmpty)

        controller.reconcile()
        system.advance(by: 60)
        controller.timePassed()
        #expect(controller.requestStop(from: .menu) == .alreadyStopped)
        #expect(controller.prepareHelperRemoval())
        controller.helperRemovalFailed()
        #expect(!controller.quitByUser())
        #expect(system.savedRecords.allSatisfy { $0.session == nil && !$0.ownsSleepDisabled })
        #expect(!system.operations.contains(.helperOn))
        #expect(!system.operations.contains(.helperOff))
        #expect(system.sleepDisabled)
    }

    @Test("SPEC-HLP-005 起動時刻が取得不能でも、利用者が外部の 1 を使って開始した後の解除・終了・ヘルパー削除では下ろさない")
    func unknownBootKeepsExternalFlagAfterUserStart() {
        let system = FakeSystem()
        storeOwnedSession(system, running: true)
        system.bootTime = .distantPast
        let controller = makeController(system, settings: settings(.afterAppOrMacRestart))
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(controller.requestStop(from: .menu) == .released)
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(controller.prepareHelperRemoval())
        controller.helperRemovalFailed()
        controller.helperRemovalSucceeded()
        #expect(!controller.quitByUser())
        #expect(!system.operations.contains(.helperOn))
        #expect(!system.operations.contains(.helperOff))
        #expect(system.sleepDisabled)
        #expect(system.storedRecord?.ownsSleepDisabled == false)
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-LCY-007 SPEC-HLP-005 起動時刻が取得不能でも、後で利用者が 0 から開始したら、新たに所有を得て解除できる")
    func userStartCanAcquireFreshOwnershipAfterUnknownBoot() {
        let system = FakeSystem()
        storeOwnedSession(system, running: true)
        system.bootTime = .distantPast
        let controller = makeController(system, settings: settings(.afterAppOrMacRestart))
        system.sleepDisabled = false
        system.clearHistory()
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(system.operations.contains(.helperOn))
        #expect(system.savedRecords.first?.ownsSleepDisabled == true)
        #expect(system.savedRecords.first?.session == nil)
        #expect(system.storedRecord?.ownsSleepDisabled == true)
        #expect(system.sleepDisabled)
        #expect(controller.requestStop(from: .menu) == .released)
        #expect(system.operations.contains(.helperOff))
        #expect(system.storedRecord?.ownsSleepDisabled == false)
        #expect(!system.sleepDisabled)
    }

    @Test(
        "SPEC-LCY-004 SPEC-HLP-005 同じ Mac 起動内なら、再開するときは所有を引き継ぎ、再開しないときと後の解除では off する",
        arguments: [
            (true, ResumePolicy.never, false),
            (true, .afterAppRestart, true),
            (true, .afterAppOrMacRestart, true),
            (false, .never, false),
            (false, .afterAppRestart, false),
            (false, .afterAppOrMacRestart, true),
        ],
    )
    func knownSameBootKeepsOwnership(running: Bool, policy: ResumePolicy, resumes: Bool) {
        let system = FakeSystem()
        storeOwnedSession(system, running: running)
        let priorSession = system.storedRecord?.session
        let controller = makeController(system, settings: settings(policy), launch: false)
        #expect(controller.launch() == (running ? .afterCrash : .afterMacRestart))
        #expect(system.savedRecords.first?.ownsSleepDisabled == true)
        #expect(controller.isBlocking == resumes)
        #expect(controller.session == (resumes ? priorSession : nil))
        #expect(system.storedRecord?.ownsSleepDisabled == resumes)
        #expect(system.sleepDisabled == resumes)
        #expect(system.operations.contains(.helperOff) == !resumes)
        controller.requestStop(from: .menu)
        #expect(system.operations.filter { $0 == .helperOff }.count == 1)
        #expect(!system.operations.contains(.helperOn))
        #expect(system.storedRecord?.ownsSleepDisabled == false)
        #expect(!system.sleepDisabled)
    }

    @Test(
        "SPEC-LCY-004 SPEC-HLP-005 Mac の再起動を確認できたら、再開する場合も前回の所有を捨てて外部の 1 に触れない",
        arguments: [true, false], [ResumePolicy.never, .afterAppRestart, .afterAppOrMacRestart],
    )
    func knownRebootDropsOwnership(running: Bool, policy: ResumePolicy) {
        let system = FakeSystem()
        storeOwnedSession(system, running: running)
        system.bootTime = system.now.addingTimeInterval(-30)
        let controller = makeController(system, settings: settings(policy), launch: false)
        #expect(controller.launch() == .afterMacRestart)
        #expect(controller.isBlocking == (policy == .afterAppOrMacRestart))
        #expect(system.savedRecords.first?.ownsSleepDisabled == false)
        controller.requestStop(from: .menu)
        #expect(controller.prepareHelperRemoval())
        #expect(!system.operations.contains(.helperOn))
        #expect(!system.operations.contains(.helperOff))
        #expect(system.storedRecord?.ownsSleepDisabled == false)
        #expect(system.sleepDisabled)
    }

    @Test("SPEC-LCY-007 起動時刻は起動ごとに一度だけ読み、理由の判定と所有の更新に同じ値を使う")
    func launchReadsBootTimeOnce() {
        let system = FakeSystem()
        storeOwnedSession(system, running: true)
        let bootTime = CountingBootTime()
        var ports = system.ports
        ports.bootTime = bootTime
        let controller = BlockingController(settings: settings(.never), capabilities: .laptop, ports: ports)
        #expect(controller.launch() == .normal)
        #expect(bootTime.readCount == 1)
        #expect(system.savedRecords.first?.ownsSleepDisabled == false)
        #expect(!system.operations.contains(.helperOff))
    }
}

@MainActor
private final class CountingBootTime: BootTimeProviding {
    private(set) var readCount = 0

    var bootTime: Date {
        readCount += 1
        return .distantPast
    }
}
