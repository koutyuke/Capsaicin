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
    var pendingUpdateVersion: String? {
        dismissedInstallationVersion ?? scheduledUpdateVersion
    }

    private(set) var pendingInstallationVersion: String?
    private var scheduledUpdateVersion: String?
    private var dismissedInstallationVersion: String?
    private var currentMode = AutomaticUpdateMode.off
    @ObservationIgnored private var updater: SPUUpdater?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var pendingInstallation: (() -> Void)?
    private let bundle: Bundle
    private var isBlocking = false
    private var settingsWindowIsOpen = false

    var automaticUpdateMode: AutomaticUpdateMode {
        get { currentMode }
        set {
            guard let updater else { return }
            updater.automaticallyChecksForUpdates = newValue.automaticallyChecksForUpdates
            updater.automaticallyDownloadsUpdates = newValue.automaticallyDownloadsUpdates
            refresh()
        }
    }

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        isEnabled = UpdatePolicy.isEnabled(
            feedURL: bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? "",
            publicKey: bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? "",
        )
        super.init()
    }

    func start() {
        guard isEnabled, updater == nil else { return }
        let standard = SPUStandardUserDriver(hostBundle: bundle, delegate: self)
        let userDriver = InstallationUserDriver(standard: standard) { [weak self] choice, stage, version in
            guard let self else { return choice }
            return installationReply(choice, stage: stage, version: version,
                                     confirm: confirmStoppingForInstallation)
        }
        let updater = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: userDriver, delegate: self)
        self.updater = updater
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
        do {
            try updater.start()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        NSApp.activate(ignoringOtherApps: true)
        updater?.checkForUpdates()
    }

    func updateInstallationConditions(isBlocking: Bool, settingsWindowIsOpen: Bool) {
        self.isBlocking = isBlocking
        self.settingsWindowIsOpen = settingsWindowIsOpen
        installIfReady()
    }

    func refresh() {
        guard let updater else { return }
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
        // 次の提示に引き継ぐ。返答後にも届く attention の通知では取り消しの記録を消さない。
        dismissedInstallationVersion = nil
        if !handleShowingUpdate {
            scheduledUpdateVersion = update.displayVersionString
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate _: SUAppcastItem) {
        scheduledUpdateVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        scheduledUpdateVersion = nil
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

    func installationReply(_ choice: SPUUserUpdateChoice, stage: SPUUserUpdateStage, version: String,
                           confirm: () -> Bool) -> SPUUserUpdateChoice
    {
        let resolved = UpdateInstallationReply.resolve(choice, stage: stage, isBlocking: isBlocking, confirm: confirm)
        if choice == .install, resolved == .dismiss {
            dismissedInstallationVersion = version
        }
        return resolved
    }

    func updater(_: SPUUpdater, didFinishUpdateCycleFor _: SPUUpdateCheck, error: any Error?) {
        scheduledUpdateVersion = nil
        // Dismiss で終わるセッションでは、次に画面を見るまで取り消した版を知らせる。
        if error != nil {
            dismissedInstallationVersion = nil
        }
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
