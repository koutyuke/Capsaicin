import CapsaicinIPC
import Foundation
import Testing

final class CLIApplicationFixture {
    let root: URL
    let app: URL
    let executable: URL

    init(identifier: String = "io.github.koutyuke.capsaicin.debug", packageType: String = "APPL") throws {
        let repository = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        root = repository.appending(path: ".build/tmp/cli-" + UUID().uuidString)
        app = root.appending(path: "名前を変えた App.app")
        executable = app.appending(path: "Contents/Helpers/capsaicin")
        let manager = FileManager.default
        try manager.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try manager.createDirectory(at: app.appending(path: "Contents/MacOS"), withIntermediateDirectories: true)
        for url in [executable, app.appending(path: "Contents/MacOS/Capsaicin")] {
            try Data("fixture, not executable code".utf8).write(to: url)
            try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        }
        let info: [String: String] = [
            "CFBundleIdentifier": identifier, "CFBundlePackageType": packageType,
            "CFBundleExecutable": "Capsaicin", "CFBundleDevelopmentRegion": "ja",
        ]
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: app.appending(path: "Contents/Info.plist"))
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func resolve() throws -> CLIApplication {
        try CLIApplication.resolve(executablePath: executable.path)
    }
}

struct CLIApplicationTests {
    @Test("SPEC-CLI-004 リネーム・空白を含む app と CLI への symlink を実パスから解決する", arguments: [false, true])
    func renamedAndSymlink(link: Bool) throws {
        let fixture = try CLIApplicationFixture()
        let path: URL
        if link {
            path = fixture.root.appending(path: "shortcut")
            try FileManager.default.createSymbolicLink(at: path, withDestinationURL: fixture.executable)
        } else {
            path = fixture.executable
        }
        let app = try CLIApplication.resolve(executablePath: path.path)
        #expect(app.url.path == fixture.app.resolvingSymlinksInPath().path)
        #expect(app.namespace == .debug)
    }

    @Test("SPEC-CLI-004 Release ID だけが本番 namespace を選ぶ")
    func releaseNamespace() throws {
        let fixture = try CLIApplicationFixture(identifier: "io.github.koutyuke.capsaicin")
        #expect(try fixture.resolve().namespace == .release)
    }

    @Test(
        "SPEC-CLI-004 単独コピー・別 ID・非 APPL・外部の本体を拒む",
        arguments: ["standalone", "wrongID", "wrongType", "externalMain", "missingMain"],
    )
    func invalidBundle(kind: String) throws {
        let fixture = try CLIApplicationFixture(
            identifier: kind == "wrongID" ? "example.other" : "io.github.koutyuke.capsaicin.debug",
            packageType: kind == "wrongType" ? "BNDL" : "APPL",
        )
        var path = fixture.executable
        if kind == "standalone" {
            path = fixture.root.appending(path: "capsaicin")
            try FileManager.default.copyItem(at: fixture.executable, to: path)
        }
        if kind == "externalMain" || kind == "missingMain" {
            let main = fixture.app.appending(path: "Contents/MacOS/Capsaicin")
            let outside = fixture.root.appending(path: "outside")
            try FileManager.default.moveItem(at: main, to: outside)
            if kind ==
                "externalMain"
            {
                try FileManager.default.createSymbolicLink(at: main, withDestinationURL: outside)
            }
        }
        #expect(throws: (any Error).self) { try CLIApplication.resolve(executablePath: path.path) }
    }
}
