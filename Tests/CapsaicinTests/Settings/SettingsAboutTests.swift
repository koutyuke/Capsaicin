import AppKit
import SwiftUI
import Testing

@MainActor
struct SettingsAboutTests {
    @Test("SPEC-SET-007 インストール待ち、新しい版、最終確認日時の順で4状態を決める")
    func updateStates() {
        let date = Date(timeIntervalSince1970: 0)
        #expect(SettingsUpdateState(isEnabled: true, lastChecked: nil, availableVersion: nil,
                                    installationVersion: nil) == .notChecked)
        #expect(SettingsUpdateState(isEnabled: true, lastChecked: date, availableVersion: nil,
                                    installationVersion: nil) == .checked(date))
        #expect(SettingsUpdateState(isEnabled: true, lastChecked: date, availableVersion: "1.2.0",
                                    installationVersion: nil) == .available("1.2.0"))
        #expect(SettingsUpdateState(isEnabled: true, lastChecked: date, availableVersion: "1.3.0",
                                    installationVersion: "1.2.0") == .readyToInstall("1.2.0"))
        #expect(SettingsUpdateState(isEnabled: false, lastChecked: date, availableVersion: "1.3.0",
                                    installationVersion: "1.2.0") == .notChecked)
        #expect(SettingsUpdateState.notChecked.version == nil)
        #expect(SettingsUpdateState.checked(date).version == nil)
        #expect(SettingsUpdateState.available("1.2.0").version == "1.2.0")
        #expect(SettingsUpdateState.readyToInstall("1.2.0").version == "1.2.0")
    }

    @Test("SPEC-SET-007 状態は各言語のカタログと表示する版に対応する", arguments: ["en", "ja"])
    func updateStateText(language: String) throws {
        let bundle = try localizedAppBundle(language)
        let locale = Locale(identifier: language)
        for (state, key, version) in [
            (SettingsUpdateState.notChecked, "neverChecked", ""),
            (.available("1.2.0"), "available", "1.2.0"),
            (.readyToInstall("1.3.0"), "readyToInstall", "1.3.0"),
        ] {
            let format = bundle.localizedString(forKey: "softwareUpdate." + key, value: nil, table: "SettingsAbout")
            #expect(state.status(bundle: bundle, locale: locale) == String(format: format, version))
        }
    }

    @Test("SPEC-SET-007 SPEC-UI-012 日付は表示言語、地域と時刻は OS の設定を保つ",
          arguments: ["en", "ja"], ["en_US@hours=h23", "ja_JP@hours=h12"])
    func checkDate(language: String, localeID: String) throws {
        let bundle = try localizedAppBundle(language)
        let systemLocale = Locale(identifier: localeID)
        let locale = SettingsUpdateState.dateLocale(language: language, locale: systemLocale)
        #expect(locale.language.languageCode?.identifier == language)
        #expect(locale.region == systemLocale.region)
        #expect(locale.hourCycle == systemLocale.hourCycle)
        let calendar = Calendar.current
        let today = try #require(calendar.date(bySettingHour: 15, minute: 53, second: 0, of: Date()))
        for daysAgo in [0, 1, 3] {
            let date = try #require(calendar.date(byAdding: .day, value: -daysAgo, to: today))
            let text = SettingsUpdateState.checked(date).status(bundle: bundle, locale: locale, calendar: calendar)
            #expect(text.contains(localeID.contains("h23") ? "15:53" : "3:53"))
            if daysAgo < 2 {
                #expect(text.contains(language == "en" ? (daysAgo == 0 ? "Today" : "Yesterday")
                        : (daysAgo == 0 ? "今日" : "昨日")))
            } else {
                #expect(!text.contains(language == "en" ? "Today" : "今日"))
                #expect(!text.contains(language == "en" ? "Yesterday" : "昨日"))
            }
        }
    }
}

extension SettingsTests {
    @Test("SPEC-SET-008 ライセンスのシートを完了・Return・Esc で閉じても親のタイトルと枠を変えない",
          arguments: ["done", "return", "escape"])
    func licenseSheet(dismissal: String) async throws {
        _ = NSApplication.shared
        let defaults = try #require(UserDefaults(suiteName: "AboutLicenseView-" + UUID().uuidString))
        defer { defaults.removeObject(forKey: "settingsSection") }
        let selection = SettingsSelection(defaults: defaults)
        selection.section = .about
        let app = try appBundle()
        let window = SettingsWindowController.makeWindow(rootView: LicenseSheetHost(content: SettingsView(
            model: makeModel(), hotkey: HotkeyController(save: { _ in true }), selection: selection,
            quit: {}, bundle: app,
        ), bundle: app), selection: selection)
        defer { window.close() }
        // SwiftUI のシートには表示中の親が必要なため、テスト用ウインドウだけを画面外に配置する。
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderBack(nil)
        await layout(window)
        let frame = window.frame
        let contentRect = window.contentLayoutRect
        let closeButton = try #require(window.standardWindowButton(.closeButton))
        let closeFrame = closeButton.frame
        let toolbar = window.toolbar
        let sheet = try #require(window.attachedSheet)
        defer { window.endSheet(sheet) }
        await layout(sheet)
        let view = try #require(sheet.contentView)
        #expect(view.frame.size == NSSize(width: 540, height: 400))
        let done = try #require(accessibilityDescendants(view).first {
            $0.accessibilityRole?() == .button && $0.accessibilityLabel?()
                == app.localizedString(forKey: "licenses.done", value: nil, table: "SettingsAbout")
        })
        if dismissal == "done" {
            #expect(done.accessibilityPerformPress?() == true)
        } else {
            let character = dismissal == "return" ? "\r" : "\u{1b}"
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: sheet.windowNumber, context: nil, characters: character,
                charactersIgnoringModifiers: character, isARepeat: false,
                keyCode: dismissal == "return" ? 36 : 53,
            ))
            #expect(sheet.performKeyEquivalent(with: event))
        }
        await layout(window)
        #expect(window.attachedSheet == nil)
        #expect(selection.section == .about)
        #expect(window.title == SettingsSection.about.title)
        #expect(window.frame == frame && window.contentLayoutRect == contentRect)
        #expect(closeButton.frame == closeFrame)
        #expect(window.toolbar === toolbar && window.toolbarStyle == .unified)
        #expect(window.toolbar?.items.isEmpty == true)
    }
}

private struct LicenseSheetHost<Content: View>: View {
    let content: Content
    let bundle: Bundle
    @State private var isPresented = true

    var body: some View {
        content.sheet(isPresented: $isPresented) {
            SettingsLicensesView(bundle: bundle).environment(\.accessibilityEnabled, true)
        }
    }
}
