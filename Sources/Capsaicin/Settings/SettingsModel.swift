import AppKit
import CapsaicinCore
import CapsaicinPlatform
import Observation
import OSLog

@MainActor
struct SettingsHelperActions {
    var state: () -> HelperInstallationState
    var perform: (HelperManagementOperation) async -> HelperManagementResult
    /// 削除成功は所有の解放→設定の保存、削除失敗は読み直し、設置・修復成功は合わせ直しを行う。
    var completed: (HelperManagementOperation, HelperManagementResult) -> Void

    static func live(helper: HelperSleepController, installer: HelperInstaller, bundle: Bundle = .main,
                     restoreSleep: @escaping () -> Bool,
                     completed: @escaping (HelperManagementOperation, HelperManagementResult) -> Void) -> Self
    {
        Self(state: { helper.installationState }, perform: { operation in
            let path = bundle.bundleURL.appendingPathComponent("Contents/Helpers/capsaicin-helper").path
            switch operation {
            case .install: return await installer.install(bundledHelperPath: path, uid: getuid())
            case .repair: return await installer.repair(bundledHelperPath: path, uid: getuid())
            case .remove: return await installer.remove(restoreSleep: restoreSleep())
            }
        }, completed: completed)
    }
}

@MainActor
@Observable
final class SettingsModel {
    let app: AppModel
    private(set) var helperState: HelperInstallationState
    private(set) var pendingManual = false
    private(set) var isBusy = false
    @ObservationIgnored var confirm: (HelperManagementOperation, Bool) async -> Bool = { _, _ in false }
    @ObservationIgnored var showError: (String, String) -> Void = { _, _ in }
    private let helper: SettingsHelperActions

    init(app: AppModel, helper: SettingsHelperActions) {
        self.app = app
        self.helper = helper
        helperState = helper.state()
    }

    var sleepRows: [SettingsSleepRow] {
        SettingsSleepRow.rows(settings: app.settings, capabilities: app.capabilities, helper: helperState)
    }

    func refreshHelper() {
        helperState = helper.state()
    }

    func change<Value>(_ key: WritableKeyPath<Settings, Value>, to value: Value) {
        var settings = app.settings
        settings[keyPath: key] = value
        if case .reverted = app.changeSettings(settings) {
            showSettingsReverted()
        }
    }

    func showSettingsReverted() {
        showError(SettingsSection.helper.text("error.settingRollback.title"),
                  SettingsSection.helper.text("error.settingRollback.message"))
    }

    func changeSleep(_ row: SettingsSleepRow, to value: Bool) async {
        guard let setting = row.setting, row.isEnabled, !isBusy else { return }
        refreshHelper()
        if setting == \.blocksManualSleep, value, helperState != .installed {
            await manage(helperState == .partial ? .repair : .install, fromSetting: true)
        } else {
            change(setting, to: value)
        }
    }

    func manage(_ operation: HelperManagementOperation, fromSetting: Bool = false) async {
        guard !isBusy else { return }
        isBusy = true
        pendingManual = fromSetting
        defer {
            pendingManual = false
            isBusy = false
            refreshHelper()
        }
        guard await confirm(operation, fromSetting) else { return }
        let result = await helper.perform(operation)
        helper.completed(operation, result)
        switch result {
        case .success:
            refreshHelper()
            if fromSetting {
                change(\.blocksManualSleep, to: true)
            }
        case .cancelled: break
        case let .failure(failedOperation, details, _):
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Capsaicin", category: "Helper")
                .error("Helper management failed: \(details, privacy: .private)")
            let key = Self.operationKey(failedOperation)
            showError(SettingsSection.helper.text("error." + key + ".title"),
                      SettingsSection.helper.text("error." + key + ".message"))
        }
    }

    static func operationKey(_ operation: HelperManagementOperation) -> String {
        switch operation {
        case .install: "helperInstall"
        case .repair: "helperRepair"
        case .remove: "helperRemove"
        }
    }
}
