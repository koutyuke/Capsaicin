import Foundation
import Testing

private final class BundleLocator: NSObject {}

func localizedAppBundle(_ language: String) throws -> Bundle {
    let products = Bundle(for: BundleLocator.self).bundleURL.deletingLastPathComponent()
    let app = try #require(Bundle(url: products.appending(path: "Capsaicin.app")))
    let resources = try #require(app.resourceURL)
    return try #require(Bundle(url: resources.appending(path: "\(language).lproj")))
}

@Test("SPEC-UI-011 アプリは英語を開発言語にしたメニューバー専用のバンドルである")
func menuBarApplicationBundle() throws {
    let products = Bundle(for: BundleLocator.self).bundleURL.deletingLastPathComponent()
    let app = try #require(Bundle(url: products.appending(path: "Capsaicin.app")))
    #expect(app.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true)
    #expect(app.developmentLocalization == "en")
    #if DEBUG
        #expect(app.bundleIdentifier == "io.github.koutyuke.capsaicin.debug")
    #else
        #expect(app.bundleIdentifier == "io.github.koutyuke.capsaicin")
    #endif
    for language in ["en", "ja"] {
        for table in localizationTables {
            #expect(app.url(forResource: table, withExtension: "strings", subdirectory: "\(language).lproj") != nil)
        }
    }
    for (preferences, expected) in [(["en"], "en"), (["ja"], "ja"), (["fr"], "en")] {
        #expect(Bundle.preferredLocalizations(from: app.localizations, forPreferences: preferences).first == expected)
    }
}

private let localizationTables = [
    "App", "MenuBar", "HUD", "SettingsAbout", "SettingsControls", "SettingsGeneral",
    "SettingsHelper", "SettingsLed", "SettingsSleep",
]

@Test("SPEC-UI-011 全テーブルは英語と日本語で同じキーを持ち、値が空でない")
func localizedTableKeys() throws {
    let products = Bundle(for: BundleLocator.self).bundleURL.deletingLastPathComponent()
    let app = try #require(Bundle(url: products.appending(path: "Capsaicin.app")))
    let resources = try #require(app.resourceURL)
    for table in localizationTables {
        var keys: [Set<String>] = []
        for language in ["en", "ja"] {
            let url = resources.appending(path: "\(language).lproj/\(table).strings")
            let values = try #require(PropertyListSerialization.propertyList(
                from: Data(contentsOf: url), format: nil,
            ) as? [String: String])
            #expect(!values.isEmpty)
            for (key, value) in values {
                #expect(!value.isEmpty, "\(language).lproj/\(table).strings: \(key)")
            }
            keys.append(Set(values.keys))
        }
        #expect(keys[0] == keys[1])
    }
}

@Test("SPEC-UI-011 終了時のアラートは指定の英語と既存の日本語を表示する", arguments: ["en", "ja"])
func terminationAlertResources(language: String) throws {
    let bundle = try localizedAppBundle(language)
    let expected = [
        "title": language == "en" ? "Some changes couldn’t be undone" : "一部の制御を元に戻せませんでした",
        "message": language == "en"
            ? "Some sleep or LED changes are still in effect. Capsaicin will undo them the next time it opens."
            : "スリープまたは LED の制御が残っています。次に Capsaicin を起動したときに戻し直します。",
        "button": "OK",
    ]
    for (suffix, value) in expected {
        #expect(bundle
            .localizedString(forKey: "alert.terminationIncomplete." + suffix, value: nil, table: "App") == value)
    }
}

@Test("SPEC-CLI-007 SPEC-CLI-008 埋め込んだ実行ファイルは不正な引数を拒否し、CLI のヘルプは成功する")
func embeddedExecutablesHandleArguments() throws {
    let products = Bundle(for: BundleLocator.self).bundleURL.deletingLastPathComponent()
    for name in ["capsaicin"] {
        for arguments in [[], ["--help"], ["unexpected", "argument"]] {
            let process = Process()
            let output = Pipe()
            let error = Pipe()
            process.executableURL = products.appending(path: "Capsaicin.app/Contents/Helpers/\(name)")
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = error
            try process.run()
            let standardOutput = output.fileHandleForReading.readDataToEndOfFile()
            let standardError = error.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            #expect(process.terminationReason == .exit)
            if arguments == ["--help"] {
                #expect(process.terminationStatus == 0)
                #expect(standardError.isEmpty)
                #expect(String(data: standardOutput, encoding: .utf8) == CLIOutput.help.standardOutput)
            } else {
                #expect(process.terminationStatus == 64)
                #expect(standardOutput.isEmpty)
                let reason = arguments.isEmpty ? "missing command" : "unknown command \"unexpected\""
                #expect(String(data: standardError, encoding: .utf8)
                    == "error: " + reason + "\nRun 'capsaicin --help' for usage.\n")
            }
        }
    }
}

@Test("SPEC-HLP-002 SMAppService 用の定義は構成ごとのサービスだけを公開する")
func bundledDaemonDefinition() throws {
    let products = Bundle(for: BundleLocator.self).bundleURL.deletingLastPathComponent()
    let app = try #require(Bundle(url: products.appending(path: "Capsaicin.app")))
    let identifier = try #require(app.bundleIdentifier)
    let directory = app.bundleURL.appending(path: "Contents/Library/LaunchDaemons")
    let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    let label = identifier + ".helper"
    #expect(files == [label + ".plist"])
    let plist = try #require(PropertyListSerialization.propertyList(
        from: Data(contentsOf: directory.appending(path: label + ".plist")), format: nil,
    ) as? [String: Any])
    #expect(Set(plist.keys) == ["Label", "BundleProgram", "MachServices", "RunAtLoad"])
    #expect(plist["Label"] as? String == label)
    #expect(plist["BundleProgram"] as? String == "Contents/Helpers/capsaicin-helper")
    #expect(plist["MachServices"] as? [String: Bool] == [label: true])
    #expect(plist["RunAtLoad"] as? Bool == true)
}

@Test("SPEC-LCY-003 クラッシュ時にアプリを起動し直す agent の定義をバンドルに含めない")
func noBundledAgentDefinition() throws {
    let products = Bundle(for: BundleLocator.self).bundleURL.deletingLastPathComponent()
    let app = try #require(Bundle(url: products.appending(path: "Capsaicin.app")))
    let directory = app.bundleURL.appending(path: "Contents/Library/LaunchAgents")
    #expect(!FileManager.default.fileExists(atPath: directory.path))
}

@Test("埋め込んだ実行ファイルの署名識別子は固定される")
func embeddedSigningIdentifiers() throws {
    let products = Bundle(for: BundleLocator.self).bundleURL.deletingLastPathComponent()
    for (name, identifier) in [
        ("capsaicin", "io.github.koutyuke.capsaicin.cli"),
        ("capsaicin-helper", "io.github.koutyuke.capsaicin.helper"),
    ] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/codesign")
        process.arguments = [
            "--display",
            "--verbose=2",
            products.appending(path: "Capsaicin.app/Contents/Helpers/\(name)").path,
        ]
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let description = try #require(String(data: data, encoding: .utf8))
        #expect(process.terminationStatus == 0)
        #expect(description.contains("Identifier=\(identifier)\n"))
    }
}
