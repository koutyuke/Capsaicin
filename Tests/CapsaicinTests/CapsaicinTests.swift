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

@Test("埋め込んだ実行ファイルは不正な引数を終了コード64で拒否する")
func embeddedExecutablesRejectArguments() throws {
    let products = Bundle(for: BundleLocator.self).bundleURL.deletingLastPathComponent()
    for name in ["capsaicin", "capsaicin-helper"] {
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
            #expect(process.terminationStatus == 64)
            if name == "capsaicin" {
                #expect(standardOutput.isEmpty)
                let diagnostic = try #require(String(data: standardError, encoding: .utf8))
                // native CLI の実行パス解決と、アプリからのカタログ読み込みも確かめる。
                #expect(diagnostic.contains("使い方:"))
            }
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
