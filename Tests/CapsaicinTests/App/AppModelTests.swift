import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinIPC
import CapsaicinPlatform
import Testing

@MainActor
struct AppModelTests {
    @Test("SPEC-BLK-011 開始・解除・ホットキーは状態と出来事を画面に渡す")
    func requests() {
        let fixture = AppFixture()
        var events: [BlockingEvent] = []
        fixture.model.onEvent = { event, _ in events.append(event) }
        fixture.model.launch()
        #expect(fixture.model.requestStart(from: .menu) == .started)
        #expect(fixture.model.status.isBlocking)
        #expect(events.contains(.started(.user(.menu))))
        #expect(fixture.model.requestStop(from: .menu) == .released)
        #expect(!fixture.model.status.isBlocking)
        fixture.model.toggleByHotkey()
        #expect(fixture.model.status.isBlocking)
        fixture.model.toggleByHotkey()
        #expect(!fixture.model.status.isBlocking)
        #expect(events.contains(.released(.user(.hotkey))))
    }

    @Test("SPEC-BLK-009 設定は受理したときだけ保存し、反映失敗は通知する")
    func settings() {
        let fixture = AppFixture(displayBlocked: false)
        fixture.model.launch()
        fixture.model.requestStart(from: .menu)
        var settings = fixture.model.settings
        settings.showsHUD = false
        #expect(fixture.model.changeSettings(settings) == .applied)
        #expect(fixture.savedSettings == [settings])
        #expect(fixture.model.settings == settings)
        var alerts: [AppAlert] = []
        fixture.model.onAlert = { alerts.append($0) }
        fixture.system.failing = [.createAssertion(.preventUserIdleDisplaySleep)]
        settings.blocksDisplaySleep = true
        #expect(fixture.model.changeSettings(settings) == .reverted(failed: [.displaySleepAssertion]))
        #expect(!fixture.model.settings.blocksDisplaySleep)
        #expect(fixture.savedSettings.count == 1)
        #expect(alerts == [.settingsReverted([.displaySleepAssertion])])
    }

    @Test("SPEC-CLI-005 無効な CLI は開始・解除・状態のすべてを拒む",
          arguments: [IPCCommand.start(nil), .stop, .status])
    func disabledCLI(command: IPCCommand) {
        let fixture = AppFixture()
        fixture.model.launch()
        fixture.model.requestStart(from: .menu)
        var settings = fixture.model.settings
        settings.acceptsCLIRequests = false
        fixture.model.changeSettings(settings)
        let before = fixture.model.status
        fixture.system.clearHistory()
        let response = fixture.model.handle(IPCRequest(command: command))
        #expect(response.outcome == .cliRequestsDisabled)
        #expect(response.status == before)
        #expect(fixture.system.operations.isEmpty)
    }

