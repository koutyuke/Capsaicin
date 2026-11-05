@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation
import Testing

@MainActor
struct ControllerLifecycleTests {
    private let resumeOnCrash = Settings.premise {
        $0.resumePolicy = .afterAppRestart
        $0.blocksManualSleep = true
    }

    /// 抑止中にクラッシュした状態を作る。記録はそのまま残り、プロセスの仕組みの見込みは失われる。
    private func crashWhileBlocking(_ system: FakeSystem, settings: Settings, timer: Int? = nil) {
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu, override: timer.map { .timer(minutes($0)) })
        system.advance(by: 60)
    }

    @Test("SPEC-LCY-007 初めての起動は通常の起動で、停止中で起動し、記録を作って実行中の印を立てる")
    func firstLaunch() {
        let system = FakeSystem()
        let controller = makeController(system, launch: false)
        #expect(controller.launch() == .normal)
        #expect(!controller.isBlocking)
        #expect(system.storedRecord?.isRunning == true)
    }

    @Test("SPEC-LCY-006 通常の起動でも、前のプロセスから残った蓋閉じスリープの制御と LED を戻す")
    func normalLaunchRestoresLeftovers() {
        let system = FakeSystem()
        var record = ResumeRecord(lastUpdated: system.now)
        record.exitReason = .userQuit
        system.storedRecord = record
        let controller = makeController(system, launch: false)
        #expect(controller.launch() == .normal)
        #expect(system.operations.contains(.setLidSleepDisabled(false)))
        #expect(system.operations.contains(.setLEDLit(false)))
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-LCY-004 クラッシュ後に再開し、記録の解除の時刻と由来を引き継ぐ")
    func resumeAfterCrash() {
        let system = FakeSystem()
        crashWhileBlocking(system, settings: resumeOnCrash, timer: 60)
        let limit = system.storedRecord?.session?.timeLimit
        system.clearHistory()
        let controller = makeController(system, settings: resumeOnCrash, launch: false)
        let events = EventRecorder(controller)
        #expect(controller.launch() == .afterCrash)
        #expect(controller.isBlocking)
        #expect(controller.session?.timeLimit == limit)
        #expect(events.stateEvents == [.started(.resume)])
        // 自分が立てた disablesleep は on を実行せずに引き継ぐ。
        #expect(!system.operations.contains(.helperOn))
        #expect(system.sleepDisabled)
    }

    @Test("SPEC-LCY-004 SPEC-LCY-006 再開しないときは、セッションを消して前のプロセスが立てた disablesleep を下ろす")
    func noResumeRestores() {
        let system = FakeSystem()
        crashWhileBlocking(system, settings: .premise { $0.blocksManualSleep = true })
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true }, launch: false)
        #expect(controller.launch() == .afterCrash)
        #expect(!controller.isBlocking)
        #expect(!system.sleepDisabled)
        #expect(system.storedRecord?.session == nil)
        #expect(system.storedRecord?.ownsSleepDisabled == false)
    }

    @Test("SPEC-LCY-004 解除の時刻を過ぎていたら再開しない")
    func expiredSessionDoesNotResume() {
        let system = FakeSystem()
        crashWhileBlocking(system, settings: resumeOnCrash, timer: 5)
        system.advance(by: 600)
        let controller = makeController(system, settings: resumeOnCrash)
        #expect(!controller.isBlocking)
    }

    @Test("SPEC-LCY-006 再開がバッテリー残量の条件で拒否されたら、セッションを消して停止中で起動する")
    func resumeRejected() {
        let system = FakeSystem()
        var settings = resumeOnCrash
        settings.batteryConditionEnabled = true
        crashWhileBlocking(system, settings: settings)
        system.powerState = PowerState(batteryLevel: 10, isOnACPower: false)
        let controller = makeController(system, settings: settings, launch: false)
        let events = EventRecorder(controller)
        controller.launch()
        #expect(!controller.isBlocking)
        #expect(events.stateEvents == [.startRejected(.resume, .batteryBelowThreshold)])
        #expect(!system.sleepDisabled)
        #expect(system.storedRecord?.session == nil)

        let second = makeController(system, settings: settings, launch: false)
        #expect(second.launch() == .afterCrash)
        #expect(!second.isBlocking)
    }

    @Test("SPEC-LCY-006 連続クラッシュの3回目の起動では再開しない")
    func crashLimit() {
        let system = FakeSystem()
        crashWhileBlocking(system, settings: resumeOnCrash)
        for _ in 1 ... 2 {
            let controller = makeController(system, settings: resumeOnCrash)
            #expect(controller.isBlocking)
            system.advance(by: 60)
        }
        let third = makeController(system, settings: resumeOnCrash)
        #expect(!third.isBlocking)
        #expect(!system.sleepDisabled)
    }

    @Test("SPEC-LCY-006 SPEC-LCY-007 上限の判定の後に中断しても、クラッシュ後の起動の時刻は残り、次も再開しない")
    func crashLaunchRecordedBeforeResume() throws {
        let system = FakeSystem()
        crashWhileBlocking(system, settings: resumeOnCrash)
        for _ in 1 ... 2 {
            _ = makeController(system, settings: resumeOnCrash)
            system.advance(by: 60)
        }
        // 3回目のクラッシュ後の起動が、時刻を記録した最初の保存の直後で中断した記録を作る。
        var interrupted = try #require(system.storedRecord)
        interrupted.crashLaunches = LaunchRules.updatingCrashLaunches(
            interrupted.crashLaunches, at: system.now, afterCrash: true,
        )
        system.storedRecord = interrupted
        #expect(interrupted.session != nil)
        #expect(interrupted.isRunning)
        system.advance(by: 60)
        let fourth = makeController(system, settings: resumeOnCrash)
        #expect(!fourth.isBlocking)
    }

    @Test("SPEC-LCY-004 Mac の再起動の後は「アプリと Mac の再起動時」のときだけ再開する")
    func resumeAfterMacRestart() {
        let system = FakeSystem()
        let settings = Settings.premise { $0.resumePolicy = .afterAppOrMacRestart }
        let first = makeController(system, settings: settings)
        first.requestStart(from: .menu)
        first.endSession()
        system.advance(by: 60)
        system.bootTime = system.now
        system.advance(by: 60)
        let controller = makeController(system, settings: settings, launch: false)
        #expect(controller.launch() == .afterMacRestart)
        #expect(controller.isBlocking)

        var appOnly = settings
        appOnly.resumePolicy = .afterAppRestart
        controller.endSession()
        #expect(!makeController(system, settings: appOnly).isBlocking)
    }

    @Test("SPEC-LCY-002 利用者の終了は解除として戻し、終了の理由を記録して実行中の印を下ろす")
    func quitByUser() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise {
            $0.resumePolicy = .afterAppOrMacRestart
            $0.blocksManualSleep = true
        })
        let events = EventRecorder(controller)
        controller.requestStart(from: .menu)
        #expect(!controller.quitByUser())
        #expect(!system.sleepDisabled)
        #expect(events.stateEvents.last == .released(.quit))
        #expect(system.storedRecord?.exitReason == .userQuit)
        #expect(system.storedRecord?.isRunning == false)
        #expect(system.storedRecord?.session == nil)
        #expect(!makeController(system).isBlocking)
    }

    @Test("SPEC-LCY-002 利用者の終了で合わせられていない制御が残れば、それを知らせる")
    func quitWithLeftover() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        system.failing = [.helperOff]
        #expect(controller.quitByUser())
        #expect(system.storedRecord?.misalignments == [.systemSleepDisabled: .leftApplied])
    }

    @Test("SPEC-LCY-002 セッションの終了では仕組みを戻し、セッションは記録に残す")
    func sessionEnd() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.blocksManualSleep = true })
        controller.requestStart(from: .menu)
        controller.endSession()
        #expect(!system.sleepDisabled)
        #expect(system.heldAssertions.isEmpty)
        #expect(!system.isLEDLit)
        #expect(system.storedRecord?.session != nil)
        #expect(system.storedRecord?.exitReason == .sessionEnd)
        #expect(system.storedRecord?.isRunning == false)
    }

    /// 所有が「立てた」で、外部の disablesleep が立っている記録を置く。
    private func storeOwnedRecord(_ system: FakeSystem, running: Bool, exit: ExitReason?, bootedAfter: Bool) {
        var record = ResumeRecord(lastUpdated: system.now)
        record.ownsSleepDisabled = true
        record.isRunning = running
        record.exitReason = exit
        system.storedRecord = record
        system.sleepDisabled = true
        system.bootTime = system.now.addingTimeInterval(bootedAfter ? 30 : -3600)
        system.advance(by: 60)
    }

    @Test(
        "SPEC-LCY-007 SPEC-HLP-005 Mac の起動の後は所有を外し、外部の disablesleep を off しない",
        arguments: [(true, ExitReason?.none), (false, .sessionEnd)],
    )
    func rebootDropsOwnership(running: Bool, exit: ExitReason?) {
        let system = FakeSystem()
        storeOwnedRecord(system, running: running, exit: exit, bootedAfter: true)
        let controller = makeController(system, launch: false)
        #expect(controller.launch() == .afterMacRestart)
        #expect(!system.operations.contains(.helperOff))
        #expect(system.sleepDisabled)
        #expect(system.storedRecord?.ownsSleepDisabled == false)
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-LCY-007 SPEC-HLP-005 ログアウトの後は Mac が起動していないので、所有を保って off する")
    func logoutKeepsOwnership() {
        let system = FakeSystem()
        storeOwnedRecord(system, running: false, exit: .sessionEnd, bootedAfter: false)
        let controller = makeController(system, launch: false)
        #expect(controller.launch() == .afterMacRestart)
        #expect(system.operations.contains(.helperOff))
        #expect(!system.sleepDisabled)
    }

    @Test("SPEC-LCY-007 SPEC-HLP-005 クラッシュの後は所有を保つ")
    func crashKeepsOwnership() {
        let system = FakeSystem()
        storeOwnedRecord(system, running: true, exit: nil, bootedAfter: false)
        let controller = makeController(system, launch: false)
        #expect(controller.launch() == .afterCrash)
        #expect(system.savedRecords.first?.ownsSleepDisabled == true)
        #expect(system.operations.contains(.helperOff))
    }
}
