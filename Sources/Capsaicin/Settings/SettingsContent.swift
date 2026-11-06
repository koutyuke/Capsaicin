import CapsaicinCore
import CapsaicinPlatform
import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, sleep, release, led, controls, helper, about
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
        case .release: "timer"
        case .led: "capslock"
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

struct SettingsSleepRow: Identifiable {
    let key: String
    let setting: WritableKeyPath<Settings, Bool>
    let state: SleepSettingRowState
    var help = ""
    var id: String {
        key
    }

    var isOn: Bool {
        switch state {
        case let .editable(value), let .prerequisiteUnmet(value): value
        case .onWithoutHelper, .implied: true
        case .hidden: false
        }
    }

    var isEnabled: Bool {
        switch state {
        case .editable, .onWithoutHelper: true
        default: false
        }
    }

    var dimsLabel: Bool {
        if case .prerequisiteUnmet = state {
            return true
        }
        return false
    }

    static func rows(settings: Settings, capabilities: MachineCapabilities,
                     helper: HelperInstallationState) -> [Self]
    {
        let presentation = SleepSettingsPresentation(settings: settings, capabilities: capabilities,
                                                     isHelperInstalled: helper == .installed)
        let manual = presentation.manualRowIncludesLidSleep ? "manualAndLid" : "manual"
        let definitions: [Self] = [
            Self(key: "idle", setting: \.blocksIdleSleep, state: presentation.idleSleep),
            Self(key: "display", setting: \.blocksDisplaySleep, state: presentation.displaySleep),
            Self(key: manual, setting: \.blocksManualSleep, state: presentation.manualSleep),
            Self(key: "lid", setting: \.blocksLidSleep, state: presentation.lidSleep),
            Self(
                key: "lidDisplayOff",
                setting: \.turnsOffDisplayOnLidClose,
                state: presentation.turnsOffDisplayOnLidClose,
            ),
        ]
        return definitions.compactMap { row in
            guard row.state != .hidden else { return nil }
            var row = row
            var prefix = ""
            if case let .implied(causes) = row.state {
                prefix = causes.map { cause in
                    SettingsSection.sleep.text("implied." + (cause == .displaySleep ? "byDisplay" :
                            presentation.manualRowIncludesLidSleep ? "byManualAndLid" : "byManual"))
                }.joined()
            } else if row.state == .onWithoutHelper {
                prefix = SettingsSection.sleep.text("helperNotReady")
            }
            row.help = prefix + SettingsSection.sleep.text(row.key + ".help")
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
