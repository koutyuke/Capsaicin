import AppKit

protocol RunningApp {
    var bundleIdentifier: String? { get }
    var processIdentifier: pid_t { get }
    var isTerminated: Bool { get }
    var bundleURL: URL? { get }
}

extension NSRunningApplication: RunningApp {}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var runtime: AppRuntime?
    private(set) var startup: Task<Void, Never>?
    private var startupFinished = false
    private var pendingReopen = false
    private var explicitUserQuit = false

    func applicationDidFinishLaunching(_: Notification) {
        launch(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            runningApplications: { NSRunningApplication.runningApplications(withBundleIdentifier: $0) },
            reopenAndTerminate: reopenAndTerminate,
            makeRuntime: { AppComposition.make(quit: { [weak self] in self?.quitByUser() }) },
        )
    }

    func launch(
        bundleIdentifier: String?,
        processIdentifier: pid_t,
        runningApplications: (String) -> [any RunningApp],
        reopenAndTerminate: (any RunningApp) -> Void,
        makeRuntime: () -> AppRuntime,
    ) {
        if let bundleIdentifier,
           let other = runningApplications(bundleIdentifier).first(where: {
               $0.bundleIdentifier == bundleIdentifier && $0.processIdentifier != processIdentifier && !$0.isTerminated
           })
        {
            reopenAndTerminate(other)
            return
        }
        let runtime = makeRuntime()
        self.runtime = runtime
        startup = Task {
            await runtime.start()
            startupFinished = true
            if pendingReopen {
                pendingReopen = false
                runtime.openSettings()
            }
        }
    }

    private func reopenAndTerminate(_ application: any RunningApp) {
        Task {
            if !application.isTerminated, let url = application.bundleURL {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.allowsRunningApplicationSubstitution = false
                do {
                    _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
                } catch {
                    AppRuntime.log(error)
                }
            }
            NSApplication.shared.terminate(nil)
        }
    }

    func quitByUser() {
        // この terminate 呼び出しの間だけ有効にし、次の終了試行には持ち越さない。
        explicitUserQuit = true
        defer { explicitUserQuit = false }
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        if startupFinished {
            runtime?.openSettings()
        } else {
            // 起動途中の開き直しを、設定ウインドウが準備されるまで保留する。
            pendingReopen = true
        }
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let startup, let runtime else { return .terminateNow }
        // 利用者の終了と分かるのは、アプリの終了操作を明示的に受けたときだけ。
        let isUserQuit = explicitUserQuit
        Task {
            await startup.value
            await runtime.terminate(isUserQuit: isUserQuit)
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
