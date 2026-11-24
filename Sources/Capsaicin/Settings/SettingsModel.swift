import AppKit
import CapsaicinCore
import CapsaicinPlatform
import Observation
import OSLog

@MainActor
struct SettingsHelperActions {
    var state: () -> HelperInstallationState
    var perform: (HelperManagementOperation) async -> HelperManagementResult
    /// 削除成功は設定の保存、削除失敗は読み直し、設置成功は合わせ直しを行う。
    var completed: (HelperManagementOperation, HelperManagementResult) -> Void
    var isTranslocated: () -> Bool = { false }
    var openSystemSettings: () -> Void = {}

    static func live(registration: HelperRegistration,
                     prepareRemoval: @escaping () -> Bool,
                     completed: @escaping (HelperManagementOperation, HelperManagementResult) -> Void) -> Self
    {
        Self(state: { registration.state }, perform: { operation in
            do {
                switch operation {
                case .install: try registration.register()
                case .remove:
                    guard prepareRemoval() else {
                        return .failure(operation: operation, details: "Could not restore SleepDisabled",
                                        needsSleepDisabledReadback: false)
                    }
                    try await registration.unregister()
                }
                return .success
            } catch {
                return .failure(operation: operation, details: String(describing: error),
                                needsSleepDisabledReadback: operation == .remove)
            }
        }, completed: completed, isTranslocated: { registration.isTranslocated },
        openSystemSettings: { registration.openSystemSettings() })
    }
}

@MainActor
@Observable
final class SettingsModel {
    let app: AppModel
    private(set) var helperState: HelperInstallationState
    private(set) var isBusy = false
    @ObservationIgnored var confirm: (HelperManagementOperation) async -> Bool = { _ in false }
    @ObservationIgnored var showError: (String, String) -> Void = { _, _ in }
    private let helper: SettingsHelperActions
    private var windowIsOpen = false
    @ObservationIgnored private(set) var approvalTimer: Timer?

    init(app: AppModel, helper: SettingsHelperActions) {
        self.app = app
        self.helper = helper
        helperState = helper.state()
    }

    var sleepRows: [SettingsSleepRow] {
        SettingsSleepRow.rows(settings: app.settings, capabilities: app.capabilities, helper: helperState,
                              brightnessUnavailable: app.isBrightnessKnownUnavailable)
    }

    var lidCloseChoice: SettingsLidCloseChoice {
        SettingsLidCloseChoice(settings: app.settings)
    }

    func refreshHelper() {
        let previous = helperState
        helperState = helper.state()
        if helperState == .installed, !isBusy, previous == .requiresApproval {
            helper.completed(.install, .success)
        }
        updateApprovalTimer()
    }

    func settingsWindowDidBecomeKey() {
        windowIsOpen = true
        refreshHelper()
    }

    func settingsWindowClosed() {
        windowIsOpen = false
        approvalTimer?.invalidate()
        approvalTimer = nil
    }

    private func updateApprovalTimer() {
        guard helperState == .requiresApproval, windowIsOpen else {
            approvalTimer?.invalidate()
            approvalTimer = nil
            return
        }
        guard approvalTimer == nil else { return }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] timer in
            guard self != nil else { timer.invalidate(); return }
            MainActor.assumeIsolated { self?.refreshHelper() }
        }
        approvalTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func change<Value>(_ key: WritableKeyPath<Settings, Value>, to value: Value) {
        var settings = app.settings
        settings[keyPath: key] = value
        change(settings)
    }

    private func change(_ settings: Settings) {
        if case .reverted = app.changeSettings(settings) {
            showSettingsReverted()
        }
    }

    func showSettingsReverted() {
        showError(SettingsSection.helper.text("error.settingRollback.title"),
                  SettingsSection.helper.text("error.settingRollback.message"))
    }

    func changeSleep(_ row: SettingsSleepRow, to value: Bool) async {
        guard let setting = row.setting, !isBusy else { return }
        refreshHelper()
        let savedValue = value != row.inverted
        if setting == \.blocksManualSleep, savedValue, helperState != .installed {
            return
        }
        change(setting, to: savedValue)
    }

    func changeLidClose(to choice: SettingsLidCloseChoice) async {
        guard !isBusy else { return }
        refreshHelper()
        guard choice == .sleep || helperState == .installed else { return }

        var settings = app.settings
        settings.blocksManualSleep = choice != .sleep
        switch choice {
        case .sleep: break
        case .turnOff: settings.lidCloseDisplay = .turnOff
        case .zeroBrightness: settings.lidCloseDisplay = .zeroBrightness
        case .keepOn: settings.lidCloseDisplay = .keepOn
        }
        change(settings)
    }

    func openHelperSystemSettings() {
        helper.openSystemSettings()
    }

    func manage(_ operation: HelperManagementOperation) async {
        guard !isBusy else { return }
        isBusy = true
        defer {
            isBusy = false
            refreshHelper()
        }
        helperState = helper.state()
        guard operation != .install || canInstall(), await confirm(operation) else { return }
        if operation == .install {
            helperState = helper.state()
            guard canInstall() else { return }
        }
        let result = await helper.perform(operation)
        finishManagement(operation, result)
    }

    private func finishManagement(_ operation: HelperManagementOperation, _ result: HelperManagementResult) {
        switch result {
        case .success:
            helperState = helper.state()
            if operation == .remove || helperState == .installed {
                helper.completed(operation, result)
            }
        case .cancelled: break
        case let .failure(failedOperation, details, _):
            helper.completed(operation, result)
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Capsaicin", category: "Helper")
                .error("Helper management failed: \(details, privacy: .private)")
            // 理由は分けて伝えず、どの失敗でも利用者が試せるやり直し方を案内する。
            showHelperError(Self.operationKey(failedOperation), message: "helperRetry")
        }
    }

    private func canInstall() -> Bool {
        guard helperState == .notInstalled else { return false }
        guard !helper.isTranslocated() else {
            showHelperError("helperTranslocated")
            return false
        }
        return true
    }

    private func showHelperError(_ key: String, message: String? = nil) {
        showError(SettingsSection.helper.text("error." + key + ".title"),
                  SettingsSection.helper.text("error." + (message ?? key) + ".message"))
    }

    static func operationKey(_ operation: HelperManagementOperation) -> String {
        switch operation {
        case .install: "helperInstall"
        case .remove: "helperRemove"
        }
    }
}
