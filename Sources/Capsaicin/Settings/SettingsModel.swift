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
    // 許可されるまで保存値と再開用の記録を変えないため、選択は画面側だけで持つ。
    private(set) var pendingManual = false
    private var pendingLidClose: SettingsLidCloseChoice?
    private(set) var isBusy = false
    @ObservationIgnored var confirm: (HelperManagementOperation, Bool) async -> Bool = { _, _ in false }
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
        pendingLidClose ?? SettingsLidCloseChoice(settings: app.settings)
    }

    var displayedSleepRows: [SettingsSleepRow] {
        var settings = app.settings
        if pendingManual {
            settings.blocksManualSleep = true
            if let pendingLidClose, let display = LidCloseDisplay(rawValue: pendingLidClose.rawValue) {
                settings.lidCloseDisplay = display
            }
        }
        return SettingsSleepRow.rows(settings: settings, capabilities: app.capabilities, helper: helperState,
                                     brightnessUnavailable: app.isBrightnessKnownUnavailable,
                                     awaitingApproval: pendingManual)
    }

    func refreshHelper() {
        let previous = helperState
        helperState = helper.state()
        if helperState == .installed, !isBusy, previous == .requiresApproval || pendingManual {
            completeInstallation()
        }
        updateApprovalTimer()
    }

    func settingsWindowDidBecomeKey() {
        windowIsOpen = true
        refreshHelper()
    }

    func settingsWindowClosed() {
        windowIsOpen = false
        discardPendingSelection()
        approvalTimer?.invalidate()
        approvalTimer = nil
    }

    private func discardPendingSelection() {
        pendingManual = false
        pendingLidClose = nil
    }

    private func completeInstallation() {
        let selection = pendingLidClose
        let hadPendingSelection = pendingManual
        discardPendingSelection()
        if hadPendingSelection {
            if let selection {
                saveLidClose(selection)
            } else {
                change(\.blocksManualSleep, to: true)
            }
        }
        helper.completed(.install, .success)
    }

    private func updateApprovalTimer() {
        guard helperState == .requiresApproval, windowIsOpen || pendingManual else {
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
        if setting == \.blocksManualSleep {
            discardPendingSelection()
        }
        refreshHelper()
        if setting == \.blocksManualSleep, value, helperState != .installed {
            await manage(.install, fromSetting: true)
        } else {
            change(setting, to: value != row.inverted)
        }
    }

    func changeLidClose(to choice: SettingsLidCloseChoice) async {
        guard !isBusy else { return }
        discardPendingSelection()
        refreshHelper()
        if choice != .sleep, helperState != .installed {
            await manage(.install, fromSetting: true, lidClose: choice)
        } else {
            saveLidClose(choice)
        }
    }

    private func saveLidClose(_ choice: SettingsLidCloseChoice) {
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

    func manage(_ operation: HelperManagementOperation, fromSetting: Bool = false,
                lidClose: SettingsLidCloseChoice? = nil) async
    {
        guard !isBusy else { return }
        isBusy = true
        if fromSetting {
            pendingManual = true
            pendingLidClose = lidClose
        }
        defer {
            isBusy = false
            refreshHelper()
        }
        helperState = helper.state()
        if operation == .install {
            if let errorKey = installationErrorKey {
                discardPendingSelection()
                showHelperError(errorKey)
                return
            }
            if helperState == .requiresApproval {
                if fromSetting, await !confirm(operation, fromSetting) {
                    discardPendingSelection()
                    return
                }
                helper.openSystemSettings()
                return
            }
        }
        guard await confirm(operation, fromSetting) else {
            if fromSetting {
                discardPendingSelection()
            }
            return
        }
        if operation == .install, let errorKey = installationErrorKey {
            discardPendingSelection()
            showHelperError(errorKey)
            return
        }
        let result = await helper.perform(operation)
        finishManagement(operation, result)
    }

    private func finishManagement(_ operation: HelperManagementOperation, _ result: HelperManagementResult) {
        switch result {
        case .success:
            helperState = helper.state()
            if operation == .remove {
                discardPendingSelection()
                helper.completed(operation, result)
            } else if helperState == .installed {
                completeInstallation()
            } else if helperState != .requiresApproval {
                discardPendingSelection()
            }
        case .cancelled: discardPendingSelection()
        case let .failure(failedOperation, details, needsReadback):
            discardPendingSelection()
            helper.completed(operation, result)
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Capsaicin", category: "Helper")
                .error("Helper management failed: \(details, privacy: .private)")
            showHelperError(failedOperation == .remove && !needsReadback
                ? "helperRestore" : Self.operationKey(failedOperation))
        }
    }

    private var installationErrorKey: String? {
        if helper.state() == .unavailable {
            return "helperUnavailable"
        }
        if helper.isTranslocated() {
            return "helperTranslocated"
        }
        return nil
    }

    private func showHelperError(_ key: String) {
        showError(SettingsSection.helper.text("error." + key + ".title"),
                  SettingsSection.helper.text("error." + key + ".message"))
    }

    static func operationKey(_ operation: HelperManagementOperation) -> String {
        switch operation {
        case .install: "helperInstall"
        case .remove: "helperRemove"
        }
    }
}
