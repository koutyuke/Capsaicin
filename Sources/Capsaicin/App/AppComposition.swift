import AppKit
import CapsaicinCore
import CapsaicinIPC
import CapsaicinPlatform

@MainActor
enum AppComposition {
    /// 実ポートを作る唯一の入口。テストとモデルの初期化からは呼ばない。
    static func make(quit: @escaping () -> Void) throws -> AppRuntime {
        #if DEBUG
            let isDebug = true
        #else
            let isDebug = false
        #endif
        let bundle = Bundle.main
        let store = UserDefaultsSettingsStore(defaults: .standard)
        let power = PowerStateMonitor()
        let led = CapsLockLEDController()
        let helper = HelperSleepController()
        let controller = try BlockingController(
            settings: store.load(), capabilities: PowerMachineCapabilities.detect(),
            ports: .init(
                assertions: PowerAssertions(), lidSleep: LidSleepControl(), helper: helper,
                led: led, power: power, bootTime: BootTimeProvider(),
                records: FileResumeRecordStore(bundleID: isDebug
                    ? "io.github.koutyuke.capsaicin.debug" : "io.github.koutyuke.capsaicin"),
                time: SystemTime(),
            ),
        )
        let model = AppModel(controller: controller, saveSettings: { store.save($0) })
        model.onAlert = showAlert
        let settings = SettingsModel(app: model, helper: .live(
            helper: helper, installer: HelperInstaller(),
            restoreSleep: model.resetsSleepDisabledOnHelperRemoval,
            completed: model.helperManagementCompleted,
        ))
        let agent = try LaunchAgent(executableURL: executableURL(in: bundle), isDebug: isDebug)
        let services = AppServices(
            model: model, settings: settings, power: power, led: led, lid: LidStateMonitor(),
            karabiner: KarabinerElementsMonitor(), display: DisplaySleep(),
            server: IPCServer(endpoint: IPCEndpoint(namespace: isDebug ? .debug : .release)) { model.handle($0) },
            quit: quit,
        )
        return AppRuntime(
            model: model,
            launchedByLaunchd: agent.wasLaunchedByLaunchd(environment: ProcessInfo.processInfo.environment),
            registerAndStart: { await agent.registerAndStart(launchAtLogin: $0) },
            restartStatus: { agent.restartStatus() },
            updateLaunchAtLogin: { try agent.updateLaunchAtLogin($0) },
            startServices: { await services.start() }, stopServices: { await services.stop() },
        )
    }

    private static func executableURL(in bundle: Bundle) throws -> URL {
        guard let url = bundle.executableURL else { throw CocoaError(.fileNoSuchFile) }
        return url
    }

    private static func showAlert(_ alert: AppAlert) {
        guard alert == .terminationIncomplete else { return }
        let panel = NSAlert()
        panel.alertStyle = .informational
        panel.messageText = "一部の制御を元に戻せませんでした"
        panel.informativeText = "スリープまたは LED の制御が残っています。次に Capsaicin を起動したときに戻し直します。"
        panel.addButton(withTitle: "OK")
        panel.runModal()
    }
}

@MainActor
private struct SystemTime: TimeProviding {
    var now: Date {
        Date()
    }

    var calendar: Calendar {
        .current
    }
}

@MainActor
private final class AppServices {
    let model: AppModel
    let settings: SettingsModel
    let power: PowerStateMonitor
    let led: CapsLockLEDController
    let lid: LidStateMonitor
    let karabiner: KarabinerElementsMonitor
    let display: DisplaySleep
    let server: IPCServer
    private let menuBar: MenuBarController
    private let hud: HUDPresenter
    private var settingsWindow: SettingsWindowController?
    private var minuteTimer: Timer?
    private var releaseTimer: Timer?
    private var wakeObserver: any NSObjectProtocol?

    init(model: AppModel, settings: SettingsModel, power: PowerStateMonitor, led: CapsLockLEDController,
         lid: LidStateMonitor, karabiner: KarabinerElementsMonitor, display: DisplaySleep, server: IPCServer,
         quit: @escaping () -> Void)
    {
        self.model = model
        self.settings = settings
        self.power = power
        self.led = led
        self.lid = lid
        self.karabiner = karabiner
        self.display = display
        self.server = server
        menuBar = MenuBarController(model: model, isOnACPower: { power.powerState.isOnACPower })
        hud = HUDPresenter(isEnabled: { model.settings.showsHUD })
        menuBar.openSettings = { [weak self] in self?.settingsWindow?.open() }
        menuBar.quit = quit
    }

    func start() async {
        settingsWindow = SettingsWindowController(
            model: settings, hotkey: .live(toggle: { [weak model] in model?.toggleByHotkey() }),
        )
        model.onStatusChange = { [weak self] in
            self?.scheduleRelease($0)
            self?.menuBar.refresh()
        }
        model.onEvent = { [weak self] event, previous in
            guard let self else { return }
            MenuHUDRouting.deliver(event, status: model.status, previousSession: previous, to: hud)
        }
        menuBar.start()
        scheduleRelease(model.status)
        minuteTimer = Timer(timeInterval: 60, repeats: true) { [weak model] _ in
            MainActor.assumeIsolated { model?.timePassed() }
        }
        if let minuteTimer {
            RunLoop.main.add(minuteTimer, forMode: .common)
        }
        do { try power.start { [weak model] _ in model?.powerStateChanged() } }
        catch { AppRuntime.log(error) }
        do {
            try lid.start { [weak self] in
                guard let self, model.shouldSleepDisplayOnLidClose else { return }
                Task {
                    do { try await self.display.sleepDisplay() }
                    catch { AppRuntime.log(error) }
                }
            }
        } catch { AppRuntime.log(error) }
        led.onReapplyFailure = { AppRuntime.log($0) }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.model.timePassed()
                do { try self.led.systemDidWake() }
                catch { AppRuntime.log(error) }
            }
        }
        karabiner.onStateChange = { [weak self] in
            self?.model.isKarabinerRunning = $0
            self?.menuBar.refresh()
        }
        karabiner.start()
        model.isKarabinerRunning = karabiner.state
        menuBar.refresh()
        do { try await server.start() }
        catch { AppRuntime.log(error) }
    }

    func stop() async {
        minuteTimer?.invalidate()
        releaseTimer?.invalidate()
        model.onStatusChange = nil
        model.onEvent = nil
        menuBar.stop()
        HotkeyController.stop()
        settingsWindow?.close()
        settingsWindow = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        power.stop()
        lid.stop()
        karabiner.stop()
        led.stopMonitoring()
        await server.stop()
    }

    private func scheduleRelease(_ status: BlockingStatus) {
        releaseTimer?.invalidate()
        guard let date = status.session?.timeLimit?.date else { return }
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak model] _ in
            Task { @MainActor in model?.timePassed() }
        }
        releaseTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
