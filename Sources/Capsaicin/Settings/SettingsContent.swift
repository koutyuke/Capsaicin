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
    case sleep, turnOff, keepOn

    init(settings: Settings) {
        self = settings.blocksManualSleep ? (settings.lidCloseDisplay == .turnOff ? .turnOff : .keepOn) : .sleep
    }
}

struct SettingsSleepRow: Identifiable {
    let key: String
    let symbol: String?
    let setting: WritableKeyPath<Settings, Bool>?
    let state: SleepSettingRowState
    var help = ""
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
                     helper: HelperInstallationState) -> [Self]
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
            row.help = (row.state == .onWithoutHelper ? SettingsSection.sleep.text("helperNotReady") : "")
                + SettingsSection.sleep.text(row.key + ".help")
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
