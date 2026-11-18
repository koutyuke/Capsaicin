import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinIPC
import CapsaicinPlatform
import Foundation
import Testing

@MainActor
struct AppModelTests {
    @Test("SPEC-BLK-013 蓋の開閉をコントローラーへ渡し、開始時には暗くしない")
    func lidBrightness() {
        let fixture = AppFixture()
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        settings.lidCloseDisplay = .zeroBrightness
        fixture.model.changeSettings(settings)
        fixture.model.finishLaunching()
        fixture.model.requestStart(from: .menu)
        #expect(fixture.system.brightness == 0.5)
        fixture.model.lidClosed()
        #expect(fixture.system.brightness == 0)
        #expect(!fixture.model.shouldSleepDisplayOnLidClose)
        fixture.model.lidOpened()
        #expect(fixture.system.brightness == 0.5)
    }

    @Test("SPEC-BLK-011 開始・解除・ホットキーは状態と出来事を画面に渡す")
    func requests() {
        let fixture = AppFixture()
        var events: [BlockingEvent] = []
        fixture.model.onEvent = { event, _ in events.append(event) }
        fixture.model.finishLaunching()
        #expect(fixture.model.requestStart(from: .menu) == .started)
        #expect(fixture.model.status.isBlocking)
        #expect(events.contains(.started(.menu)))
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
        fixture.model.finishLaunching()
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
        fixture.model.finishLaunching()
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
        fixture.model.finishLaunching()
        let start = try IPCRequest(command: .start(.timer(#require(TimerDuration(minutes: 5)))))
        #expect(fixture.model.handle(start).outcome == .started)
        let session = fixture.model.status.session
        #expect(fixture.model.handle(IPCRequest(command: .start(nil))).outcome == .alreadyBlocking)
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
        fixture.model.finishLaunching()
        try fixture.model.requestStart(from: .menu, override: .timer(#require(TimerDuration(minutes: 1))))
        fixture.system.advance(by: 60)
        fixture.model.timePassed()
        #expect(!fixture.model.status.isBlocking)
        fixture.model.requestStart(from: .menu)
        fixture.system.powerState = PowerState(batteryLevel: 1, isOnACPower: false)
        fixture.model.powerStateChanged()
        #expect(!fixture.model.status.isBlocking)
    }

    @Test("SPEC-HLP-004 ヘルパーの許可を外した解除は画面に通知し、設定を保存し直さない")
    func helperApprovalRevocation() {
        let fixture = AppFixture()
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        #expect(fixture.model.changeSettings(settings) == .applied)
        #expect(fixture.model.requestStart(from: .menu) == .started)
        var events: [BlockingEvent] = []
        var alerts: [AppAlert] = []
        fixture.model.onEvent = { event, _ in events.append(event) }
        fixture.model.onAlert = { alerts.append($0) }
        fixture.system.isHelperInstalled = false
        fixture.system.isHelperAwaitingApproval = true
        fixture.system.closeConnection()
        fixture.system.sleepDisabled = false

        fixture.controller.helperConnectionLost(.invalid)

        #expect(!fixture.model.status.isBlocking)
        #expect(fixture.model.settings == settings)
        #expect(fixture.savedSettings == [settings])
        #expect(events == [.released(.helperApprovalRevoked)])
        #expect(alerts.isEmpty)
    }

    @Test("SPEC-CLI-001 SPEC-BLK-011 抑止中の on --for と on --until は期限を置き換え、終了コード0と新しい時刻を返す",
          arguments: ["--for", "--until"])
    func cliReplacesTime(option: String) throws {
        let fixture = AppFixture()
        fixture.system.now = Date(timeIntervalSince1970: 0)
        fixture.system.calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        fixture.model.finishLaunching()
        try fixture.model.requestStart(from: .menu, override: .timer(#require(TimerDuration(minutes: 60))))
        fixture.system.advance(by: 600)
        let command = try CLIArguments.parse(["on", option, option == "--for" ? "30m" : "4:00"])
        var events: [BlockingEvent] = []
        fixture.model.onEvent = { event, _ in events.append(event) }
        fixture.system.clearHistory()
        let response = fixture.model.handle(IPCRequest(command: command))
        #expect(response.outcome == .timeLimitReplaced)
        #expect(response.exitCode == .success)
        #expect(response.status.session?.timeLimit == TimeLimit(
            date: Date(timeIntervalSince1970: option == "--for" ? 2400 : 14400),
            source: option == "--for" ? .timer : .specifiedTime,
        ))
        #expect(response.status == fixture.model.status)
        #expect(fixture.system.operations.isEmpty)
        #expect(events == [.timeLimitReplaced(.cli)])
        #expect(!MenuHUDRouting.shouldPresent(.timeLimitReplaced(.cli)))
        let output = CLIOutput.response(response, now: fixture.system.now, timeZone: fixture.system.calendar.timeZone)
        #expect(output.exitCode == .success)
        #expect(output.standardError.isEmpty)
        #expect(output.standardOutput == "✓ Turn-off time updated\n  Turns off  "
            + (option == "--for" ? "0:40 (in 30m)" : "4:00 (in 3h 50m)")
            + "\n  Battery    turns off below 20%, except on AC power\n")
    }

    @Test("SPEC-BLK-011 SPEC-CLI-001 期限到達後の on --for は自動解除を返し、置き換えや再開をしない")
    func cliReplacementAfterExpiry() throws {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
        try fixture.model.requestStart(from: .menu, override: .timer(#require(TimerDuration(minutes: 1))))
        fixture.system.advance(by: 60)
        var events: [BlockingEvent] = []
        fixture.model.onEvent = { event, _ in events.append(event) }
        let response = try fixture.model.handle(IPCRequest(command: CLIArguments.parse(["on", "--for", "30m"])))
        #expect(response.outcome == .released)
        #expect(response.exitCode == .success)
        #expect(!response.status.isBlocking)
        #expect(events == [.released(.timeLimit(.timer))])
    }

    @Test("SPEC-BLK-002 蓋閉じの消灯は抑止中かつ実効設定が有効なときだけ要求する")
    func lidClose() {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
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

    @Test("SPEC-CLI-003 SPEC-CLI-007 輝度の保存・削除の警告を応答に含めるが失敗にはしない")
    func cliWarnings() {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        settings.lidCloseDisplay = .zeroBrightness
        fixture.model.changeSettings(settings)
        fixture.system.failing = [.saveBrightnessRecord(0.5)]
        let start = IPCRequest(command: .start(nil))
        #expect(fixture.model.handle(start).outcome == .started)
        fixture.model.lidClosed()
        let alreadyBlocking = fixture.model.handle(start)
        #expect(alreadyBlocking.outcome == .alreadyBlocking && alreadyBlocking.exitCode == .success)
        #expect(alreadyBlocking.status.brightnessWarnings == [.saveFailed])
        #expect(fixture.model.handle(IPCRequest(command: .status)).exitCode == .success)
        fixture.model.lidOpened()

        fixture.system.failing = [.removeBrightnessRecord]
        fixture.model.lidClosed()
        let released = fixture.model.handle(IPCRequest(command: .stop))
        #expect(released.outcome == .released && released.exitCode == .success)
        #expect(released.status.brightnessWarnings == [.deletionFailed])
        #expect(fixture.model.handle(IPCRequest(command: .status)).exitCode == .stopped)
    }

    @Test("SPEC-LCY-002 どの終了も停止中に戻し、HUD を出さず、利用者の終了だけ残留をダイアログで知らせる",
          arguments: [false, true], [false, true])
    func termination(isUserQuit: Bool, fails: Bool) {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        settings.lidCloseDisplay = .zeroBrightness
        fixture.model.changeSettings(settings)
        fixture.model.requestStart(from: .menu)
        fixture.model.lidClosed()
        if fails {
            fixture.system.failing = [.helperOff]
        }
        fixture.system.clearHistory()
        var events: [BlockingEvent] = []
        fixture.model.onEvent = { event, _ in events.append(event) }
        var alerts: [AppAlert] = []
        fixture.model.onAlert = { alerts.append($0) }
        fixture.model.terminate(isUserQuit: isUserQuit)
        #expect(!fixture.model.status.isBlocking)
        #expect(fixture.system.operations.prefix(4) == [
            .setBrightness(0.5), .removeBrightnessRecord, .readSleepDisabled, .helperOff,
        ])
        #expect(fixture.system.heldAssertions.isEmpty && !fixture.system.isLEDLit)
        #expect(fixture.model.status.misalignments == (fails ? [.systemSleepDisabled: .leftApplied] : [:]))
        #expect(!events.contains(where: MenuHUDRouting.shouldPresent))
        #expect(alerts == (isUserQuit && fails ? [.terminationIncomplete] : []))
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

    lazy var controller = BlockingController(
        settings: initialSettings,
        capabilities: MachineCapabilities(hasLid: true, hasInternalBattery: true),
        ports: system.ports,
    )

    lazy var model = AppModel(
        controller: controller,
        saveSettings: { [unowned self] in savedSettings.append($0) },
    )
}
