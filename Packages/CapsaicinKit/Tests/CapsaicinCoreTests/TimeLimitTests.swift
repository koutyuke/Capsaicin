@testable import CapsaicinCore
import Foundation
import Testing

struct TimeLimitTests {
    private let tokyo = calendar("Asia/Tokyo")
    private let newYork = calendar("America/New_York")

    private func limit(_ override: StartTimeOverride?, _ settings: Settings, at now: Date) -> TimeLimit? {
        TimeLimitRule.timeLimit(override: override, settings: settings, now: now, calendar: tokyo)
    }

    @Test("SPEC-BLK-003 指定のない開始は、設定でオンのタイマーを使う")
    func unspecifiedUsesSettings() {
        let now = tokyo.date(2026, 11, 6, 13, 0)
        let settings = Settings.premise { $0.timerEnabled = true }
        #expect(limit(nil, settings, at: now) == TimeLimit(date: now.addingTimeInterval(3600), source: .timer))
    }

    @Test("SPEC-BLK-003 時間を指定した開始は、設定のタイマーと指定時刻を使わない")
    func overrideReplacesSettings() {
        let now = tokyo.date(2026, 11, 6, 13, 0)
        let settings = Settings.premise {
            $0.timerEnabled = true
            $0.specifiedTimeEnabled = true
            $0.specifiedTime = time(13, 30)
        }
        #expect(limit(.timer(minutes(120)), settings, at: now)?.date == now.addingTimeInterval(7200))
        let specified = limit(.specifiedTime(time(18, 0)), settings, at: now)
        #expect(specified == TimeLimit(date: tokyo.date(2026, 11, 6, 18, 0), source: .specifiedTime))
    }

    @Test("SPEC-BLK-003 両方を使うときは早い方を解除の時刻にし、その条件を由来にする")
    func earlierWins() {
        let now = tokyo.date(2026, 11, 6, 13, 0)
        let settings = Settings.premise {
            $0.timerEnabled = true
            $0.specifiedTimeEnabled = true
            $0.specifiedTime = time(13, 30)
        }
        #expect(limit(nil, settings, at: now) == TimeLimit(
            date: tokyo.date(2026, 11, 6, 13, 30),
            source: .specifiedTime,
        ))
        var later = settings
        later.specifiedTime = time(15, 0)
        #expect(limit(nil, later, at: now)?.source == .timer)
    }

    @Test("SPEC-BLK-003 両方が同じ時刻なら由来は指定時刻")
    func tieGoesToSpecifiedTime() {
        let now = tokyo.date(2026, 11, 6, 13, 0)
        let settings = Settings.premise {
            $0.timerEnabled = true
            $0.specifiedTimeEnabled = true
            $0.specifiedTime = time(14, 0)
        }
        #expect(limit(nil, settings, at: now) == TimeLimit(
            date: tokyo.date(2026, 11, 6, 14, 0),
            source: .specifiedTime,
        ))
    }

    @Test("SPEC-BLK-003 時間の条件を使わなければ解除の時刻を持たない")
    func noTimeCondition() {
        #expect(limit(nil, .premise(), at: Date()) == nil)
    }

    @Test("SPEC-BLK-003 現在時刻が解除の時刻以上になった時点で時間の条件が成り立つ")
    func reachedAtLimit() {
        let limit = TimeLimit(date: Date(timeIntervalSince1970: 1000), source: .timer)
        #expect(!TimeLimitRule.isReached(limit, now: Date(timeIntervalSince1970: 999)))
        #expect(TimeLimitRule.isReached(limit, now: Date(timeIntervalSince1970: 1000)))
    }

    struct SpecifiedTimeCase: Sendable, CustomTestStringConvertible {
        /// 2026-11-06 の開始の時刻（時、分、秒）。
        var hour: Int
        var minute: Int
        var second = 0
        var specified: TimeOfDay
        /// 解除の時刻の日。時と分は指定どおり。
        var expectedDay: Int

        var testDescription: String {
            "\(hour):\(minute):\(second) に \(specified.hour):\(specified.minute) を指定"
        }
    }

    @Test(
        "SPEC-BLK-005 指定時刻は開始より厳密に後の最も早い時刻になる",
        arguments: [
            SpecifiedTimeCase(hour: 23, minute: 0, specified: time(4, 0), expectedDay: 7),
            SpecifiedTimeCase(hour: 13, minute: 0, specified: time(18, 0), expectedDay: 6),
            SpecifiedTimeCase(hour: 4, minute: 0, second: 30, specified: time(4, 0), expectedDay: 7),
            SpecifiedTimeCase(hour: 4, minute: 0, specified: time(4, 0), expectedDay: 7),
            SpecifiedTimeCase(hour: 3, minute: 59, second: 59, specified: time(4, 0), expectedDay: 6),
        ],
    )
    func specifiedTime(_ testCase: SpecifiedTimeCase) {
        let now = tokyo.date(2026, 11, 6, testCase.hour, testCase.minute)
            .addingTimeInterval(TimeInterval(testCase.second))
        let result = SpecifiedTimeRule.releaseDate(for: testCase.specified, after: now, calendar: tokyo)
        let expected = tokyo.date(2026,
                                  11,
                                  testCase.expectedDay,
                                  testCase.specified.hour,
                                  testCase.specified.minute)
        #expect(result == expected)
    }

    @Test("SPEC-BLK-005 夏時間で存在しない時刻は、その直後に存在する時刻になる")
    func skippedTime() {
        // 2026-03-08 のニューヨークは 2:00 から 3:00 に飛ぶ。
        let now = newYork.date(2026, 3, 7, 23, 0)
        let result = SpecifiedTimeRule.releaseDate(for: time(2, 30), after: now, calendar: newYork)
        #expect(result == newYork.date(2026, 3, 8, 3, 0))
        #expect(result == Date(timeIntervalSince1970: 1_772_953_200)) // 2026-03-08T07:00:00Z
    }

    @Test("SPEC-BLK-005 夏時間で2回来る時刻は、どちらの出現も候補になる")
    func repeatedTime() {
        // 2026-11-01 のニューヨークは 2:00 (EDT) から 1:00 (EST) に戻る。1回目の 1:45 は 05:45Z。
        let firstOneFortyFive = Date(timeIntervalSince1970: 1_793_511_900)
        let result = SpecifiedTimeRule.releaseDate(for: time(1, 30), after: firstOneFortyFive, calendar: newYork)
        #expect(result == firstOneFortyFive.addingTimeInterval(45 * 60))
        let beforeFirst = firstOneFortyFive.addingTimeInterval(-30 * 60)
        let first = SpecifiedTimeRule.releaseDate(for: time(1, 30), after: beforeFirst, calendar: newYork)
        #expect(first == firstOneFortyFive.addingTimeInterval(-15 * 60))
    }

    @Test("SPEC-BLK-005 夏時間で2回来る日の2回目の 1:45 に 1:30 を指定したら、翌日の 1:30 になる")
    func afterSecondOccurrence() {
        // 2回目の 1:45 (EST) は 06:45Z、翌日の 1:30 (EST) は 06:30Z。
        let secondOneFortyFive = Date(timeIntervalSince1970: 1_793_515_500)
        let result = SpecifiedTimeRule.releaseDate(for: time(1, 30), after: secondOneFortyFive, calendar: newYork)
        #expect(result == Date(timeIntervalSince1970: 1_793_601_000))
        #expect(result == newYork.date(2026, 11, 2, 1, 30))
    }
}
