import Foundation

/// 抑止のセッション。抑止中だけある。
public struct BlockingSession: Hashable, Sendable, Codable {
    /// 開始時に決めた解除の時刻。時間の条件を使わないときは nil。
    public var timeLimit: TimeLimit?

    public init(timeLimit: TimeLimit?) {
        self.timeLimit = timeLimit
    }
}

/// 利用者の要求がどこから来たか。
public enum RequestOrigin: String, Hashable, Sendable, Codable {
    case menu
    case hotkey
    case cli
}

/// 開始のきっかけ。
public enum StartTrigger: Hashable, Sendable {
    case user(RequestOrigin)
    case resume
}

/// 開始を拒否した理由。
public enum StartRejection: Hashable, Sendable, Codable {
    /// バッテリー残量の条件がすでに成り立っている。
    case batteryBelowThreshold
    /// 手動スリープを止める設定なのに、ヘルパーが正しく設置されていない。
    case helperNotInstalled
    /// 止めるスリープに必要な仕組みを適用できなかった。
    case mechanismsFailed(Set<Mechanism>)
    /// 再開用の記録を保存できない。
    case recordNotSaved
}

/// 解除の理由。
public enum ReleaseReason: Hashable, Sendable {
    case user(RequestOrigin)
    case timeLimit(TimeLimitSource)
    case batteryBelowThreshold
    /// 利用者がアプリを終了した。
    case quit
}

/// 開始の拒否と自動の解除の判定。
public enum BlockingRules {
    /// 仕組みを適用する前に分かる、開始を拒否する理由。
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

    /// 抑止中に自動で解除する理由。時間とバッテリーが同時に成り立てば、時間を理由にする。
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
