import Foundation

public struct BlockingSession: Hashable, Sendable, Codable {
    /// 現在の解除の時刻。時間の条件を使わないときは nil。
    public var timeLimit: TimeLimit?

    public init(timeLimit: TimeLimit?) {
        self.timeLimit = timeLimit
    }
}

public enum RequestOrigin: String, Hashable, Sendable, Codable {
    case menu
    case hotkey
    case cli
}

public enum StartRejection: Hashable, Sendable, Codable {
    case batteryBelowThreshold
    case helperNotInstalled
    case mechanismsFailed(Set<Mechanism>)
}

public enum ReleaseReason: Hashable, Sendable {
    case user(RequestOrigin)
    case timeLimit(TimeLimitSource)
    case batteryBelowThreshold
}

public enum BlockingRules {
    public static func rejectionBeforeApplying(
        effective: EffectiveSettings,
        power: PowerState,
        isHelperInstalled: Bool,
    ) -> StartRejection? {
        if effective.batteryCondition?.isMet(by: power) == true {
            return .batteryBelowThreshold
        }
        if effective.blocksManualSleep, !isHelperInstalled {
            return .helperNotInstalled
        }
        return nil
    }

    /// 時間とバッテリーが同時に成り立てば、時間を理由にする。
    public static func automaticReleaseReason(
        session: BlockingSession,
        batteryCondition: BatteryCondition?,
        power: PowerState,
        now: Date,
    ) -> ReleaseReason? {
        if let limit = session.timeLimit, TimeLimitRule.isReached(limit, now: now) {
            return .timeLimit(limit.source)
        }
        if batteryCondition?.isMet(by: power) == true {
            return .batteryBelowThreshold
        }
        return nil
    }
}
