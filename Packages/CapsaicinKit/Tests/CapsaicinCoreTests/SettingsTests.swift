@testable import CapsaicinCore
import Foundation
import Testing

struct SettingsTests {
    @Test("SPEC-SET-002 既定値は設定項目の表のとおり")
    func defaults() {
        let settings = Settings()
        #expect(settings.launchesAtLogin)
        #expect(settings.showsHUD)
        #expect(settings.showsMenuBarIcon)
        #expect(!settings.showsDockIcon)
        #expect(settings.blocksDisplaySleep)
        #expect(!settings.blocksManualSleep)
        #expect(settings.lidCloseDisplay == .turnOff)
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

    @Test("SPEC-SET-002 しきい値は 5〜100% の 5% 刻みだけを受け付ける", arguments: [-5, 0, 5, 7, 20, 100, 105])
    func thresholdRange(percent: Int) {
        let valid = (5 ... 100).contains(percent) && percent.isMultiple(of: 5)
        #expect((BatteryThreshold(percent: percent) != nil) == valid)
    }

    @Test("SPEC-SET-002 範囲外のしきい値を読むと、その項目だけ既定値にする", arguments: [0, 105])
    func invalidThresholdFallsBack(percent: Int) throws {
        let data = Data("{\"batteryThreshold\":\(percent),\"showsHUD\":false}".utf8)
        var expected = Settings()
        expected.showsHUD = false
        #expect(try JSONDecoder().decode(Settings.self, from: data) == expected)
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
        settings.timerDuration = minutes(90)
        settings.specifiedTime = time(23, 5)
        settings.batteryThreshold = try #require(BatteryThreshold(percent: 35))
        settings.blocksManualSleep = true
        settings.lidCloseDisplay = .keepOn
        settings.showsMenuBarIcon = false
        settings.showsDockIcon = true
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(Settings.self, from: data) == settings)
    }

    @Test("SPEC-SET-002 SPEC-MENU-006 アイコン表示は既定でオン、保存したオフを復元する")
    func menuBarIconCoding() throws {
        let data = try JSONEncoder().encode(Settings())
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["showsMenuBarIcon"] as? Bool == true)
        let hidden = try JSONDecoder().decode(Settings.self, from: Data(#"{"showsMenuBarIcon": false}"#.utf8))
        #expect(!hidden.showsMenuBarIcon)
    }

    @Test("SPEC-SET-002 SPEC-MENU-007 Dock表示は既定でオフ、保存した値を復元する", arguments: [true, false])
    func dockIconCoding(visible: Bool) throws {
        let defaults = try JSONEncoder().encode(Settings())
        let object = try #require(JSONSerialization.jsonObject(with: defaults) as? [String: Any])
        #expect(object["showsDockIcon"] as? Bool == false)
        let json = "{\"showsDockIcon\": \(visible)}"
        let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        #expect(settings.showsDockIcon == visible)
        let encoded = try JSONEncoder().encode(settings)
        let restored = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(restored["showsDockIcon"] as? Bool == visible)
    }

    @Test("SPEC-SET-002 欠けたキーは既定値で補い、未知のキーは無視する")
    func missingAndUnknownKeys() throws {
        let json = #"{"blocksDisplaySleep": false, "futureOption": 3}"#
        var expected = Settings()
        expected.blocksDisplaySleep = false
        #expect(try JSONDecoder().decode(Settings.self, from: Data(json.utf8)) == expected)
    }

    @Test("SPEC-LCY-008 以前の版の設定から有効な値だけを引き継ぐ")
    func readsSettingsFromPreviousVersion() throws {
        let data = Data(#"{"resumePolicy":"afterAppRestart","launchesAtLogin":false,"showsHUD":false}"#.utf8)
        let settings = try JSONDecoder().decode(Settings.self, from: data)
        #expect(!settings.launchesAtLogin && !settings.showsHUD)
        let encoded = try JSONEncoder().encode(settings)
        let written = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(written["resumePolicy"] == nil)
    }

    @Test("SPEC-SET-002 範囲外や型の違う値は、その項目だけ既定値にする")
    func invalidValuesFallBack() throws {
        let json = """
        {"batteryThreshold": 150, "timerDuration": 0, "specifiedTime": {"hour": 24, "minute": 0},
         "showsHUD": "yes", "showsMenuBarIcon": "no", "showsDockIcon": "yes", "lidCloseDisplay": "dim"}
        """
        #expect(try JSONDecoder().decode(Settings.self, from: Data(json.utf8)) == Settings())
    }

    @Test("SPEC-SET-002 画面と手動の保存キーを保ち、新しい閉じたときの画面を読み書きする")
    func sleepSettingsCoding() throws {
        let json = #"{"blocksDisplaySleep": false, "blocksManualSleep": true, "lidCloseDisplay": "keepOn"}"#
        let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        #expect(!settings.blocksDisplaySleep && settings.blocksManualSleep)
        #expect(settings.lidCloseDisplay == .keepOn)
        let data = try JSONEncoder().encode(settings)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["blocksDisplaySleep"] as? Bool == false)
        #expect(object["blocksManualSleep"] as? Bool == true)
        #expect(object["lidCloseDisplay"] as? String == "keepOn")
    }

    @Test("SPEC-SET-005 SPEC-BLK-013 明るさを0をzeroBrightnessとして保存して読み戻す")
    func zeroBrightnessCoding() throws {
        let json = #"{"blocksManualSleep":true,"lidCloseDisplay":"zeroBrightness"}"#
        let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        #expect(settings.blocksManualSleep && settings.lidCloseDisplay == .zeroBrightness)
        let data = try JSONEncoder().encode(settings)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["lidCloseDisplay"] as? String == "zeroBrightness")
        #expect(try JSONDecoder().decode(Settings.self, from: data) == settings)
    }

    @Test("SPEC-SET-002 欠けた閉じたときの画面は消灯にし、古い保存値は読み飛ばす")
    func oldSleepKeysIgnored() throws {
        let oldValues: [String: Bool] = [
            "blocksIdleSleep": false,
            "blocksLidSleep": true,
            "turnsOffDisplayOnLidClose": false,
        ]
        let data = try JSONSerialization.data(withJSONObject: oldValues)
        #expect(try JSONDecoder().decode(Settings.self, from: data) == Settings())
    }
}
