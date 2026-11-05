@testable import CapsaicinCore
import Foundation
import Testing

struct SettingsTests {
    @Test("SPEC-SET-002 既定値は設定項目の表のとおり")
    func defaults() {
        let settings = Settings()
        #expect(settings.launchesAtLogin)
        #expect(settings.resumePolicy == .never)
        #expect(settings.showsHUD)
        #expect(settings.blocksIdleSleep)
        #expect(!settings.blocksDisplaySleep)
        #expect(!settings.blocksManualSleep)
        #expect(!settings.blocksLidSleep)
        #expect(settings.turnsOffDisplayOnLidClose)
        #expect(!settings.timerEnabled)
        #expect(settings.timerDuration.minutes == 60)
        #expect(!settings.specifiedTimeEnabled)
        #expect(settings.specifiedTime == time(4, 0))
        #expect(settings.batteryConditionEnabled)
        #expect(settings.batteryThreshold.percent == 20)
        #expect(settings.ignoresBatteryOnACPower)
        #expect(settings.notifiesWithLED)
        #expect(settings.acceptsCLIRequests)
    }

    @Test("SPEC-SET-002 タイマーは 1 分〜24 時間だけを受け付ける", arguments: [0, 1, 1440, 1441, -5])
    func timerRange(minutes: Int) {
        #expect((TimerDuration(minutes: minutes) != nil) == (1 ... 1440).contains(minutes))
    }

    @Test("SPEC-SET-002 しきい値は 0〜100% の 5% 刻みだけを受け付ける", arguments: [-5, 0, 5, 7, 20, 100, 105])
    func thresholdRange(percent: Int) {
        let valid = (0 ... 100).contains(percent) && percent.isMultiple(of: 5)
        #expect((BatteryThreshold(percent: percent) != nil) == valid)
    }

    @Test("SPEC-SET-002 時刻は 0:00〜23:59 だけを受け付ける")
    func timeOfDayRange() {
        #expect(TimeOfDay(hour: 0, minute: 0) != nil)
        #expect(TimeOfDay(hour: 23, minute: 59) != nil)
        #expect(TimeOfDay(hour: 24, minute: 0) == nil)
        #expect(TimeOfDay(hour: 12, minute: 60) == nil)
    }

    @Test("SPEC-SET-002 保存した設定を読み直すと同じ値になる")
    func roundTrip() throws {
        var settings = Settings()
        settings.resumePolicy = .afterAppOrMacRestart
        settings.timerDuration = minutes(90)
        settings.specifiedTime = time(23, 5)
        settings.batteryThreshold = try #require(BatteryThreshold(percent: 35))
        settings.blocksManualSleep = true
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(Settings.self, from: data) == settings)
    }

    @Test("SPEC-SET-002 欠けたキーは既定値で補い、未知のキーは無視する")
    func missingAndUnknownKeys() throws {
        let json = #"{"blocksDisplaySleep": true, "futureOption": 3}"#
        var expected = Settings()
        expected.blocksDisplaySleep = true
        #expect(try JSONDecoder().decode(Settings.self, from: Data(json.utf8)) == expected)
    }

    @Test("SPEC-SET-002 範囲外や型の違う値は、その項目だけ既定値にする")
    func invalidValuesFallBack() throws {
        let json = """
        {"batteryThreshold": 150, "timerDuration": 0, "specifiedTime": {"hour": 24, "minute": 0},
         "resumePolicy": "always", "showsHUD": "yes", "blocksLidSleep": true}
        """
        var expected = Settings()
        expected.blocksLidSleep = true
        #expect(try JSONDecoder().decode(Settings.self, from: Data(json.utf8)) == expected)
    }
}
