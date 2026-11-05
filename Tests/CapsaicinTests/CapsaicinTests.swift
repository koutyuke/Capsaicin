import Foundation
import Testing

private final class BundleLocator: NSObject {}

@Test("アプリはメニューバー専用のバンドルである")
func menuBarApplicationBundle() throws {
    let products = Bundle(for: BundleLocator.self).bundleURL.deletingLastPathComponent()
    let app = try #require(Bundle(url: products.appending(path: "Capsaicin.app")))
    #expect(app.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true)
    #expect(app.developmentLocalization == "ja")
    #if DEBUG
        #expect(app.bundleIdentifier == "io.github.koutyuke.capsaicin.debug")
    #else
        #expect(app.bundleIdentifier == "io.github.koutyuke.capsaicin")
    #endif
    #expect(app.url(forResource: "MenuBar", withExtension: "strings", subdirectory: "ja.lproj") != nil)
}

@Test("埋め込んだ雛形の実行ファイルはすべての入力を拒否する")
func embeddedExecutablesRejectArguments() throws {
    let products = Bundle(for: BundleLocator.self).bundleURL.deletingLastPathComponent()
    for name in ["capsaicin", "capsaicin-helper"] {
        for arguments in [[], ["--help"], ["unexpected", "argument"]] {
            let process = Process()
            process.executableURL = products.appending(path: "Capsaicin.app/Contents/Helpers/\(name)")
            process.arguments = arguments
            try process.run()
            process.waitUntilExit()
            #expect(process.terminationReason == .exit)
            #expect(process.terminationStatus == 64)
        }
    }
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
