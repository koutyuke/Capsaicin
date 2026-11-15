import CapsaicinCore
import Foundation

enum MenuCommand: Equatable {
    case start(StartTimeOverride?), stop, durationPanel, timePanel, settings, quit
    case toggleSleep(String), lidClose(SettingsLidCloseChoice)
    case toggleBattery
}

struct MenuEntry {
    var id: String
    var title: String = ""
    var subtitle: String?
    var command: MenuCommand?
    var children: [MenuEntry] = []
    var isWarning = false
    var isChecked = false
    var accessibilityLabel: String?
}

enum MenuContent {
    static func make(
        status: BlockingStatus, settings: Settings, isOnACPower: Bool, hasInternalBattery: Bool,
        sleepRows: [SettingsSleepRow],
        now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current, bundle: Bundle = .main,
    ) -> [MenuEntry] {
        func row(_ key: String, subtitle: String? = nil, command: MenuCommand? = nil,
                 children: [MenuEntry] = []) -> MenuEntry
        {
            MenuEntry(id: key, title: text(key, bundle: bundle), subtitle: subtitle, command: command,
                      children: children)
        }
        var rows = [row(status.isBlocking ? "menu.header.active" : "menu.header.idle")]
        rows += warnings(status: status, bundle: bundle)
        let timeRows = [row("menu.header.fromNow")] + presets(calendar: calendar, locale: locale, bundle: bundle) + [
            MenuEntry(id: "separator.time"), row("menu.startUntil", command: .timePanel),
        ]
        if let session = status.session {
            if let limit = session.timeLimit {
                var entry = row("menu.status.until")
                entry.title = String(
                    format: entry.title,
                    DisplayFormat.time(limit.date, calendar: calendar, locale: locale),
                    duration(limit.date.timeIntervalSince(now), calendar: calendar,
                             locale: locale, bundle: bundle),
                )
                rows.append(entry)
            } else {
                rows.append(row("menu.status.noCondition"))
            }
            if let battery = status.batteryCondition {
                var entry = row("menu.status.battery")
                entry.title = isOnACPower && battery.ignoresOnACPower
                    ? text("menu.status.battery.onAdapter", bundle: bundle)
                    : String(format: entry.title, battery.threshold.percent)
                rows.append(entry)
            }
            rows.append(row("menu.stop", command: .stop))
            rows.append(row("menu.changeTime", children: timeRows + [
                MenuEntry(id: "separator.noTimeLimit"), row("menu.noTimeLimit", command: .start(.noTimeLimit)),
            ]))
        } else {
            let limit = TimeLimitRule.timeLimit(override: nil, settings: settings, now: now, calendar: calendar)
            let subtitle = startSubtitle(limit, now: now, calendar: calendar, locale: locale, bundle: bundle)
            rows.append(row("menu.start", subtitle: subtitle, command: .start(nil)))
            rows.append(MenuEntry(id: "separator.start"))
            rows.append(row("menu.startNoTimeLimit", command: .start(.noTimeLimit)))
            rows.append(row("menu.startFor", children: timeRows))
        }
        rows += [MenuEntry(id: "separator.sleep"), quickSettings(sleepRows, settings: settings,
                                                                 hasInternalBattery: hasInternalBattery,
                                                                 bundle: bundle)]
        return rows + [MenuEntry(id: "separator.footer"), row("menu.settings", command: .settings),
                       row("menu.quit", command: .quit)]
    }

    private static func startSubtitle(_ limit: TimeLimit?, now: Date, calendar: Calendar,
                                      locale: Locale, bundle: Bundle) -> String
    {
        guard let limit else { return text("menu.start.subtitle.none", bundle: bundle) }
        if limit.source == .timer {
            return String(format: text("menu.start.subtitle.timer", bundle: bundle),
                          duration(
                              limit.date.timeIntervalSince(now),
                              calendar: calendar,
                              locale: locale,
                              bundle: bundle,
                          ))
        }
        let key = calendar.isDate(limit.date, inSameDayAs: now) ? "menu.start.subtitle.until" : "menu.start.subtitle.nextDay"
        return String(
            format: text(key, bundle: bundle),
            DisplayFormat.time(limit.date, calendar: calendar, locale: locale),
        )
    }

