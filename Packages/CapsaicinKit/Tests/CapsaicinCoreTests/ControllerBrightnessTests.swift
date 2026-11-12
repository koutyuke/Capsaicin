@testable import CapsaicinCore
import CapsaicinCoreTesting
import Testing

@MainActor
struct ControllerBrightnessTests {
    private var settings: Settings {
        .premise {
            $0.blocksManualSleep = true
            $0.lidCloseDisplay = .zeroBrightness
        }
    }

    @Test("SPEC-BLK-013 抑止中の明るさを0だけが閉じた通知で暗くする",
          arguments: [false, true], LidCloseDisplay.allCases)
    func closeNeedsBlockingAndChoice(blocking: Bool, choice: LidCloseDisplay) {
        let system = FakeSystem()
        var settings = settings
        settings.lidCloseDisplay = choice
        let controller = makeController(system, settings: settings)
        if blocking {
            controller.requestStart(from: .menu)
        }
        #expect(system.brightness == 0.5)
        system.clearHistory()
        controller.lidClosed()
        #expect(system.operations == (blocking && choice == .zeroBrightness
                ? [.readBrightness, .saveRecord, .setBrightness(0)] : []))
        #expect(system.storedRecord?.savedBrightness == (blocking && choice == .zeroBrightness ? 0.5 : nil))
    }

    @Test("SPEC-BLK-013 蓋の状態は起動時に開いており、抑止や設定によらず開閉の通知で更新する",
          arguments: [false, true], LidCloseDisplay.allCases)
    func lidStateTracksNotifications(blocking: Bool, choice: LidCloseDisplay) {
        let system = FakeSystem()
        var settings = settings
        settings.lidCloseDisplay = choice
        let controller = makeController(system, settings: settings)
        #expect(!controller.isLidClosed)
        if blocking {
            controller.requestStart(from: .menu)
        }
        controller.lidClosed()
        #expect(controller.isLidClosed)
        controller.lidOpened()
        #expect(!controller.isLidClosed)
    }

    @Test("SPEC-BLK-013 元の輝度を保存してから暗くし、二度目は記録を上書きしない")
    func savesBeforeDimmingAndKeepsOriginal() {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        system.clearHistory()
        controller.lidClosed()
        #expect(system.operations == [.readBrightness, .saveRecord, .setBrightness(0)])
        #expect(system.savedRecords.first?.savedBrightness == 0.5)
        #expect(system.brightness == 0)
        system.brightness = 0.2
        system.clearHistory()
        controller.lidClosed()
        #expect(system.operations == [.setBrightness(0)])
        #expect(system.storedRecord?.savedBrightness == 0.5)
        controller.lidOpened()
        #expect(system.brightness == 0.5)
    }

    @Test("SPEC-BLK-013 読み取り・保存失敗と対象なしでは暗くせず、警告も出さない",
          arguments: [0, 1, 2])
    func cannotPrepareDimming(failure: Int) {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        system.failing = failure == 0 ? [.readBrightness] : failure == 1 ? [.saveRecord] : []
        if failure == 2 {
            system.brightness = nil
        }
        system.clearHistory()
        let events = EventRecorder(controller)
        controller.lidClosed()
        #expect(!system.operations.contains(.setBrightness(0)))
        #expect(system.storedRecord?.savedBrightness == nil)
        #expect(controller.record.savedBrightness == nil)
        #expect(controller.isBlocking && !controller.status.hasWarnings)
        #expect(events.events.isEmpty)
        system.failing = []
        system.brightness = 0.7
        controller.lidClosed()
        #expect(system.storedRecord?.savedBrightness == 0.7)
    }

    @Test("SPEC-BLK-013 暗くする書き込みが失敗しても記録を残し、ディスプレイスリープや警告にしない")
    func dimWriteFailureKeepsRecord() {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        system.failing = [.setBrightness(0)]
        controller.lidClosed()
        #expect(system.brightness == 0.5)
        #expect(system.storedRecord?.savedBrightness == 0.5)
        #expect(controller.isBlocking && !controller.status.hasWarnings)
    }
}

extension ControllerBrightnessTests {
    @Test("SPEC-BLK-013 閉じている間に上がった輝度を時刻の経過で0に戻し、元の記録を保つ",
          arguments: [Float(0), 0.3])
    func timePassedKeepsBrightnessZero(current: Float) {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        system.brightness = current
        system.advance(by: 60)
        system.clearHistory()
        controller.timePassed()
        #expect(system.operations == (current > 0 ? [.readBrightness, .setBrightness(0)] : [.readBrightness]))
        #expect(system.brightness == 0)
        #expect(controller.record.savedBrightness == 0.5)
        #expect(system.storedRecord?.savedBrightness == 0.5)
        controller.lidOpened()
        #expect(system.brightness == 0.5)
    }

