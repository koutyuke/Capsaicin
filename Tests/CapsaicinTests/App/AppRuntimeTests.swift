import CapsaicinCore
import Testing

@MainActor
struct AppRuntimeTests {
    @Test("SPEC-LCY-001 SPEC-LCY-006 SPEC-HLP-007 輝度の復元、ヘルパーの登録し直し、停止中への整合、ログイン時の起動設定、サービスの順に起動する",
          arguments: [false, true])
    func startupOrder(loginSetting: Bool) async {
        let fixture = RuntimeFixture(loginSetting: loginSetting)
        let system = fixture.app.system
        system.brightnessRecord = BrightnessRecord(savedBrightness: 0.75)
        system.brightness = 0
        fixture.reregister = { [unowned fixture] in
            #expect(system.operations == [.readBrightness, .setBrightness(0.75), .removeBrightnessRecord])
            #expect(system.brightness == 0.75)
            #expect(fixture.updates.isEmpty)
        }
        await fixture.runtime.start()
        #expect(fixture.calls == ["helper", "update", "start"])
        #expect(fixture.updates == [loginSetting])
        #expect(!fixture.app.model.status.isBlocking)
        var settings = fixture.app.model.settings
        settings.launchesAtLogin.toggle()
        fixture.app.model.changeSettings(settings)
        #expect(fixture.updates == [loginSetting, !loginSetting])
    }

    @Test("SPEC-HLP-001 SPEC-LCY-002 終了時は承認待ちのタイマーを止め、抑止を解除する")
    func stopsApprovalPollingOnQuit() async {
        let fixture = RuntimeFixture()
        await fixture.runtime.start()
        fixture.app.model.requestStart(from: .menu)
        let settings = SettingsModel(app: fixture.app.model, helper: .init(
            state: { .requiresApproval }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
        fixture.stopSettings = {
            #expect(fixture.app.model.status.isBlocking)
            settings.settingsWindowClosed()
        }
        settings.settingsWindowDidBecomeKey()
        #expect(settings.approvalTimer?.isValid == true)
        await fixture.runtime.terminate(isUserQuit: true)
        #expect(fixture.calls.last == "stop")
        #expect(!fixture.app.model.status.isBlocking)
        #expect(settings.lidCloseChoice == .sleep && settings.approvalTimer == nil)
        #expect(fixture.app.savedSettings.isEmpty)
    }
}

@MainActor
private final class RuntimeFixture {
    let app = AppFixture()
    let loginSetting: Bool
    var calls: [String] = []
    var updates: [Bool] = []
    var reregister: () -> Void = {}
    var stopSettings: () -> Void = {}

    init(loginSetting: Bool = true) {
        self.loginSetting = loginSetting
        var settings = app.model.settings
        settings.launchesAtLogin = loginSetting
        app.model.changeSettings(settings)
        app.savedSettings = []
    }

    lazy var runtime = AppRuntime(
        model: app.model,
        updateLaunchAtLogin: { [unowned self] value in
            #expect(app.system.operations.last == .setLEDLit(false))
            calls.append("update")
            updates.append(value)
        },
        reregisterHelper: { [unowned self] in await reregisterHelper() },
        startServices: { [unowned self] in
            #expect(updates == [loginSetting])
            calls.append("start")
        },
        stopServices: { [unowned self] in
            stopSettings()
            calls.append("stop")
        },
        openSettings: {},
    )

    private func reregisterHelper() async {
        await Task.yield()
        reregister()
        calls.append("helper")
    }
}
