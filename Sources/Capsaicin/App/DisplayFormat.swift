import Foundation

enum DisplayFormat {
    static func time(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened,
                                        locale: locale, calendar: calendar, timeZone: calendar.timeZone))
    }

    static func duration(_ seconds: TimeInterval, calendar: Calendar, locale: Locale) -> String {
        var calendar = calendar
        calendar.locale = locale
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? ""
    }
}