    @Test("SPEC-BLK-013 時刻の経過で暗くし直すのは抑止中の明るさを0だけ",
          arguments: [false, true], LidCloseDisplay.allCases)
    func timePassedNeedsBlockingAndChoice(blocking: Bool, choice: LidCloseDisplay) {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        if !blocking {
            system.failing = [.setBrightness(0.5)]
            controller.requestStop(from: .menu)
            system.failing = []
        }
        var settings = settings
        settings.lidCloseDisplay = choice
        controller.changeSettings(settings)
        system.brightness = 0.3
        system.advance(by: 60)
        system.clearHistory()
        controller.timePassed()
        #expect(system.operations == (blocking && choice == .zeroBrightness
                ? [.readBrightness, .setBrightness(0)] : []))
        #expect(controller.record.savedBrightness == 0.5)
    }

    @Test("SPEC-BLK-013 蓋が閉じていても輝度の記録がなければ時刻の経過で暗くしない")
    func timePassedNeedsSavedBrightness() {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        system.failing = [.readBrightness]
        controller.lidClosed()
        system.failing = []
        system.clearHistory()
        controller.timePassed()
        #expect(system.operations.isEmpty)
    }

    @Test("SPEC-BLK-013 起動時に復元が失敗しても閉じた通知なしでは暗くしない")
    func timePassedNeedsClosedNotification() {
        let system = FakeSystem()
        var record = ResumeRecord(lastUpdated: system.now)
        record.savedBrightness = 0.5
        record.isRunning = true
        record.session = BlockingSession(timeLimit: nil)
        system.storedRecord = record
        system.failing = [.setBrightness(0.5)]
        var settings = settings
        settings.resumePolicy = .afterAppRestart
        let controller = makeController(system, settings: settings)
        #expect(controller.isBlocking)
        #expect(controller.record.savedBrightness == 0.5)
        system.failing = []
        system.brightness = 0.3
        system.clearHistory()
        controller.timePassed()
        #expect(system.operations.isEmpty)
    }

    @Test("SPEC-BLK-013 暗くし直す読み取り・書き込み失敗と対象なしは記録を保ち、次回に再試行する",
          arguments: [0, 1, 2])
    func periodicFailureRetries(failure: Int) {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        system.brightness = failure == 2 ? nil : 0.3
        system.failing = failure == 0 ? [.readBrightness] : failure == 1 ? [.setBrightness(0)] : []
        system.clearHistory()
        let events = EventRecorder(controller)
        controller.timePassed()
        #expect(system.operations == (failure == 1 ? [.readBrightness, .setBrightness(0)] : [.readBrightness]))
        #expect(controller.record.savedBrightness == 0.5)
        #expect(system.storedRecord?.savedBrightness == 0.5)
        #expect(controller.isBlocking && !controller.status.hasWarnings)
        #expect(events.events.isEmpty)
        system.failing = []
        system.brightness = 0.3
        system.advance(by: 60)
        system.clearHistory()
        controller.timePassed()
        #expect(system.operations == [.readBrightness, .setBrightness(0)])
        #expect(system.brightness == 0)
    }

    @Test("SPEC-BLK-013 解除の条件が成り立つ時刻の経過では暗くし直さずに復元する")
    func timePassedReleasesBeforeDimming() {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu, override: .timer(minutes(1)))
        controller.lidClosed()
        system.brightness = 0.3
        system.advance(by: 60)
        system.clearHistory()
        controller.timePassed()
        #expect(!controller.isBlocking)
        #expect(!system.operations.contains(.readBrightness))
        #expect(!system.operations.contains(.setBrightness(0)))
        #expect(system.operations.contains(.setBrightness(0.5)))
        #expect(system.brightness == 0.5)
        #expect(system.storedRecord?.savedBrightness == nil)
    }
}

