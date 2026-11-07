import Foundation

/// loginwindow が配信する画面のロックの開始と終了を受け取る。スクリーンセーバーの開始と終了でも届く。
/// 名前は SDK に定数がないので文字列で書く。届かなくなっても、再適用のきっかけが減るだけである。
@MainActor
final class ScreenLockObserver: NSObject {
    private static let names: [Notification.Name] = [
        .init("com.apple.screenIsLocked"),
        .init("com.apple.screenIsUnlocked"),
    ]
    private let onChange: @MainActor () -> Void

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        super.init()
    }

    /// メニューバーのアプリはほぼ常に非アクティブで、AppKit が既定の配信を止めるので、即時配信で受け取る。
    func start() {
        for name in Self.names {
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(changed), name: name, object: nil, suspensionBehavior: .deliverImmediately,
            )
        }
    }

    func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func changed() {
        onChange()
    }
}
