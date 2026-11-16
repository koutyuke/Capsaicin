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
        let brightness = DisplayServicesBrightness()
        let controller = try BlockingController(
            settings: store.load(), capabilities: PowerMachineCapabilities.detect(),
            ports: .init(
                assertions: PowerAssertions(), helper: helper,
                led: led, brightness: brightness, power: power, bootTime: BootTimeProvider(),
                records: FileResumeRecordStore(bundleID: isDebug
                    ? "io.github.koutyuke.capsaicin.debug" : "io.github.koutyuke.capsaicin"),
                time: SystemTime(),
            ),
        )
        let model = AppModel(controller: controller, saveSettings: { store.save($0) },
                             updater: UpdateModel(bundle: bundle))
        model.onAlert = showAlert
        let settings = SettingsModel(app: model, helper: .live(
            helper: helper, installer: HelperInstaller(),
            restoreSleep: model.resetsSleepDisabledOnHelperRemoval,
            completed: model.helperManagementCompleted,
        ))
        let agent = try LaunchAgent(executableURL: executableURL(in: bundle), isDebug: isDebug)
        let services = AppServices(
            model: model, settings: settings, power: power, led: led, lid: LidStateMonitor(),
            virtualKeyboard: VirtualKeyboardMonitor(), display: DisplaySleep(),
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
            openSettings: { services.openSettings() },
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
        panel.messageText = Bundle.main.localizedString(
            forKey: "alert.terminationIncomplete.title", value: nil, table: "App",
        )
        panel.informativeText = Bundle.main.localizedString(
            forKey: "alert.terminationIncomplete.message", value: nil, table: "App",
        )
        panel.addButton(withTitle: Bundle.main.localizedString(
            forKey: "alert.terminationIncomplete.button", value: nil, table: "App",
        ))
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
    let virtualKeyboard: VirtualKeyboardMonitor
    let display: DisplaySleep
    let server: IPCServer
    private let menuBar: MenuBarController
    private let hud: HUDPresenter
    private var settingsWindow: SettingsWindowController?
    private var minuteTimer: Timer?
    private var releaseTimer: Timer?
    private var wakeObservers: [any NSObjectProtocol] = []
    private var screenLock: ScreenLockObserver?
    private var settingsCloseObserver: any NSObjectProtocol?

    init(model: AppModel, settings: SettingsModel, power: PowerStateMonitor, led: CapsLockLEDController,
         lid: LidStateMonitor, virtualKeyboard: VirtualKeyboardMonitor, display: DisplaySleep, server: IPCServer,
         quit: @escaping () -> Void)
    {
        self.model = model
        self.settings = settings
        self.power = power
        self.led = led
        self.lid = lid
        self.virtualKeyboard = virtualKeyboard
        self.display = display
        self.server = server
        menuBar = MenuBarController(settings: settings, isOnACPower: { power.powerState.isOnACPower })
        hud = HUDPresenter(isEnabled: { model.settings.showsHUD })
        menuBar.openSettings = { [weak self] in self?.openSettings() }
        menuBar.quit = quit
    }

    private func prepareSettingsWindow() {
        settingsWindow = SettingsWindowController(
            model: settings, hotkey: .live(toggle: { [weak model] in model?.toggleByHotkey() }), quit: menuBar.quit,
        )
        settingsCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: settingsWindow?.window, queue: .main,
        ) { [weak model] _ in
            MainActor.assumeIsolated {
                guard let model else { return }
                model.updater.updateInstallationConditions(
                    isBlocking: model.status.isBlocking,
                    settingsWindowIsOpen: false,
                )
            }
        }
        // メニューからの変更でも、確認・エラーが必要なときだけ既存のシートの親を前面に出す。
        let confirm = settings.confirm
        settings.confirm = { [weak self] operation, fromSetting in
            self?.openSettings()
            return await confirm(operation, fromSetting)
        }
        let showError = settings.showError
        settings.showError = { [weak self] title, message in
            self?.openSettings()
            showError(title, message)
        }
    }

    func start() async {
        prepareSettingsWindow()
        model.onStatusChange = { [weak self] in self?.refresh($0) }
        model.onEvent = { [weak self] event, previous in
            guard let self else { return }
            MenuHUDRouting.deliver(event, status: model.status, previousSession: previous, to: hud)
        }
        menuBar.start()
        refresh(model.status)
        model.updater.start()
        minuteTimer = Timer(timeInterval: 60, repeats: true) { [weak model] _ in
            MainActor.assumeIsolated { model?.timePassed() }
        }
        if let minuteTimer {
            RunLoop.main.add(minuteTimer, forMode: .common)
        }
        do { try power.start { [weak model] _ in model?.powerStateChanged() } }
        catch { AppRuntime.log(error) }
        do {
            try lid.start(onClose: { [weak self] in
                guard let self else { return }
                model.lidClosed()
                guard model.shouldSleepDisplayOnLidClose else { return }
                Task {
                    do { try await self.display.sleepDisplay() }
                    catch { AppRuntime.log(error) }
                }
            }, onOpen: { [weak model] in model?.lidOpened() })
        } catch { AppRuntime.log(error) }
        led.onReapplyFailure = { AppRuntime.log($0) }
        // 画面のスリープ、スクリーンセーバー、画面のロックでも OS が LED を "Auto" に戻すので、それぞれで書き直す。
        wakeObservers = [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification].map { name in
            NSWorkspace.shared.notificationCenter
                .addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.systemStateChanged() }
                }
        }
        screenLock = ScreenLockObserver { [weak self] in
            // 画面のスリープの直後にロックが始まることがある。眠っている間は OS が LED を消すので点けず、画面の復帰で点け直す。
            guard CGDisplayIsAsleep(CGMainDisplayID()) == 0 else { return }
            self?.systemStateChanged()
        }
        screenLock?.start()
        virtualKeyboard.onStateChange = { [weak self] in
            self?.model.hasVirtualKeyboard = $0
            self?.menuBar.refresh()
        }
        virtualKeyboard.start()
        model.hasVirtualKeyboard = virtualKeyboard.state
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
        if let settingsCloseObserver {
            NotificationCenter.default.removeObserver(settingsCloseObserver)
            self.settingsCloseObserver = nil
        }
        settingsWindow?.close()
        settingsWindow = nil
        wakeObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        wakeObservers = []
        screenLock?.stop()
        screenLock = nil
        power.stop()
        lid.stop()
        virtualKeyboard.stop()
        led.stopMonitoring()
        await server.stop()
    }

    func openSettings() {
        settingsWindow?.open()
        model.updater.updateInstallationConditions(isBlocking: model.status.isBlocking,
                                                   settingsWindowIsOpen: settingsWindow?.window?.isVisible == true)
    }

    private func systemStateChanged() {
        model.timePassed()
        do { try led.reapply() }
        catch { AppRuntime.log(error) }
    }

    private func refresh(_ status: BlockingStatus) {
        model.updater.updateInstallationConditions(isBlocking: status.isBlocking,
                                                   settingsWindowIsOpen: settingsWindow?.window?.isVisible == true)
        scheduleRelease(status)
        menuBar.refresh()
        let policy: NSApplication.ActivationPolicy = model.settings.showsDockIcon ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if let settingsWindow, settingsWindow.window?.isVisible == true {
            // 方針の切り替えに伴う非アクティブ化を処理した次のメインキューで、表示中の設定画面を前面に戻す。
            DispatchQueue.main.async { settingsWindow.bringToFront() }
        }
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
