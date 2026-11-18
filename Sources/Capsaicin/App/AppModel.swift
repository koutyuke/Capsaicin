import CapsaicinCore
import CapsaicinIPC
import CapsaicinPlatform
import Observation

enum AppAlert: Equatable {
    case settingsReverted(Set<Mechanism>)
    case terminationIncomplete
}

@MainActor
@Observable
final class AppModel {
    private(set) var status: BlockingStatus
    private(set) var settings: Settings
    let capabilities: MachineCapabilities
    let updater: UpdateModel
    var hasVirtualKeyboard = false
    var launchAgentStatus = LaunchAgentStatus.unavailable
    var willRestartAfterCrash: Bool {
        launchAgentStatus == .ready
    }

    /// 出来事と、その直前のセッション（指定時刻で解除したときの表示に使う）。
    @ObservationIgnored var onEvent: ((BlockingEvent, BlockingSession?) -> Void)?
    @ObservationIgnored var onAlert: ((AppAlert) -> Void)?
    @ObservationIgnored var onStatusChange: ((BlockingStatus) -> Void)?
    @ObservationIgnored var onLaunchAtLoginChange: ((Bool) -> Void)?
    private let controller: BlockingController
    private let saveSettings: (Settings) -> Void

    init(controller: BlockingController, saveSettings: @escaping (Settings) -> Void,
         updater: UpdateModel = UpdateModel())
    {
        self.controller = controller
        self.updater = updater
        self.saveSettings = saveSettings
        status = controller.status
        settings = controller.settings
        capabilities = controller.capabilities
        controller.onEvent = { [weak self] event in
            guard let self else { return }
            let previousSession = status.session
            refresh()
            onEvent?(event, previousSession)
        }
    }

    var shouldSleepDisplayOnLidClose: Bool {
        status.isBlocking && controller.effectiveSettings.shouldSleepDisplayOnLidClose
    }

    var isBrightnessKnownUnavailable: Bool {
        controller.isBrightnessKnownUnavailable
    }

    func lidClosed() {
        controller.lidClosed()
    }

    func lidOpened() {
        controller.lidOpened()
    }

    func launch() {
        controller.launch()
        refresh()
    }

    @discardableResult
    func requestStart(from origin: RequestOrigin, override: StartTimeOverride? = nil) -> StartResult {
        defer { refresh() }
        return controller.requestStart(from: origin, override: override)
    }

    @discardableResult
    func requestStop(from origin: RequestOrigin) -> StopResult {
        defer { refresh() }
        return controller.requestStop(from: origin)
    }

    func toggleByHotkey() {
        controller.toggleByHotkey()
        refresh()
    }

    func prepareHelperRemoval() -> Bool {
        let result = controller.prepareHelperRemoval()
        refresh()
        return result
    }

    func helperRemovalSucceeded() {
        controller.helperRemovalSucceeded()
        refresh()
        saveSettings(settings)
    }

    func helperRemovalFailed() {
        controller.helperRemovalFailed()
        refresh()
    }

    func reconcile() {
        controller.reconcile()
        refresh()
    }

    func helperManagementCompleted(_ operation: HelperManagementOperation, _ result: HelperManagementResult) {
        switch result {
        case .success:
            if operation == .remove {
                helperRemovalSucceeded()
            } else {
                reconcile()
            }
        case let .failure(_, _, needsReadback):
            if operation == .remove, needsReadback {
                helperRemovalFailed()
            }
        case .cancelled: break
        }
    }

    @discardableResult
    func changeSettings(_ value: Settings) -> SettingsChangeResult {
        let previous = settings
        let result = controller.changeSettings(value)
        refresh()
        switch result {
        case .applied:
            saveSettings(settings)
            if previous.launchesAtLogin != settings.launchesAtLogin {
                onLaunchAtLoginChange?(settings.launchesAtLogin)
            }
        case let .reverted(failed):
            onAlert?(.settingsReverted(failed))
        }
        return result
    }

    func timePassed() {
        controller.timePassed()
        refresh()
    }

    func powerStateChanged() {
        controller.powerStateChanged()
        refresh()
    }

    func handle(_ request: IPCRequest) -> IPCResponse {
        guard request.version == IPCProtocol.version else {
            return IPCResponse(outcome: .unsupportedVersion, status: status)
        }
        guard settings.acceptsCLIRequests else {
            return IPCResponse(outcome: .cliRequestsDisabled, status: status)
        }
        let outcome: IPCOutcome = switch request.command {
        case let .start(override):
            switch requestStart(from: .cli, override: override) {
            case .started: .started
            case .timeLimitReplaced: .timeLimitReplaced
            case .released: .released
            case .alreadyBlocking: .alreadyBlocking
            case let .rejected(reason): .startRejected(reason)
            }
        case .stop:
            requestStop(from: .cli) == .released ? .released : .alreadyStopped
        case .status:
            .status
        }
        return IPCResponse(outcome: outcome, status: status)
    }

    func terminate(reason: TerminationReason) {
        let needsAlert: Bool
        switch reason {
        case .userQuit: needsAlert = controller.quitByUser()
        case .sessionEnd:
            controller.endSession()
            needsAlert = false
        case .unknown:
            controller.terminateForUnknownReason()
            needsAlert = false
        }
        refresh()
        if needsAlert {
            onAlert?(.terminationIncomplete)
        }
    }

    private func refresh() {
        settings = controller.settings
        status = controller.status
        onStatusChange?(status)
    }
}