extension ControllerBrightnessTests {
    @Test("SPEC-BLK-013 開いたときは現在の輝度を読まず元に戻す。設定変更によらない",
          arguments: [Float(0), 0.3])
    func openRestoresSavedBrightness(current: Float) {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        controller.changeSettings(.premise())
        system.brightness = current
        system.failing = [.readBrightness]
        system.clearHistory()
        controller.lidOpened()
        #expect(system.operations == [.setBrightness(0.5), .saveRecord])
        #expect(system.brightness == 0.5)
        #expect(system.storedRecord?.savedBrightness == nil)
        system.clearHistory()
        controller.lidOpened()
        #expect(system.operations.isEmpty)
    }

    @Test("SPEC-BLK-013 復元の書き込み失敗は記録を残し、開いた後は暗くし直さず次の開いた通知で再試行する")
    func restoreFailureRetries() {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        system.failing = [.setBrightness(0.5)]
        controller.lidOpened()
        #expect(system.storedRecord?.savedBrightness == 0.5)
        #expect(controller.record.savedBrightness == 0.5)
        #expect(!controller.status.hasWarnings)
        system.failing = []
        system.brightness = 0.3
        system.clearHistory()
        controller.timePassed()
        #expect(system.operations.isEmpty)
        controller.lidOpened()
        #expect(system.brightness == 0.5)
        #expect(system.storedRecord?.savedBrightness == nil)
    }

    @Test("SPEC-BLK-013 復元後の記録消去に失敗しても警告にせず、次の通知で消去を再試行する")
    func recordClearFailureRetries() {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        system.failing = [.saveRecord]
        controller.lidOpened()
        #expect(system.brightness == 0.5)
        #expect(system.storedRecord?.savedBrightness == 0.5)
        #expect(!controller.status.hasWarnings)
        system.failing = []
        system.clearHistory()
        controller.lidOpened()
        #expect(system.operations == [.setBrightness(0.5), .saveRecord])
        #expect(system.storedRecord?.savedBrightness == nil)
    }

    @Test("SPEC-BLK-013 復元できなくても解除を完了し、記録を次の復元のために残す")
    func failedRestoreDoesNotBlockRelease() {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        system.failing = [.setBrightness(0.5)]
        system.clearHistory()
        #expect(controller.requestStop(from: .menu) == .released)
        #expect(!system.sleepDisabled)
        #expect(system.storedRecord?.savedBrightness == 0.5)
        #expect(!controller.status.hasWarnings)
        system.failing = []
        controller.lidOpened()
        #expect(system.brightness == 0.5)
        #expect(system.storedRecord?.savedBrightness == nil)
    }

    @Test("SPEC-BLK-013 SPEC-LCY-002 解除・利用者終了・理由不明終了・セッション終了はhelperOffより先に復元する",
          arguments: [0, 1, 2, 3])
    func restoresBeforeHelperOff(path: Int) throws {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        let session = controller.session
        system.clearHistory()
        switch path {
        case 0: controller.requestStop(from: .menu)
        case 1: _ = controller.quitByUser()
        case 2: controller.terminateForUnknownReason()
        default: controller.endSession()
        }
        let write = try #require(system.operations.firstIndex(of: .setBrightness(0.5)))
        let off = try #require(system.operations.firstIndex(of: .helperOff))
        #expect(write < off)
        #expect(system.savedRecords.first?.savedBrightness == nil)
        #expect(system.brightness == 0.5)
        #expect(system.storedRecord?.savedBrightness == nil)
        #expect(system.storedRecord?.session == (path == 3 ? session : nil))
        #expect(!system.sleepDisabled)
    }

    @Test("SPEC-BLK-013 SPEC-LCY-006 起動では再開・後片付けより先に復元する",
          arguments: [false, true])
    func launchRestoresBeforeStarting(resumes: Bool) throws {
        let system = FakeSystem()
        var record = ResumeRecord(lastUpdated: system.now)
        record.savedBrightness = 0.6
        record.isRunning = true
        record.session = BlockingSession(timeLimit: nil)
        record.ownsSleepDisabled = !resumes
        system.sleepDisabled = !resumes
        system.storedRecord = record
        system.brightness = 0
        var settings = settings
        settings.resumePolicy = resumes ? .afterAppRestart : .never
        let controller = makeController(system, settings: settings, launch: false)
        #expect(controller.launch() == .afterCrash)
        let write = try #require(system.operations.firstIndex(of: .setBrightness(0.6)))
        let mechanism = try #require(system.operations.firstIndex(of: resumes ? .helperOn : .helperOff))
        #expect(write < mechanism)
        #expect(system.storedRecord?.savedBrightness == nil)
        #expect(system.brightness == 0.6)
        #expect(controller.isBlocking == resumes)
    }
}
