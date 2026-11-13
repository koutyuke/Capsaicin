import CapsaicinIPC
import Darwin
import Foundation
import MachO

struct CLIApplication {
    let url: URL
    let namespace: IPCEndpoint.Namespace

    static func current() throws -> CLIApplication {
        var size: UInt32 = 0
        var probe: CChar = 0
        _ = _NSGetExecutablePath(&probe, &size)
        guard size > 0 else { throw CLIApplicationError.invalidBundle }
        var buffer = [CChar](repeating: 0, count: Int(size))
        guard _NSGetExecutablePath(&buffer, &size) == 0 else { throw CLIApplicationError.invalidBundle }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        guard let path = String(bytes: bytes, encoding: .utf8) else { throw CLIApplicationError.invalidBundle }
        return try resolve(executablePath: path)
    }

    static func resolve(executablePath: String) throws -> CLIApplication {
        let executable = try canonical(executablePath)
        let helpers = executable.deletingLastPathComponent()
        let contents = helpers.deletingLastPathComponent()
        let app = contents.deletingLastPathComponent()
        guard executable.lastPathComponent == "capsaicin", helpers.lastPathComponent == "Helpers",
              contents.lastPathComponent == "Contents", app.pathExtension == "app"
        else { throw CLIApplicationError.invalidBundle }
        let data = try Data(contentsOf: contents.appending(path: "Info.plist"))
        guard let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              info["CFBundlePackageType"] as? String == "APPL",
              let identifier = info["CFBundleIdentifier"] as? String,
              let mainName = info["CFBundleExecutable"] as? String,
              !mainName.isEmpty, mainName != ".", mainName != "..", !mainName.contains("/"), !mainName.contains("\0")
        else { throw CLIApplicationError.invalidBundle }
        let namespace: IPCEndpoint.Namespace
        switch identifier {
        case "io.github.koutyuke.capsaicin": namespace = .release
        case "io.github.koutyuke.capsaicin.debug": namespace = .debug
        default: throw CLIApplicationError.invalidBundle
        }
        let mainDirectory = contents.appending(path: "MacOS")
        let main = try canonical(mainDirectory.appending(path: mainName).path)
        guard main.deletingLastPathComponent().path == mainDirectory.path,
              FileManager.default.isExecutableFile(atPath: main.path),
              FileManager.default.isExecutableFile(atPath: executable.path),
              try FileManager.default.attributesOfItem(atPath: main.path)[.type] as? FileAttributeType == .typeRegular
        else { throw CLIApplicationError.invalidBundle }
        return CLIApplication(url: app, namespace: namespace)
    }

    private static func canonical(_ path: String) throws -> URL {
        guard let resolved = realpath(path, nil) else { throw CLIApplicationError.invalidBundle }
        defer { free(resolved) }
        return URL(filePath: String(cString: resolved))
    }
}

enum CLIApplicationError: Error { case invalidBundle }
