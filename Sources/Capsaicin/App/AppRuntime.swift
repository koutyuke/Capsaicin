import OSLog

@MainActor
final class AppRuntime {
    let model: AppModel
    let openSettings: @MainActor () -> Void
    private let updateLaunchAtLogin: (Bool) throws -> Void
    private let reregisterHelper: @MainActor () async -> Void
    private let startServices: @MainActor () async -> Void
    private let stopServices: @MainActor () async -> Void

    init(
        model: AppModel,
        updateLaunchAtLogin: @escaping (Bool) throws -> Void,
        reregisterHelper: @escaping @MainActor () async -> Void,
        startServices: @escaping @MainActor () async -> Void,
        stopServices: @escaping @MainActor () async -> Void,
        openSettings: @escaping @MainActor () -> Void,
    ) {
        self.model = model
        self.updateLaunchAtLogin = updateLaunchAtLogin
        self.reregisterHelper = reregisterHelper
        self.startServices = startServices
        self.stopServices = stopServices
        self.openSettings = openSettings
        model.onLaunchAtLoginChange = { [weak self] in self?.updateLoginSetting($0) }
    }

    func start() async {
        model.restoreBrightnessAtLaunch()
        await reregisterHelper()
        model.finishLaunching()
        updateLoginSetting(model.settings.launchesAtLogin)
        await startServices()
    }

    func terminate(isUserQuit: Bool) async {
        await stopServices()
        model.terminate(isUserQuit: isUserQuit)
    }

    private func updateLoginSetting(_ enabled: Bool) {
        do {
            try updateLaunchAtLogin(enabled)
        } catch {
            Self.log(error)
        }
    }

    static func log(_ error: any Error) {
        Logger(subsystem: "io.github.koutyuke.capsaicin", category: "App")
            .error("アプリの処理に失敗: \(String(describing: error), privacy: .public)")
    }
}
