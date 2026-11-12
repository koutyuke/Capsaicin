import Foundation

/// 解除の時刻の由来。
public enum TimeLimitSource: String, Hashable, Sendable, Codable {
    case timer
    case specifiedTime
}

/// 解除の時刻（壁時計の時刻）とその由来。
public struct TimeLimit: Hashable, Sendable, Codable {
    public var date: Date
    public var source: TimeLimitSource

    public init(date: Date, source: TimeLimitSource) {
        self.date = date
        self.source = source
    }
}

/// 開始の要求に含まれる時間の指定。指定がなければ設定のタイマーと指定時刻を使う。
public enum StartTimeOverride: Hashable, Sendable, Codable {
    case timer(TimerDuration)
    case specifiedTime(TimeOfDay)
    case noTimeLimit
}

/// 開始または置き換えの要求から、解除の時刻を決める規則。
public enum TimeLimitRule {
    /// 使う条件から解除の時刻を1つ決める。早い方を使い、同じ時刻なら由来は指定時刻にする。どちらも使わなければ nil。
    public static func timeLimit(
        override: StartTimeOverride?,
        settings: Settings,
        now: Date,
        calendar: Calendar,
    ) -> TimeLimit? {
        let timer: TimerDuration?
        let specifiedTime: TimeOfDay?
        switch override {
        case nil:
            timer = settings.timerEnabled ? settings.timerDuration : nil
            specifiedTime = settings.specifiedTimeEnabled ? settings.specifiedTime : nil
        case let .timer(duration):
            timer = duration
            specifiedTime = nil
        case let .specifiedTime(time):
            timer = nil
            specifiedTime = time
        case .noTimeLimit:
            timer = nil
            specifiedTime = nil
        }

        let timerLimit = timer.map { TimeLimit(date: now.addingTimeInterval($0.timeInterval), source: .timer) }
        let specifiedLimit = specifiedTime.map {
            TimeLimit(
                date: SpecifiedTimeRule.releaseDate(for: $0, after: now, calendar: calendar),
                source: .specifiedTime,
            )
        }
        switch (timerLimit, specifiedLimit) {
        case let (timerLimit?, specifiedLimit?):
            return timerLimit.date < specifiedLimit.date ? timerLimit : specifiedLimit
        case let (timerLimit, specifiedLimit):
            return timerLimit ?? specifiedLimit
        }
    }

    /// 現在時刻が解除の時刻以上なら、時間の条件が成り立つ。
    public static func isReached(_ limit: TimeLimit, now: Date) -> Bool {
        now >= limit.date
    }
}
