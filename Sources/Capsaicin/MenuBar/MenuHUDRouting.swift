import AppKit
import CapsaicinCore

enum MenuHUDRouting {
    static func shouldPresent(_ event: BlockingEvent) -> Bool {
        switch event {
        case .started(.user(.menu)), .started(.user(.hotkey)),
             .timeLimitReplaced(.menu),
             .startRejected(.user(.menu), _), .startRejected(.user(.hotkey), _),
             .released(.user(.menu)), .released(.user(.hotkey)),
             .released(.timeLimit), .released(.batteryBelowThreshold): true
        default: false
        }
    }

    @MainActor
    static func deliver(_ event: BlockingEvent, status: BlockingStatus,
                        previousSession: BlockingSession?, to presenter: HUDPresenter)
    {
        guard shouldPresent(event), let content = HUDContent.make(
            for: event, status: status, previousSession: previousSession,
        ) else { return }
        // メニューの追跡が終わった後の通常のランループで、表示と読み上げを行う。
        RunLoop.main.perform(inModes: [.default]) {
            MainActor.assumeIsolated { presenter.show(content) }
        }
    }
}
