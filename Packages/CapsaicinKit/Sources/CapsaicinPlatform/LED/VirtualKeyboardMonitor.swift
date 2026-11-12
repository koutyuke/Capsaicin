import CapsaicinLEDShim
import Foundation
import OSLog

/// Transport のない仮想キーボードを検出する。LED が上書きされているかは判定しない。
@MainActor
public final class VirtualKeyboardMonitor {
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
        self.init(
            symbolAvailable: { CapsaicinLEDClientSymbolAvailable() },
            makeClient: { try LEDClient.native() },
            schedule: Self.scheduleNative,
        )
    }

    convenience init(
        symbolAvailable: @escaping () -> Bool,
        makeClient: @escaping () throws -> LEDClient,
        schedule: @escaping Schedule,
    ) {
        self.init(detect: {
            guard symbolAvailable() else { return false }
            let client = try makeClient()
            return try client.services().contains { $0.isKeyboard() && $0.transport() == nil }
        }, schedule: schedule)
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
            Logger(subsystem: "io.github.koutyuke.capsaicin", category: "VirtualKeyboard")
                .error("仮想キーボードの検出に失敗: \(String(describing: error), privacy: .public)")
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
