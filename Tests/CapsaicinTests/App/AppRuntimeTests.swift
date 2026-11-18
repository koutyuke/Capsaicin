import CapsaicinPlatform
import Testing

@MainActor
struct AppRuntimeTests {
    @Test("SPEC-LCY-005 引き渡しに成功した直接起動は Core と CLI を起動しない")
    func handoff() async {
        let fixture = RuntimeFixture(launchedByLaunchd: false, registration: .ready)
        #expect(await !fixture.runtime.start())
        #expect(fixture.calls == ["register"])
        #expect(fixture.app.system.operations.isEmpty)
    }

    @Test("SPEC-LCY-005 登録・起動に失敗したらそのまま動き、再起動されないことを示す",
          arguments: [LaunchAgentStatus.registrationFailed, .launchFailed, .disabled, .unavailable])
    func fallback(status: LaunchAgentStatus) async {
        let fixture = RuntimeFixture(launchedByLaunchd: false, registration: status)
        #expect(await fixture.runtime.start())
        #expect(!fixture.app.model.willRestartAfterCrash)
        #expect(fixture.app.model.launchAgentStatus == status)
        #expect(fixture.calls == ["register", "helper", "update", "start"])
        #expect(fixture.app.system.storedRecord?.isRunning == true)
    }

    @Test("SPEC-HLP-007 SPEC-LCY-006 ヘルパーの登録し直しを待ってから Core、mainApp の整合、CLI の順に起動する")
    func managedLifecycle() async {
        let fixture = RuntimeFixture(launchedByLaunchd: true)
        #expect(await fixture.runtime.start())
        #expect(fixture.app.model.willRestartAfterCrash)
        #expect(fixture.calls == ["helper", "update", "start"])
        var settings = fixture.app.model.settings
        settings.launchesAtLogin = false
        fixture.app.model.changeSettings(settings)
        #expect(fixture.updates == [true, false])
        await fixture.runtime.terminate(reason: .userQuit)
        #expect(fixture.calls.last == "stop")
        #expect(fixture.app.system.storedRecord?.isRunning == false)
    }

    @Test("SPEC-LCY-001 SPEC-LCY-005 起動時は保存したログイン設定を使い、agent 自身は登録し直さない",
          arguments: [false, true], [LaunchAgentStatus.ready, .disabled])
    func startupLoginSetting(enabled: Bool, status: LaunchAgentStatus) async {
        let fixture = RuntimeFixture(launchedByLaunchd: true, restartStatus: status, loginSetting: enabled)
        #expect(await fixture.runtime.start())
        #expect(fixture.calls == ["helper", "update", "start"])
        #expect(fixture.updates == [enabled])
        #expect(fixture.app.model.launchAgentStatus == status)
    }

    @Test("SPEC-HLP-001 SPEC-LCY-002 終了時に承認待ちの選択とタイマーを捨て、設定も再開用の記録も変えない")
    func discardsApprovalOnQuit() async {
        let fixture = RuntimeFixture(launchedByLaunchd: true)
        #expect(await fixture.runtime.start())
        let settings = SettingsModel(app: fixture.app.model, helper: .init(
            state: { .requiresApproval }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
        settings.confirm = { _, _ in true }
        fixture.stopSettings = { settings.settingsWindowClosed() }
        let record = fixture.app.system.storedRecord
        await settings.changeLidClose(to: .keepOn)
        #expect(settings.pendingManual && settings.approvalTimer != nil)
        #expect(fixture.app.system.storedRecord == record)
        await fixture.runtime.terminate(reason: .userQuit)
        #expect(!settings.pendingManual && settings.lidCloseChoice == .sleep && settings.approvalTimer == nil)
        #expect(fixture.app.savedSettings.isEmpty)
    }
}

@MainActor
private final class RuntimeFixture {
    let app = AppFixture()
    let launchedByLaunchd: Bool
    let registration: LaunchAgentStatus
    let restartStatus: LaunchAgentStatus
    let loginSetting: Bool
    var calls: [String] = []
    var updates: [Bool] = []
    var stopSettings: () -> Void = {}

    init(launchedByLaunchd: Bool, registration: LaunchAgentStatus = .ready,
         restartStatus: LaunchAgentStatus = .ready, loginSetting: Bool = true)
    {
        self.launchedByLaunchd = launchedByLaunchd
        self.registration = registration
        self.restartStatus = restartStatus
        self.loginSetting = loginSetting
        var settings = app.model.settings
        settings.launchesAtLogin = loginSetting
        app.model.changeSettings(settings)
        app.savedSettings = []
    }

    lazy var runtime = AppRuntime(
        model: app.model,
        launchedByLaunchd: launchedByLaunchd,
        registerAndStart: { [unowned self] in calls.append("register"); return registration },
        restartStatus: { [unowned self] in restartStatus },
        updateLaunchAtLogin: { [unowned self] value in
            #expect(app.system.storedRecord?.isRunning == true)
            calls.append("update")
            updates.append(value)
        },
        reregisterHelper: { [unowned self] in await reregisterHelper() },
        startServices: { [unowned self] in
            #expect(updates == [loginSetting])
            calls.append("start")
        },
        stopServices: { [unowned self] in
            #expect(app.system.storedRecord?.isRunning == true)
            stopSettings()
            calls.append("stop")
        },
        openSettings: {},
    )

    private func reregisterHelper() async {
        #expect(app.system.operations.isEmpty)
        #expect(app.system.storedRecord == nil)
        await Task.yield()
        #expect(app.system.operations.isEmpty)
        #expect(updates.isEmpty)
        calls.append("helper")
    }
}
