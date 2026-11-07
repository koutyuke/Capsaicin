import CapsaicinPlatform
import OSLog

@MainActor
final class AppRuntime {
    let model: AppModel
    let openSettings: @MainActor () -> Void
    private let launchedByLaunchd: Bool
    private let registerAndStart: @MainActor (Bool) async -> LaunchAgentStatus
    private let restartStatus: () -> LaunchAgentStatus
    private let updateLaunchAtLogin: (Bool) throws -> Void
    private let startServices: @MainActor () async -> Void
    private let stopServices: @MainActor () async -> Void

    init(
        model: AppModel, launchedByLaunchd: Bool,
        registerAndStart: @escaping @MainActor (Bool) async -> LaunchAgentStatus,
        restartStatus: @escaping () -> LaunchAgentStatus,
        updateLaunchAtLogin: @escaping (Bool) throws -> Void,
        startServices: @escaping @MainActor () async -> Void,
        stopServices: @escaping @MainActor () async -> Void,
        openSettings: @escaping @MainActor () -> Void,
    ) {
        self.model = model
        self.launchedByLaunchd = launchedByLaunchd
        self.registerAndStart = registerAndStart
        self.restartStatus = restartStatus
        self.updateLaunchAtLogin = updateLaunchAtLogin
        self.startServices = startServices
        self.stopServices = stopServices
        self.openSettings = openSettings
        model.onLaunchAtLoginChange = { [weak self] in self?.updateLoginSetting($0) }
    }

    /// false なら LaunchAgent に引き渡せたので、このプロセスは後片付けせず終わる。
    func start() async -> Bool {
        if launchedByLaunchd {
            model.launchAgentStatus = restartStatus()
        } else {
            model.launchAgentStatus = await registerAndStart(model.settings.launchesAtLogin)
            if model.launchAgentStatus == .ready {
                return false
            }
        }
        model.launch()
        updateLoginSetting(model.settings.launchesAtLogin)
        await startServices()
        return true
    }

    func terminate(reason: TerminationReason) async {
        await stopServices()
        model.terminate(reason: reason)
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
