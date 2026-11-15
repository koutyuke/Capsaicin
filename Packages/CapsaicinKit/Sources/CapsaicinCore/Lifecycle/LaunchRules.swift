import Foundation

public enum LaunchReason: Hashable, Sendable {
    case afterCrash
    /// Mac の再起動・ログアウトの後。
    case afterMacRestart
    case normal
}

public enum LaunchRules {
    public static let crashWindow: TimeInterval = 10 * 60
    public static let crashLimit = 3

    /// 記録を書き換える前に判定する。起動時刻が取得不能（`Date.distantPast`）なら通常の起動とする。
    public static func launchReason(record: ResumeRecord?, bootTime: Date) -> LaunchReason {
        guard bootTime != .distantPast, let record else { return .normal }
        if record.isRunning {
            return hasMacBooted(since: record, bootTime: bootTime) ? .afterMacRestart : .afterCrash
        }
        return record.exitReason == .sessionEnd ? .afterMacRestart : .normal
    }

    /// 記録を最後に書いた後に Mac が起動したと確認できるか（取得不能、ログアウトだけなら false）。
    public static func hasMacBooted(since record: ResumeRecord, bootTime: Date) -> Bool {
        bootTime != .distantPast && bootTime > record.lastUpdated
    }

    public static func updatingCrashLaunches(_ launches: [Date], at now: Date, afterCrash: Bool) -> [Date] {
        let recent = launches.filter { now.timeIntervalSince($0) <= crashWindow }
        return afterCrash ? recent + [now] : recent
    }

    /// クラッシュ後の起動の時刻の一覧（今回の起動を加えた後）が上限に達したか。
    public static func isCrashLimitReached(_ launches: [Date]) -> Bool {
        launches.count >= crashLimit
    }

    public static func shouldResume(
        reason: LaunchReason,
        policy: ResumePolicy,
        session: BlockingSession?,
        isCrashLimitReached: Bool,
        now: Date,
    ) -> Bool {
        guard let session, !isCrashLimitReached else { return false }
        if let limit = session.timeLimit, TimeLimitRule.isReached(limit, now: now) {
            return false
        }
        switch (reason, policy) {
        case (.afterCrash, .afterAppRestart), (.afterCrash, .afterAppOrMacRestart),
             (.afterMacRestart, .afterAppOrMacRestart):
            return true
        default:
            return false
        }
    }
}
