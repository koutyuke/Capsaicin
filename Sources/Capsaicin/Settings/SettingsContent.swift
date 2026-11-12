import CapsaicinCore
import CapsaicinPlatform
import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, sleep, led, controls, helper, about
    var id: Self {
        self
    }

    var title: String {
        text("title")
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .sleep: "moon.zzz"
        case .led: "custom.capsaicin.led"
        case .controls: "keyboard"
        case .helper: "lock.shield"
        case .about: "info.circle"
        }
    }

    func text(_ key: String) -> String {
        let table = "Settings" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        return Bundle(for: SettingsResources.self).localizedString(forKey: key, value: nil, table: table)
    }
}

private final class SettingsResources: NSObject {}

enum SettingsLidCloseChoice: String, CaseIterable {
    case sleep, turnOff, zeroBrightness, keepOn

    init(settings: Settings) {
        guard settings.blocksManualSleep else { self = .sleep; return }
        switch settings.lidCloseDisplay {
        case .turnOff: self = .turnOff
        case .zeroBrightness: self = .zeroBrightness
        case .keepOn: self = .keepOn
        }
    }
}

struct SettingsSleepRow: Identifiable {
    let key: String
    let symbol: String?
    let setting: WritableKeyPath<Settings, Bool>?
    let state: SleepSettingRowState
    var help = ""
    /// 注意の文。(i) の先頭とメニューの副題で使う。
    var warning = ""
    var warningLabel = ""
    var id: String {
        key
    }

    var isOn: Bool {
        switch state {
        case let .editable(value): value
        case .onWithoutHelper: true
        }
    }

    static func rows(settings: Settings, capabilities: MachineCapabilities,
                     helper: HelperInstallationState, brightnessUnavailable: Bool) -> [Self]
    {
        let presentation = SleepSettingsPresentation(settings: settings, isHelperInstalled: helper == .installed)
        let manual = capabilities.hasLid ? "lidClose" : "manual"
        let definitions: [Self] = [
            Self(key: "display", symbol: "display", setting: \.blocksDisplaySleep, state: presentation.displaySleep),
            Self(key: manual, symbol: capabilities.hasLid ? "laptopcomputer" : "powersleep",
                 setting: capabilities.hasLid ? nil : \.blocksManualSleep, state: presentation.manualSleep),
        ]
        return definitions.map { row in
            var row = row
            var warnings: [String] = []
            if row.state == .onWithoutHelper {
                warnings.append("helperNotReady")
            }
            if row.key == "lidClose", SettingsLidCloseChoice(settings: settings) == .zeroBrightness,
               brightnessUnavailable
            {
                warnings.append("brightnessUnavailable")
            }
            row.warningLabel = warnings.map { SettingsSection.sleep.text($0 + ".a11y") }.joined(separator: "、")
            row.warning = warnings.map { SettingsSection.sleep.text($0) }.joined()
            row.help = row.warning + SettingsSection.sleep.text(row.key + ".help")
            return row
        }
    }
}

struct SettingsReleasePresentation {
    let timerEnabled: Bool
    let timeEnabled: Bool
    let showsBattery: Bool
    let batteryEnabled: Bool
    init(settings: Settings, capabilities: MachineCapabilities) {
        timerEnabled = settings.timerEnabled
        timeEnabled = settings.specifiedTimeEnabled
        showsBattery = capabilities.hasInternalBattery
        batteryEnabled = settings.batteryConditionEnabled
    }
}
