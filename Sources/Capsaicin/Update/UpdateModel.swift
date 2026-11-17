import AppKit
import CapsaicinCore
import Observation
import Sparkle

@MainActor
@Observable
final class UpdateModel: NSObject, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    let isEnabled: Bool
    private(set) var canCheckForUpdates = false
    private(set) var lastUpdateCheckDate: Date?
    private(set) var pendingUpdateVersion: String?
    private(set) var pendingInstallationVersion: String?
    private var currentMode = AutomaticUpdateMode.off
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var pendingInstallation: (() -> Void)?
    private var isBlocking = false
    private var settingsWindowIsOpen = false

    var automaticUpdateMode: AutomaticUpdateMode {
        get { currentMode }
        set {
            guard let updater = controller?.updater else { return }
            updater.automaticallyChecksForUpdates = newValue.automaticallyChecksForUpdates
            updater.automaticallyDownloadsUpdates = newValue.automaticallyDownloadsUpdates
            refresh()
        }
    }

    init(bundle: Bundle = .main) {
        isEnabled = UpdatePolicy.isEnabled(
            feedURL: bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? "",
            publicKey: bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? "",
        )
        super.init()
    }

    func start() {
        guard isEnabled, controller == nil else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: self, userDriverDelegate: self,
        )
        self.controller = controller
        let updater = controller.updater
        observations = [
            updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            updater.observe(\.automaticallyDownloadsUpdates, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            updater.observe(\.lastUpdateCheckDate, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
        ]
        controller.startUpdater()
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }

    func updateInstallationConditions(isBlocking: Bool, settingsWindowIsOpen: Bool) {
        self.isBlocking = isBlocking
        self.settingsWindowIsOpen = settingsWindowIsOpen
        installIfReady()
    }

    func refresh() {
        guard let updater = controller?.updater else { return }
        currentMode = AutomaticUpdateMode(
            automaticallyChecksForUpdates: updater.automaticallyChecksForUpdates,
            automaticallyDownloadsUpdates: updater.automaticallyDownloadsUpdates,
        )
        canCheckForUpdates = updater.canCheckForUpdates
        lastUpdateCheckDate = updater.lastUpdateCheckDate
    }

    private func installIfReady() {
        guard UpdatePolicy.canInstallAutomatically(isBlocking: isBlocking,
                                                   settingsWindowIsOpen: settingsWindowIsOpen),
            let install = pendingInstallation else { return }
        pendingInstallation = nil
        install()
    }

    var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_: SUAppcastItem,
                                                              andInImmediateFocus _: Bool) -> Bool
    {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem,
                                                   state _: SPUUserUpdateState)
    {
        if !handleShowingUpdate {
            pendingUpdateVersion = update.displayVersionString
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate _: SUAppcastItem) {
        pendingUpdateVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        pendingUpdateVersion = nil
    }

    func updater(_: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool
    {
        pendingInstallationVersion = item.displayVersionString
        pendingInstallation = immediateInstallHandler
        // ブロックは true を返した後に使う。すでに停止中でも次のメインキューまで待つ。
        DispatchQueue.main.async { [weak self] in self?.installIfReady() }
        return true
    }

    func updater(_: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool
    {
        guard isBlocking else { return false }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if confirmStoppingForInstallation() {
                installHandler()
            } else {
                // 取り消しは今のインストールだけを止める。抑止と設定画面が終わったら続ける。
                pendingInstallationVersion = item.displayVersionString
                pendingInstallation = installHandler
            }
        }
        return true
    }

    func updater(_: SPUUpdater, didFinishUpdateCycleFor _: SPUUpdateCheck, error _: any Error?) {
        pendingUpdateVersion = nil
        pendingInstallationVersion = nil
        pendingInstallation = nil
        refresh()
    }

    private func confirmStoppingForInstallation() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = text("alert.updateInstallation.title")
        alert.informativeText = text("alert.updateInstallation.message")
        alert.addButton(withTitle: text("alert.updateInstallation.install"))
        alert.addButton(withTitle: text("alert.updateInstallation.cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: "App")
    }
}
