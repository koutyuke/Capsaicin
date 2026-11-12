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

    @Test("SPEC-BLK-013 開いたとき0なら復元し、変更済みなら書かずに記録を消す。設定変更によらない",
          arguments: [Float(0), 0.3])
    func openRestoresOnlyZero(current: Float) {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        controller.changeSettings(.premise())
        system.brightness = current
        system.clearHistory()
        controller.lidOpened()
        #expect(system.operations == (current == 0
                ? [.readBrightness, .setBrightness(0.5), .saveRecord] : [.readBrightness, .saveRecord]))
        #expect(system.brightness == (current == 0 ? 0.5 : current))
        #expect(system.storedRecord?.savedBrightness == nil)
        system.clearHistory()
        controller.lidOpened()
        #expect(system.operations.isEmpty)
    }

    @Test("SPEC-BLK-013 復元の読み取り・書き込み失敗と対象なしは記録を残し、次の開いた通知で再試行する",
          arguments: [0, 1, 2])
    func restoreFailureRetries(failure: Int) {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        system.failing = failure == 0 ? [.readBrightness] : failure == 1 ? [.setBrightness(0.5)] : []
        if failure == 2 {
            system.brightness = nil
        }
        controller.lidOpened()
        #expect(system.storedRecord?.savedBrightness == 0.5)
        #expect(controller.record.savedBrightness == 0.5)
        #expect(!controller.status.hasWarnings)
        system.failing = []
        system.brightness = 0
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
        #expect(system.operations == [.readBrightness, .saveRecord])
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
