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
        #expect(fixture.calls == ["register", "update", "start"])
        #expect(fixture.app.system.storedRecord?.isRunning == true)
    }

    @Test("SPEC-LCY-006 launch、RunAtLoad、CLI の順に起動し、停止後に終了記録を保存する")
    func managedLifecycle() async {
        let fixture = RuntimeFixture(launchedByLaunchd: true)
        #expect(await fixture.runtime.start())
        #expect(fixture.app.model.willRestartAfterCrash)
        #expect(fixture.calls == ["update", "start"])
        var settings = fixture.app.model.settings
        settings.launchesAtLogin = false
        fixture.app.model.changeSettings(settings)
        #expect(fixture.updates == [true, false])
        await fixture.runtime.terminate(reason: .userQuit)
        #expect(fixture.calls.last == "stop")
        #expect(fixture.app.system.storedRecord?.isRunning == false)
    }
}

@MainActor
private final class RuntimeFixture {
    let app = AppFixture()
    let launchedByLaunchd: Bool
    let registration: LaunchAgentStatus
    var calls: [String] = []
    var updates: [Bool] = []

    init(launchedByLaunchd: Bool, registration: LaunchAgentStatus = .ready) {
        self.launchedByLaunchd = launchedByLaunchd
        self.registration = registration
    }

    lazy var runtime = AppRuntime(
        model: app.model,
        launchedByLaunchd: launchedByLaunchd,
        registerAndStart: { [unowned self] _ in calls.append("register"); return registration },
        restartStatus: { .ready },
        updateLaunchAtLogin: { [unowned self] value in
            #expect(app.system.storedRecord?.isRunning == true)
            calls.append("update")
            updates.append(value)
        },
        startServices: { [unowned self] in
            #expect(updates == [true])
            calls.append("start")
        },
        stopServices: { [unowned self] in
            #expect(app.system.storedRecord?.isRunning == true)
            calls.append("stop")
        },
    )
}
