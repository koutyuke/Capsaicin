import CapsaicinCore
import Foundation
import Testing

struct DisplayFormatTests {
    @Test("SPEC-UI-012 時刻は表示言語と12時間制・24時間制に従う",
          arguments: ["en_US", "ja_JP", "en_US@hours=h23", "ja_JP@hours=h12"])
    func time(localeID: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: localeID)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = Date(timeIntervalSince1970: 15 * 3600 + 53 * 60)
        let value = DisplayFormat.time(date, calendar: calendar, locale: Locale(identifier: localeID))
        if localeID == "en_US" {
            #expect(value.hasPrefix("3:53"))
            #expect(value.contains("PM"))
        } else if localeID == "ja_JP@hours=h12" {
            #expect(value == "午後3:53")
        } else {
            #expect(value == "15:53")
        }
    }

    @Test("SPEC-UI-012 期間の単位はカレンダーの言語ではなく表示言語に従う",
          arguments: ["en_US", "ja_JP"])
    func duration(localeID: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: localeID == "en_US" ? "ja_JP" : "en_US")
        let value = DisplayFormat.duration(5400, calendar: calendar, locale: Locale(identifier: localeID))
        #expect(value == (localeID == "en_US" ? "1h 30m" : "1時間30分"))
    }

    @Test("SPEC-UI-012 SPEC-MENU-004 メニューとHUDに同じ時刻・期間の書式を使い、各画面の分の丸めを保つ",
          arguments: ["en_US", "ja_JP", "en_US@hours=h23"])
    func content(localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let language = try #require(locale.language.languageCode?.identifier)
        let bundle = try localizedAppBundle(language)
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: language == "en" ? "ja_JP" : "en_US")
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let end = Date(timeIntervalSince1970: 15 * 3600 + 53 * 60)
        let now = end.addingTimeInterval(-5399.99)
        let remaining = language == "en" ? "1h 29m" : "1時間29分"
        let rounded = language == "en" ? "1h 30m" : "1時間30分"
        let time = DisplayFormat.time(end, calendar: calendar, locale: locale)
        for source in [TimeLimitSource.timer, .specifiedTime] {
            let session = BlockingSession(timeLimit: TimeLimit(date: end, source: source))
            let status = BlockingStatus(session: session, batteryCondition: nil,
                                        misalignments: [:])
            let rows = MenuContent.make(status: status, settings: Settings(), isOnACPower: false,
                                        hasInternalBattery: false, sleepRows: [], now: now,
                                        calendar: calendar, locale: locale, bundle: bundle)
            let menu = try #require(rows.first { $0.id == "menu.status.until" })
            #expect(menu
                .title == (language == "en" ? "Until \(time) (\(remaining) remaining)" : "\(time)まで（残り\(remaining)）"))
            for event in [BlockingEvent.started(.menu), .timeLimitReplaced(.menu)] {
                let hud = try #require(HUDContent.make(for: event, status: status, now: now,
                                                       calendar: calendar, locale: locale, bundle: bundle))
                #expect(hud.detail == (source == .timer ? rounded : (language == "en" ? "Until \(time)" : "\(time)まで")))
            }
            if source == .specifiedTime {
                let hud = try #require(HUDContent.make(for: .released(.timeLimit(.specifiedTime)), status: status,
                                                       previousSession: session, calendar: calendar,
                                                       locale: locale, bundle: bundle))
                #expect(hud.detail == (language == "en" ? "Scheduled time (\(time))" : "指定時刻（\(time)）"))
            }
        }
    }

    @Test("SPEC-UI-012 メニューの開始の副題とプリセットも表示言語と時刻の設定に従う",
          arguments: ["en_US", "ja_JP", "en_US@hours=h23"])
    func startSubtitle(localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let language = try #require(locale.language.languageCode?.identifier)
        let bundle = try localizedAppBundle(language)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = Date(timeIntervalSince1970: 12 * 3600)
        let idle = BlockingStatus(session: nil, batteryCondition: nil, misalignments: [:])
        var settings = Settings()
        settings.timerEnabled = true
        settings.timerDuration = try #require(TimerDuration(minutes: 90))
        func rows() -> [MenuEntry] {
            MenuContent.make(status: idle, settings: settings, isOnACPower: false,
                             hasInternalBattery: false, sleepRows: [], now: now,
                             calendar: calendar, locale: locale, bundle: bundle)
        }
        #expect(rows().first { $0.id == "menu.start" }?.subtitle
            == (language == "en" ? "Turns off in 1h 30m" : "1時間30分後にオフ"))
        let presets = try #require(rows().first { $0.id == "menu.startFor" }?.children)
        #expect(presets.first { $0.id == "preset.60" }?.title == (language == "en" ? "1h" : "1時間"))
        settings.timerEnabled = false
        settings.specifiedTimeEnabled = true
        for hour in [15, 4] {
            settings.specifiedTime = try #require(TimeOfDay(hour: hour, minute: 53))
            let date = Date(timeIntervalSince1970: Double(hour * 3600 + 53 * 60))
            let time = DisplayFormat.time(date, calendar: calendar, locale: locale)
            let expected = language == "en" ? "Turns off \(hour == 4 ? "tomorrow " : "")at \(time)"
                : "\(hour == 4 ? "明日" : "")\(time)にオフ"
            #expect(rows().first { $0.id == "menu.start" }?.subtitle == expected)
        }
    }
}
