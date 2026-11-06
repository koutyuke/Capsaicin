import Foundation
import OSLog

/// 既知の実行ファイルの起動だけを検出する。LED の上書きや設定の有効性を断定しない。
@MainActor
public final class KarabinerElementsMonitor {
    public private(set) var state = false
    public var onStateChange: (@MainActor @Sendable (Bool) -> Void)?
    public var onDetectionFailure: (@MainActor @Sendable (any Error) -> Void)?

    typealias Tick = @MainActor @Sendable () -> Void
    typealias Cancel = @MainActor () -> Void
    typealias Schedule = @MainActor (@escaping Tick) -> Cancel

    private let detect: () throws -> Bool
    private let schedule: Schedule
    private var cancel: Cancel?

    public convenience init() {
        self.init(detect: { try KarabinerProcessSource.native.isRunning() }, schedule: Self.scheduleNative)
    }

    init(detect: @escaping () throws -> Bool, schedule: @escaping Schedule) {
        self.detect = detect
        self.schedule = schedule
    }

    public func start() {
        guard cancel == nil else { return }
        cancel = schedule { [weak self] in
            guard let self, cancel != nil else { return }
            poll()
        }
        poll()
    }

    public func stop() {
        cancel?()
        cancel = nil
    }

    isolated deinit { cancel?() }

    private func poll() {
        let next: Bool
        do {
            next = try detect()
        } catch {
            next = false
            Logger(subsystem: "io.github.koutyuke.capsaicin", category: "KarabinerElements")
                .error("プロセスの検出に失敗: \(String(describing: error), privacy: .public)")
            onDetectionFailure?(error)
        }
        guard state != next else { return }
        state = next
        onStateChange?(next)
    }

    private static func scheduleNative(tick: @escaping Tick) -> Cancel {
        let timer = Timer(timeInterval: 5, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        return { timer.invalidate() }
    }
}
