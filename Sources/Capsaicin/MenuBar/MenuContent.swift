import CapsaicinCore
import Foundation

enum MenuCommand: Equatable {
    case start(StartTimeOverride?), stop, durationPanel, timePanel, settings, quit
    case toggleSleep(String), lidClose(SettingsLidCloseChoice)
}

struct MenuEntry {
    var id: String
    var title: String = ""
    var subtitle: String?
    var command: MenuCommand?
    var children: [MenuEntry] = []
    var isWarning = false
    var isChecked = false
}

enum MenuContent {
    static func make(
        status: BlockingStatus, settings: Settings, isOnACPower: Bool, sleepRows: [SettingsSleepRow],
        now: Date = Date(), calendar: Calendar = .current, bundle: Bundle = .main,
    ) -> [MenuEntry] {
        func row(_ key: String, subtitle: String? = nil, command: MenuCommand? = nil,
                 children: [MenuEntry] = []) -> MenuEntry
        {
            MenuEntry(id: key, title: text(key, bundle: bundle), subtitle: subtitle, command: command,
                      children: children)
        }
        var rows = [row(status.isBlocking ? "menu.header.active" : "menu.header.idle")]
        rows += warnings(status: status, bundle: bundle)
        if let session = status.session {
            if let limit = session.timeLimit {
                var entry = row("menu.status.until")
                entry.title = String(format: entry.title, time(limit.date, calendar: calendar),
                                     duration(limit.date.timeIntervalSince(now), calendar: calendar, bundle: bundle))
                rows.append(entry)
            } else if status.batteryCondition == nil {
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
            rows.append(row("menu.changeTime", children:
                [row("menu.header.fromNow")] + presets(calendar: calendar, bundle: bundle)))
        } else {
            let limit = TimeLimitRule.timeLimit(override: nil, settings: settings, now: now, calendar: calendar)
            let subtitle = limit.map {
                $0.source == .timer ? duration($0.date.timeIntervalSince(now), calendar: calendar, bundle: bundle)
                    : String(
                        format: text("menu.start.subtitle.until", bundle: bundle),
                        time($0.date, calendar: calendar),
                    )
            } ?? (status.batteryCondition == nil ? text("menu.start.subtitle.none", bundle: bundle) : nil)
            rows.append(row("menu.start", subtitle: subtitle, command: .start(nil)))
            rows.append(row("menu.startFor", children: presets(calendar: calendar, bundle: bundle)))
        }
        return rows + [MenuEntry(id: "separator.sleep"),
                       MenuEntry(id: "menu.sleep", title: SettingsSection.sleep.text("behavior.group.title"),
                                 children: sleepEntries(sleepRows, settings: settings)),
                       MenuEntry(id: "separator.footer"), row("menu.settings", command: .settings),
                       row("menu.quit", command: .quit)]
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

    private static func presets(calendar: Calendar, bundle: Bundle) -> [MenuEntry] {
        [15, 30, 60, 120, 240, 480].map { minutes in
            MenuEntry(id: "preset.\(minutes)",
                      title: duration(Double(minutes * 60), calendar: calendar, bundle: bundle),
                      command: .start(.timer(TimerDuration(minutes: minutes)!)))
        } + [MenuEntry(
            id: "menu.startFor.custom",
            title: text("menu.startFor.custom", bundle: bundle),
            command: .durationPanel,
        ),
        MenuEntry(id: "separator.time"),
        MenuEntry(id: "menu.startUntil", title: text("menu.startUntil", bundle: bundle), command: .timePanel),
        MenuEntry(id: "separator.noTimeLimit"),
        MenuEntry(id: "menu.noTimeLimit", title: text("menu.noTimeLimit", bundle: bundle),
                  command: .start(.noTimeLimit))]
    }

    private static func sleepEntries(_ rows: [SettingsSleepRow], settings: Settings) -> [MenuEntry] {
        rows.map { row in
            let choices: [MenuEntry] = row.key == "lidClose" ? SettingsLidCloseChoice.allCases.map { choice in
                MenuEntry(id: "menu.sleep.lidClose." + choice.rawValue,
                          title: SettingsSection.sleep.text("lidClose." + choice.rawValue), command: .lidClose(choice),
                          isChecked: choice == SettingsLidCloseChoice(settings: settings))
            } : []
            return MenuEntry(id: "menu.sleep." + row.key, title: SettingsSection.sleep.text(row.key + ".label"),
                             subtitle: row.warning.isEmpty ? nil : row.warning,
                             command: row.setting == nil ? nil : .toggleSleep(row.key), children: choices,
                             isWarning: !row.warningLabel.isEmpty, isChecked: row.setting != nil && row.isOn)
        }
    }

    static func time(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }

    private static func duration(_ seconds: TimeInterval, calendar: Calendar, bundle: Bundle) -> String {
        guard seconds >= 60 else { return text("menu.duration.lessThanMinute", bundle: bundle) }
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: floor(seconds / 60) * 60) ?? ""
    }
}
