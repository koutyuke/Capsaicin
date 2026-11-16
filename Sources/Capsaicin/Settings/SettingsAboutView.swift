import AppKit
import CapsaicinCore
import SwiftUI

struct SettingsAboutContent: View {
    @Bindable var updater: UpdateModel
    let quit: () -> Void
    var bundle: Bundle = .main
    @Environment(\.locale) private var locale

    var body: some View {
        Section {
            SettingsRow(title: text("autoUpdate.label"), help: text("autoUpdate.help"),
                        symbol: "arrow.triangle.2.circlepath")
            {
                Picker(text("autoUpdate.label"), selection: $updater.automaticUpdateMode) {
                    Text(text("autoUpdate.option.off")).tag(AutomaticUpdateMode.off)
                    Text(text("autoUpdate.option.check")).tag(AutomaticUpdateMode.checkOnly)
                    Text(text("autoUpdate.option.install")).tag(AutomaticUpdateMode.downloadAndInstall)
                }
                .labelsHidden().pickerStyle(.menu).disabled(!updater.isEnabled)
            }
            softwareUpdate
        } header: {
            VStack(alignment: .leading, spacing: 24) {
                header
                Text(text("updates.group.title"))
            }
        }
        Section {
            Link(destination: URL(string: "https://github.com/koutyuke/Capsaicin")!) {
                SettingsRow(title: text("website.label"), symbol: "globe") {
                    Image(systemName: "arrow.up.right").imageScale(.small).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain).foregroundStyle(.primary)
            .accessibilityHint(text("website.a11y"))
            NavigationLink(value: SettingsDestination.licenses) {
                SettingsRow(title: text("licenses.label"), symbol: "doc.text") {}
            }
        } header: {
            Text(text("links.group.title"))
        } footer: {
            footer
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: bundle.bundlePath))
                .resizable().frame(width: 80, height: 80)
                .accessibilityLabel(text("icon.a11y"))
            VStack(spacing: 4) {
                Text(verbatim: "Capsaicin").font(.title).foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                Text(String(format: text("version"),
                            bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—",
                            bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))
                    .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    var footer: some View {
        VStack(spacing: 12) {
            Button(MenuContent.text("menu.quit", bundle: bundle), action: quit).buttonStyle(.bordered)
            Text(verbatim: bundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? "")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
        // grouped Form の footer の上余白 10 pt を相殺し、カードからの間隔を 24 pt にする。
        .padding(.top, -10)
        .accessibilityElement(children: .contain)
    }

    private var softwareUpdate: some View {
        let state = SettingsUpdateState(isEnabled: updater.isEnabled,
                                        lastChecked: updater.lastUpdateCheckDate,
                                        availableVersion: updater.pendingUpdateVersion,
                                        installationVersion: updater.pendingInstallationVersion)
        let dateLocale = SettingsUpdateState.dateLocale(
            language: bundle.preferredLocalizations.first ?? "en",
            locale: locale,
        )
        return SettingsRow(
            title: text("softwareUpdate.label"),
            subtitle: state.status(bundle: bundle, locale: dateLocale),
            symbol: "arrow.down.circle",
            controlAccessibilityLabel: state.version.map {
                String(format: text("softwareUpdate.update.a11y"), $0)
            } ?? text("softwareUpdate.check.a11y"),
        ) {
            Button(action: updater.checkForUpdates) {
                // どちらのラベルでも同じ幅を確保し、状態の変化で行を動かさない。
                ZStack {
                    Text(text("softwareUpdate.check.button")).hidden()
                    Text(text("softwareUpdate.update.button")).hidden()
                    Text(text(state.version == nil ? "softwareUpdate.check.button" : "softwareUpdate.update.button"))
                }
            }
            .buttonStyle(.bordered).fixedSize().disabled(!updater.isEnabled || !updater.canCheckForUpdates)
        }
    }

    private func text(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: "SettingsAbout")
    }
}

enum SettingsUpdateState: Equatable {
    case notChecked, checked(Date), available(String), readyToInstall(String)

    init(isEnabled: Bool, lastChecked: Date?, availableVersion: String?, installationVersion: String?) {
        if !isEnabled {
            self = .notChecked
        } else if let installationVersion {
            self = .readyToInstall(installationVersion)
        } else if let availableVersion {
            self = .available(availableVersion)
        } else if let lastChecked {
            self = .checked(lastChecked)
        } else {
            self = .notChecked
        }
    }

    var version: String? {
        switch self {
        case let .available(version), let .readyToInstall(version): version
        case .notChecked, .checked: nil
        }
    }

    func status(bundle: Bundle, locale: Locale, calendar: Calendar = .current) -> String {
        func text(_ key: String) -> String {
            bundle.localizedString(forKey: "softwareUpdate." + key, value: nil, table: "SettingsAbout")
        }
        switch self {
        case .notChecked: return text("neverChecked")
        case let .available(version): return String(format: text("available"), version)
        case let .readyToInstall(version): return String(format: text("readyToInstall"), version)
        case let .checked(date):
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            // 相対表記は今日と昨日だけにし、それ以前は日付と時刻を示す。
            formatter.doesRelativeDateFormatting = calendar.isDateInToday(date) || calendar.isDateInYesterday(date)
            return String(format: text("lastChecked"), formatter.string(from: date))
        }
    }

    static func dateLocale(language: String, locale: Locale) -> Locale {
        var components = Locale.Components(identifier: locale.identifier)
        components.languageComponents.languageCode = Locale.LanguageCode(language)
        components.hourCycle = locale.hourCycle
        return Locale(components: components)
    }
}