    @Test("SPEC-BLK-011 CLI の結果と要求後の状態を返す")
    func cli() throws {
        let fixture = AppFixture()
        fixture.model.launch()
        let start = try IPCRequest(command: .start(.timer(#require(TimerDuration(minutes: 5)))))
        #expect(fixture.model.handle(start).outcome == .started)
        let session = fixture.model.status.session
        #expect(fixture.model.handle(start).outcome == .alreadyBlocking)
        #expect(fixture.model.status.session == session)
        #expect(fixture.model.handle(IPCRequest(command: .status)).status.isBlocking)
        #expect(fixture.model.handle(IPCRequest(command: .stop)).outcome == .released)
        #expect(fixture.model.handle(IPCRequest(command: .stop)).outcome == .alreadyStopped)
        var request = IPCRequest(command: .start(nil))
        request.version += 1
        #expect(fixture.model.handle(request).outcome == .unsupportedVersion)
        #expect(!fixture.model.status.isBlocking)
        fixture.system.powerState = PowerState(batteryLevel: 1, isOnACPower: false)
        #expect(fixture.model.handle(start).outcome == .startRejected(.batteryBelowThreshold))
    }

    @Test("SPEC-BLK-004 SPEC-BLK-006 時刻と電源の変化を Core に伝える")
    func automaticRelease() throws {
        let fixture = AppFixture()
        fixture.model.launch()
        try fixture.model.requestStart(from: .menu, override: .timer(#require(TimerDuration(minutes: 1))))
        fixture.system.advance(by: 60)
        fixture.model.timePassed()
        #expect(!fixture.model.status.isBlocking)
        fixture.model.requestStart(from: .menu)
        fixture.system.powerState = PowerState(batteryLevel: 1, isOnACPower: false)
        fixture.model.powerStateChanged()
        #expect(!fixture.model.status.isBlocking)
    }

    @Test("SPEC-BLK-002 蓋閉じの消灯は抑止中かつ実効設定が有効なときだけ要求する")
    func lidClose() {
        let fixture = AppFixture()
        fixture.model.launch()
        #expect(!fixture.model.shouldSleepDisplayOnLidClose)
        fixture.model.requestStart(from: .menu)
        #expect(!fixture.model.shouldSleepDisplayOnLidClose)
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        fixture.model.changeSettings(settings)
        #expect(fixture.model.shouldSleepDisplayOnLidClose)
        settings.lidCloseDisplay = .keepOn
        fixture.model.changeSettings(settings)
        #expect(!fixture.model.shouldSleepDisplayOnLidClose)
        settings.lidCloseDisplay = .turnOff
        fixture.model.changeSettings(settings)
        fixture.model.requestStop(from: .menu)
        #expect(!fixture.model.shouldSleepDisplayOnLidClose)
    }

    @Test("SPEC-CLI-007 解除後の残留と保存失敗も CLI の応答に含む")
    func cliWarnings() {
        let fixture = AppFixture()
        fixture.model.launch()
        fixture.model.requestStart(from: .menu)
        fixture.system.failing = [.setLEDLit(false), .saveRecord]
        let response = fixture.model.handle(IPCRequest(command: .stop))
        #expect(response.outcome == .released)
        #expect(response.status.hasWarnings)
        #expect(response.status.isRecordUnsaved)
        #expect(!response.status.isBlocking)
        fixture.system.failing = []
        let retried = fixture.model.handle(IPCRequest(command: .stop))
        #expect(retried.outcome == .alreadyStopped)
        #expect(!retried.status.hasWarnings)
    }

    @Test("SPEC-LCY-002 終了の種類を振り分け、利用者の終了だけ残留を通知する",
          arguments: [TerminationReason.userQuit, .sessionEnd, .unknown], [false, true])
    func termination(reason: TerminationReason, fails: Bool) throws {
        let fixture = AppFixture()
        fixture.model.launch()
        fixture.model.requestStart(from: .menu)
        if fails {
            fixture.system.failing = [.setLEDLit(false)]
        }
        var alerts: [AppAlert] = []
        fixture.model.onAlert = { alerts.append($0) }
        fixture.model.terminate(reason: reason)
        let record = try #require(fixture.system.storedRecord)
        #expect(!record.isRunning)
        #expect(!fixture.model.status.isBlocking)
        #expect((record.session != nil) == (reason == .sessionEnd))
        switch reason {
        case .userQuit: #expect(record.exitReason == .userQuit)
        case .sessionEnd: #expect(record.exitReason == .sessionEnd)
        case .unknown: #expect(record.exitReason == nil)
        }
        #expect(alerts == (reason == .userQuit && fails ? [.terminationIncomplete] : []))
    }
}

@MainActor
final class AppFixture {
    private let initialSettings: Settings
    let system = FakeSystem()
    var savedSettings: [Settings] = []
    init(displayBlocked: Bool = true) {
        var settings = Settings()
        settings.blocksDisplaySleep = displayBlocked
        initialSettings = settings
    }

    lazy var model = AppModel(
        controller: BlockingController(
            settings: initialSettings,
            capabilities: MachineCapabilities(hasLid: true, hasInternalBattery: true),
            ports: system.ports,
        ),
        saveSettings: { [unowned self] in savedSettings.append($0) },
    )
}
