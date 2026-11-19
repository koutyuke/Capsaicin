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
            let text = try license.text(in: app)
            #expect(try text == String(contentsOf: resource, encoding: .utf8))
            #expect(SettingsLicense.reflowed(text).split(whereSeparator: \.isWhitespace)
                == text.split(whereSeparator: \.isWhitespace))
        }
        // 表示する版は、組み込んだ Sparkle から読み、project.yml で固定した版と一致する。
        let project = try String(contentsOf: root.appending(path: "project.yml"), encoding: .utf8)
        let pinned = try #require(project.firstMatch(of: /Sparkle:\n.*\n\s+exactVersion: (\S+)/)?.1)
        #expect(SettingsLicense.sparkle.source?.hasPrefix("Sparkle \(pinned)\n") == true)
        #expect(SettingsLicense.sparkle.source?.contains("https://github.com/sparkle-project/Sparkle") == true)
    }

    @Test("SPEC-SET-008 段落の中の改行だけを空白にして、列挙・番号付きの項目・空行の改行を残す")
    func reflowedLicense() {
        let text = """
        Copyright (c) 2006 A.
        Copyright (c) 2009 B.

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software.
        are met:
        1. Redistributions of source code must retain the above copyright
           notice, this list of conditions.
        2. Redistributions in binary form must reproduce the above copyright

        """
        #expect(SettingsLicense.reflowed(text) == """
        Copyright (c) 2006 A.
        Copyright (c) 2009 B.

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software.
        are met:
        1. Redistributions of source code must retain the above copyright notice, this list of conditions.
        2. Redistributions in binary form must reproduce the above copyright

        """)
    }

    @Test("SPEC-SET-007 SPEC-SET-008 SPEC-UI-011 更新とリンクの文言を英語と日本語で持つ", arguments: ["en", "ja"])
    func catalogs(language: String) throws {
        let bundle = try localizedAppBundle(language)
        for key in ["updates.group.title", "autoUpdate.label", "autoUpdate.option.off", "autoUpdate.option.check",
                    "autoUpdate.option.install", "softwareUpdate.label", "softwareUpdate.debugDisabled",
                    "softwareUpdate.lastChecked",
                    "softwareUpdate.neverChecked", "softwareUpdate.available", "softwareUpdate.readyToInstall",
                    "softwareUpdate.check.button", "softwareUpdate.check.a11y", "softwareUpdate.update.button",
                    "softwareUpdate.update.a11y", "links.group.title", "website.label", "website.a11y",
                    "licenses.label", "licenses.done"]
        {
            #expect(bundle.localizedString(forKey: key, value: nil, table: "SettingsAbout") != key)
        }
        #expect(bundle.localizedString(forKey: "licenses.done", value: nil, table: "SettingsAbout")
            == (language == "en" ? "Done" : "完了"))
        for key in ["menu.update.available", "menu.update.available.subtitle"] {
            #expect(MenuContent.text(key, bundle: bundle) != key)
        }
    }
}

private final class AboutResourceLocator: NSObject {}
