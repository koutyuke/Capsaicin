import Foundation
import Testing

@MainActor
struct AboutResourcesTests {
    @Test("SPEC-SET-008 ライセンスの全文を省略せずアプリに同梱する")
    func licenseResources() throws {
        let products = Bundle(for: AboutResourceLocator.self).bundleURL.deletingLastPathComponent()
        let app = try #require(Bundle(url: products.appending(path: "Capsaicin.app")))
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        for (name, original) in [
            ("Capsaicin-LICENSE", "LICENSE"),
            ("KeyboardShortcuts-LICENSE", "Sources/Capsaicin/Hotkey/KeyboardShortcuts-LICENSE.txt"),
            ("Sparkle-LICENSE", ".build/spm/checkouts/Sparkle/LICENSE"),
        ] {
            let resource = try #require(app.url(forResource: name, withExtension: "txt"))
            #expect(try Data(contentsOf: resource) == Data(contentsOf: root.appending(path: original)))
        }
        #expect(SettingsLicense.allCases.map(\.rawValue) == ["Capsaicin", "KeyboardShortcuts", "Sparkle"])
        for license in SettingsLicense.allCases {
            let resource = try #require(app.url(forResource: license.rawValue + "-LICENSE", withExtension: "txt"))
            #expect(try license.text(in: app) == String(contentsOf: resource, encoding: .utf8))
        }
        #expect(SettingsLicense.sparkle.source?.contains("2.10.1") == true)
        #expect(SettingsLicense.sparkle.source?.contains("https://github.com/sparkle-project/Sparkle") == true)
    }

    @Test("SPEC-SET-007 SPEC-SET-008 SPEC-UI-011 更新とリンクの文言を英語と日本語で持つ", arguments: ["en", "ja"])
    func catalogs(language: String) throws {
        let bundle = try localizedAppBundle(language)
        for key in ["updates.group.title", "autoUpdate.label", "autoUpdate.option.off", "autoUpdate.option.check",
                    "autoUpdate.option.install", "autoUpdate.help", "softwareUpdate.label",
                    "softwareUpdate.lastChecked",
                    "softwareUpdate.neverChecked", "softwareUpdate.available", "softwareUpdate.readyToInstall",
                    "softwareUpdate.check.button", "softwareUpdate.check.a11y", "softwareUpdate.update.button",
                    "softwareUpdate.update.a11y", "links.group.title", "website.label", "website.a11y",
                    "licenses.label"]
        {
            #expect(bundle.localizedString(forKey: key, value: nil, table: "SettingsAbout") != key)
        }
        for key in ["menu.update.available", "menu.update.available.subtitle"] {
            #expect(MenuContent.text(key, bundle: bundle) != key)
        }
    }
}

private final class AboutResourceLocator: NSObject {}
