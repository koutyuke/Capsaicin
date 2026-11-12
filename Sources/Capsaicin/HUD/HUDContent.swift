import CapsaicinCore
import Foundation

struct HUDContent: Equatable {
    enum Tone {
        case normal, error, warning
    }

    var symbol: String
    var state: String
    var detail: String?
    var tone = Tone.normal
    var bundle: Bundle = .main

    var announcement: String {
        detail.map { String(
            format: bundle.localizedString(forKey: "hud.announcement.a11y", value: nil, table: "HUD"),
            state,
            $0,
        ) } ?? state
    }

    /// 解除後の status にはセッションがないため、指定時刻の表示には解除前のセッションを渡す。
    static func make(
        for event: BlockingEvent, status: BlockingStatus, previousSession: BlockingSession? = nil,
        now: Date = Date(), calendar: Calendar = .current, bundle: Bundle = .main,
    ) -> Self? {
        func text(_ key: String) -> String {
            bundle.localizedString(forKey: key, value: nil, table: "HUD")
        }
        let off = Self(symbol: "custom.capsaicin.led", state: text("hud.state.off"), bundle: bundle)
        switch event {
        case .started, .timeLimitReplaced:
            let detail = status.session?.timeLimit.map { limit in
                if limit.source == .specifiedTime {
                    return String(format: text("hud.condition.until"), time(limit.date, calendar: calendar))
                }
                let formatter = DateComponentsFormatter()
                formatter.calendar = calendar
                formatter.allowedUnits = [.hour, .minute]
                formatter.unitsStyle = .abbreviated
                // 開始から HUD を作るまでの遅れで端数の分が切り捨てられ、1分少なく出ないよう分に丸める。
                let minutes = max(1, (limit.date.timeIntervalSince(now) / 60).rounded())
                return String(format: text("hud.condition.for"), formatter.string(from: minutes * 60) ?? "")
            }
            return Self(
                symbol: "custom.capsaicin.led.fill",
                state: text("hud.state.on"),
                detail: detail,
                bundle: bundle,
            )
        case let .startRejected(_, reason):
            return Self(symbol: "xmark.octagon.fill", state: text("hud.state.notStarted"),
                        detail: text(rejectionKey(reason)), tone: .error, bundle: bundle)
        case let .released(reason):
            var result = off
            switch reason {
            case .timeLimit(.timer): result.detail = text("hud.reason.timer")
            case .timeLimit(.specifiedTime):
                result.detail = previousSession?.timeLimit.map {
                    String(format: text("hud.reason.time"), time($0.date, calendar: calendar))
                } ?? text("hud.reason.timeReached")
            case .batteryBelowThreshold:
                result.detail = status.batteryCondition.map {
                    String(format: text("hud.reason.battery"), $0.threshold.percent)
                } ?? text("hud.reason.batteryLowAtStart")
            case .user, .quit: break
            }
            if !status.misalignments.isEmpty {
                result.symbol = "exclamationmark.triangle.fill"
                result.tone = .warning
                result.detail = text("hud.reason.unalignedRemaining")
            }
            return result
        case .warningsChanged: return nil
        }
    }

    private static func rejectionKey(_ reason: StartRejection) -> String {
        switch reason {
        case .batteryBelowThreshold: "hud.reason.batteryLowAtStart"
        case .helperNotInstalled: "hud.reason.helperUnavailableAtStart"
        case .mechanismsFailed: "hud.reason.applyFailedAtStart"
        case .recordNotSaved: "hud.reason.stateSaveFailedAtStart"
        }
    }

    private static func time(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }
}
