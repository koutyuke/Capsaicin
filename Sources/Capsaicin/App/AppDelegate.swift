import AppKit
import CapsaicinPlatform

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var runtime: AppRuntime?
    private var startup: Task<Bool, Never>?
    private var explicitUserQuit = false

    func applicationDidFinishLaunching(_: Notification) {
        do {
            let runtime = try AppComposition.make(quit: { [weak self] in self?.quitByUser() })
            self.runtime = runtime
            let startup = Task { await runtime.start() }
            self.startup = startup
            Task {
                if await !startup.value {
                    // 引き渡し済みで後片付けはない。Task の中で terminateLater を返すと、返答の Task が
                    // メインキューで待たされて終了できないので、startup を外して terminateNow にする。
                    self.startup = nil
                    NSApplication.shared.terminate(nil)
                }
            }
        } catch {
            AppRuntime.log(error)
            NSApplication.shared.terminate(nil)
        }
    }

    func quitByUser() {
        // この terminate 呼び出しの間だけ有効にし、次の終了試行には持ち越さない。
        explicitUserQuit = true
        defer { explicitUserQuit = false }
        NSApplication.shared.terminate(nil)
    }

    /// 起動中に Finder などからアプリを開き直すと呼ばれる。Dock のアイコンがないので、ここを設定画面の入口にする。
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        runtime?.openSettings()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let startup, let runtime else { return .terminateNow }
        let reason = TerminationReasonDetector.classify(
            explicitUserQuit: explicitUserQuit, appleEvent: NSAppleEventManager.shared().currentAppleEvent,
        )
        Task {
            if await startup.value {
                await runtime.terminate(reason: reason)
            }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
