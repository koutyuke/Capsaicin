import Foundation

public enum SpecifiedTimeRule {
    /// `now` より厳密に後で、壁時計の時と分が一致し秒が 0 の時刻のうち、最も早いもの。
    ///
    /// 夏時間で2回来る時刻はどちらの出現も候補にするため、1回目（`.first`）と2回目（`.last`）を探して早い方を取る。
    /// 存在しない時刻は、`.nextTime` によってその直後に存在する時刻（2:30 が飛ぶ日は 3:00）になる。
    public static func releaseDate(for time: TimeOfDay, after now: Date, calendar: Calendar) -> Date {
        let components = DateComponents(hour: time.hour, minute: time.minute, second: 0)
        let candidates = [Calendar.RepeatedTimePolicy.first, .last].compactMap { policy in
            calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime, repeatedTimePolicy: policy)
        }
        // 時と分だけを合わせる探索は、翌日までに必ず見つかる。
        return candidates.min()!
    }
}
