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
                ? [.readBrightness, .saveBrightnessRecord(0.5), .setBrightness(0)] : []))
        #expect(system.brightnessRecord?.savedBrightness == (blocking && choice == .zeroBrightness ? 0.5 : nil))
    }

    @Test("SPEC-BLK-013 元の輝度を保存してから暗くし、二度目は記録を上書きしない")
    func savesBeforeDimmingAndKeepsOriginal() {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        system.clearHistory()
        controller.lidClosed()
        #expect(system.operations == [.readBrightness, .saveBrightnessRecord(0.5), .setBrightness(0)])
        #expect(system.brightnessRecord?.savedBrightness == 0.5)
        #expect(system.brightness == 0)
        system.brightness = 0.2
        system.clearHistory()
        controller.lidClosed()
        #expect(system.operations == [.setBrightness(0)])
        #expect(system.brightnessRecord?.savedBrightness == 0.5)
        controller.lidOpened()
        #expect(system.brightness == 0.5)
    }

    @Test("SPEC-BLK-013 読み取り失敗や対象なしでは暗くせず、警告も出さない",
          arguments: [false, true])
    func cannotReadBrightness(hasDisplay: Bool) {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        system.failing = hasDisplay ? [.readBrightness] : []
        system.brightness = hasDisplay ? 0.5 : nil
        system.clearHistory()
        let events = EventRecorder(controller)
        controller.lidClosed()
        #expect(!system.operations.contains(.setBrightness(0)))
        #expect(system.brightnessRecord?.savedBrightness == nil)
        #expect(controller.savedBrightness == nil)
        #expect(controller.isBlocking && !controller.status.hasWarnings)
        #expect(events.events.isEmpty)
        system.failing = []
        system.brightness = 0.7
        controller.lidClosed()
        #expect(system.brightnessRecord?.savedBrightness == 0.7)
    }

    @Test("SPEC-BLK-010 SPEC-BLK-013 保存に失敗したら暗くせず、警告を出して抑止を続ける",
          arguments: [false, true])
    func saveFailureDoesNotBlock(endsBlocking: Bool) {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        system.failing = [.saveBrightnessRecord(0.5)]
        #expect(controller.requestStart(from: .cli) == .started)
        let events = EventRecorder(controller)
        system.clearHistory()
        controller.lidClosed()
        #expect(system.operations == [.readBrightness, .saveBrightnessRecord(0.5)])
        #expect(system.brightness == 0.5)
        #expect(system.brightnessRecord == nil)
        #expect(controller.isBlocking && controller.status.brightnessWarnings == [.saveFailed])
        #expect(events.events == [.warningsChanged])

        system.failing = []
        system.clearHistory()
        system.advance(by: 60)
        controller.timePassed()
        #expect(system.operations.isEmpty)
        #expect(controller.status.brightnessWarnings == [.saveFailed])
        if endsBlocking {
            controller.requestStop(from: .cli)
            #expect(!controller.isBlocking)
        } else {
            controller.lidOpened()
            #expect(controller.isBlocking)
        }
        #expect(!controller.status.hasWarnings)
        if !endsBlocking {
            controller.lidClosed()
            #expect(system.brightness == 0)
        }
    }

    @Test("SPEC-BLK-013 暗くする書き込みが失敗しても記録を残し、ディスプレイスリープや警告にしない")
    func dimWriteFailureKeepsRecord() {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        system.failing = [.setBrightness(0)]
        controller.lidClosed()
        #expect(system.brightness == 0.5)
        #expect(system.brightnessRecord?.savedBrightness == 0.5)
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
        #expect(controller.savedBrightness == 0.5)
        #expect(system.brightnessRecord?.savedBrightness == 0.5)
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
        #expect(controller.savedBrightness == 0.5)
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
        system.brightnessRecord = BrightnessRecord(savedBrightness: 0.5)
        system.brightness = 0
        system.failing = [.setBrightness(0.5)]
        let controller = makeController(system, settings: settings)
        #expect(!controller.isBlocking)
        #expect(controller.savedBrightness == 0.5)
        // 停止中の閉じた通知は、開始後の暗くし直しを有効にしない。
        controller.lidClosed()
        controller.requestStart(from: .menu)
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
        #expect(controller.savedBrightness == 0.5)
        #expect(system.brightnessRecord?.savedBrightness == 0.5)
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
        #expect(system.brightnessRecord?.savedBrightness == nil)
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
        #expect(system.operations == [.setBrightness(0.5), .removeBrightnessRecord])
        #expect(system.brightness == 0.5)
        #expect(system.brightnessRecord?.savedBrightness == nil)
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
        #expect(system.brightnessRecord?.savedBrightness == 0.5)
        #expect(controller.savedBrightness == 0.5)
        #expect(!controller.status.hasWarnings)
        system.failing = []
        system.brightness = 0.3
        system.clearHistory()
        controller.timePassed()
        #expect(system.operations.isEmpty)
        controller.lidOpened()
        #expect(system.brightness == 0.5)
        #expect(system.brightnessRecord?.savedBrightness == nil)
    }

    @Test("SPEC-BLK-013 復元後の削除に失敗したら警告し、1分ごとに削除だけを試み直す")
    func recordClearFailureRetries() {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        system.failing = [.removeBrightnessRecord]
        let events = EventRecorder(controller)
        controller.requestStop(from: .menu)
        #expect(system.brightness == 0.5)
        #expect(system.brightnessRecord?.savedBrightness == 0.5)
        #expect(controller.status.brightnessWarnings == [.deletionFailed])
        #expect(controller.misalignments.isEmpty)
        #expect(controller.savedBrightness == nil)
        #expect(events.events == [.released(.user(.menu)), .warningsChanged])

        system.brightness = 0.8
        system.clearHistory()
        controller.lidOpened()
        controller.requestStop(from: .cli)
        system.advance(by: 59)
        controller.timePassed()
        #expect(system.operations.isEmpty)
        #expect(controller.status.brightnessWarnings == [.deletionFailed])

        system.advance(by: 1)
        controller.timePassed()
        #expect(system.operations == [.removeBrightnessRecord])
        #expect(controller.status.brightnessWarnings == [.deletionFailed])
        system.failing = []
        system.advance(by: 60)
        controller.timePassed()
        #expect(system.operations == [.removeBrightnessRecord, .removeBrightnessRecord])
        #expect(system.brightness == 0.8)
        #expect(system.brightnessRecord == nil)
        #expect(!controller.status.hasWarnings)
        #expect(events.events.last == .warningsChanged)
    }

    @Test("SPEC-BLK-013 再度暗くするときは、削除待ちの記録を上書きし、新しい記録は定期的に削除しない")
    func newRecordReplacesPendingDeletion() {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        system.failing = [.removeBrightnessRecord]
        controller.lidOpened()
        #expect(controller.status.brightnessWarnings == [.deletionFailed])
        system.brightness = 0.8
        system.failing = [.saveBrightnessRecord(0.8)]
        controller.lidClosed()
        #expect(controller.status.brightnessWarnings == [.saveFailed, .deletionFailed])
        #expect(system.brightness == 0.8)
        system.failing = []
        controller.lidClosed()
        #expect(!controller.status.hasWarnings)
        #expect(system.brightness == 0)
        system.advance(by: 60)
        controller.timePassed()
        #expect(system.brightnessRecord?.savedBrightness == 0.8)
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
        #expect(system.brightnessRecord?.savedBrightness == 0.5)
        #expect(!controller.status.hasWarnings)
        system.failing = []
        controller.lidOpened()
        #expect(system.brightness == 0.5)
        #expect(system.brightnessRecord?.savedBrightness == nil)
    }

    @Test("SPEC-BLK-013 SPEC-LCY-002 解除と終了は helper の off より先に輝度を復元して記録を削除する",
          arguments: [false, true])
    func restoresBeforeHelperOff(terminates: Bool) throws {
        let system = FakeSystem()
        let controller = makeController(system, settings: settings)
        controller.requestStart(from: .menu)
        controller.lidClosed()
        system.clearHistory()
        if terminates {
            controller.terminate()
        } else {
            controller.requestStop(from: .menu)
        }
        let write = try #require(system.operations.firstIndex(of: .setBrightness(0.5)))
        let deletion = try #require(system.operations.firstIndex(of: .removeBrightnessRecord))
        let off = try #require(system.operations.firstIndex(of: .helperOff))
        #expect(write < deletion && deletion < off)
        #expect(system.brightness == 0.5)
        #expect(system.brightnessRecord?.savedBrightness == nil)
        #expect(!controller.isBlocking)
        #expect(!system.sleepDisabled)
    }
}