    static func text(_ key: String, bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: key, value: nil, table: "MenuBar")
    }

    private static func warnings(status: BlockingStatus, bundle: Bundle) -> [MenuEntry] {
        func warning(_ key: String, subtitle: String? = nil) -> MenuEntry {
            MenuEntry(id: key, title: text(key, bundle: bundle), subtitle: subtitle, isWarning: true)
        }
        var rows: [MenuEntry] = []
        for direction in [MisalignmentDirection.leftApplied, .notApplied] {
            let affected = status.misalignments.filter { $0.key != .led && $0.value == direction }
            if !affected.isEmpty {
                let key = direction == .leftApplied ? "menu.warning.remainingSleepSetting" : "menu.warning.unappliedSleep"
                rows.append(warning(key + ".title", subtitle: affected[.systemSleepDisabled] == nil ? nil :
                        text(key + ".helper.subtitle", bundle: bundle)))
            }
        }
        if status.misalignments[.led] != nil {
            rows.append(warning("menu.warning.unalignedLed.title"))
        }
        if status.isRecordUnsaved {
            rows.append(warning("menu.warning.stateSaveFailed.title"))
        }
        return rows
    }

    private static func presets(calendar: Calendar, locale: Locale, bundle: Bundle) -> [MenuEntry] {
        [15, 30, 60, 120, 240, 480].map { minutes in
            MenuEntry(id: "preset.\(minutes)",
                      title: duration(Double(minutes * 60), calendar: calendar, locale: locale, bundle: bundle),
                      command: .start(.timer(TimerDuration(minutes: minutes)!)))
        } + [MenuEntry(
            id: "menu.startFor.custom",
            title: text("menu.startFor.custom", bundle: bundle),
            command: .durationPanel,
        )]
    }

    private static func quickSettings(_ sleepRows: [SettingsSleepRow], settings: Settings,
                                      hasInternalBattery: Bool, bundle: Bundle) -> MenuEntry
    {
        var rows = sleepEntries(sleepRows, settings: settings, bundle: bundle)
        if hasInternalBattery {
            rows += [MenuEntry(id: "separator.battery"), batteryEntry(settings: settings, bundle: bundle)]
        }
        return MenuEntry(id: "menu.quickSettings", title: text("menu.quickSettings", bundle: bundle),
                         children: rows, isWarning: rows.contains(where: \.isWarning))
    }

    private static func sleepEntries(_ rows: [SettingsSleepRow], settings: Settings, bundle: Bundle) -> [MenuEntry] {
        rows.flatMap { row in
            let title = SettingsSection.sleep.text(row.key + ".label")
            if row.key == "lidClose" {
                // 1つを選ぶ選択肢は前後を区切りで囲み、オン・オフの項目と見分けられるようにする。
                return [MenuEntry(id: "separator.lidClose"), MenuEntry(id: "menu.header.lidClose", title: title)]
                    + SettingsLidCloseChoice.allCases
                    .map { choice in
                        let selected = choice == SettingsLidCloseChoice(settings: settings)
                        let choiceTitle = SettingsSection.sleep.text("lidClose." + choice.rawValue)
                        return MenuEntry(id: "menu.sleep.lidClose." + choice.rawValue, title: choiceTitle,
                                         subtitle: selected && !row.warning.isEmpty ? row.warning : nil,
                                         command: .lidClose(choice), isWarning: selected && !row.warningLabel.isEmpty,
                                         isChecked: selected,
                                         accessibilityLabel: String(
                                             format: text("menu.sleep.lidClose.a11y", bundle: bundle),
                                             title,
                                             choiceTitle,
                                         ))
                    }
            }
            return [MenuEntry(id: "menu.sleep." + row.key, title: title,
                              subtitle: row.warning.isEmpty ? nil : row.warning,
                              command: .toggleSleep(row.key),
                              isWarning: !row.warningLabel.isEmpty, isChecked: row.isOn)]
        }
    }

    private static func batteryEntry(settings: Settings, bundle: Bundle) -> MenuEntry {
        MenuEntry(id: "menu.battery",
                  title: String(format: text("menu.battery", bundle: bundle), settings.batteryThreshold.percent),
                  subtitle: settings.ignoresBatteryOnACPower ? text("menu.battery.subtitle", bundle: bundle) : nil,
                  command: .toggleBattery, isChecked: settings.batteryConditionEnabled)
    }

    private static func duration(_ seconds: TimeInterval, calendar: Calendar, locale: Locale,
                                 bundle: Bundle) -> String
    {
        guard seconds >= 60 else { return text("menu.duration.lessThanMinute", bundle: bundle) }
        return DisplayFormat.duration(floor(seconds / 60) * 60, calendar: calendar, locale: locale)
    }
}
