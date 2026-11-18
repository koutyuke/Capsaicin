import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var runtime: AppRuntime?
    private var startup: Task<Void, Never>?
    private var explicitUserQuit = false

    func applicationDidFinishLaunching(_: Notification) {
        let runtime = AppComposition.make(quit: { [weak self] in self?.quitByUser() })
        self.runtime = runtime
        startup = Task { await runtime.start() }
    }

    func quitByUser() {
        // この terminate 呼び出しの間だけ有効にし、次の終了試行には持ち越さない。
        explicitUserQuit = true
        defer { explicitUserQuit = false }
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        runtime?.openSettings()
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
