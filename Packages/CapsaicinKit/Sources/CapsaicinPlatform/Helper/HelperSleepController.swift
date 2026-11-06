import CapsaicinCore
import Foundation

public enum HelperInstallationState: Sendable {
    case notInstalled, partial, installed
}

enum HelperError: Error, Equatable {
    case invalidSleepDisabled
    case invalidInstallerInput
    case unexpectedInstallerOutput
}

typealias HelperCommand = @Sendable (String, [String], TimeInterval) throws -> Data

struct HelperPaths: Sendable {
    let debug: Bool
    static var current: Self {
        #if DEBUG
            Self(debug: true)
        #else
            Self(debug: false)
        #endif
    }

    var label: String {
        "io.github.koutyuke.capsaicin.helper" + (debug ? ".debug" : "")
    }

    var helper: String {
        "/Library/PrivilegedHelperTools/\(label)"
    }

    var sudoers: String {
        "/etc/sudoers.d/capsaicin" + (debug ? "_debug" : "")
    }

    var daemon: String {
        "/Library/LaunchDaemons/\(label).plist"
    }

    var files: [String] {
        [helper, sudoers, daemon]
    }
}

@MainActor
public final class HelperSleepController: HelperSleepControlling {
    private let paths: HelperPaths
    private let exists: (String) -> Bool
    private let run: HelperCommand

    public convenience init() {
        self.init(runner: CommandRunner(executable: "/usr/bin/pmset", arguments: ["-g"], outputLimit: 65536))
    }

    convenience init(runner: CommandRunner) {
        self.init(run: { try runner.run(executable: $0, arguments: $1, timeout: $2) })
    }

    init(paths: HelperPaths = .current,
         exists: @escaping (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
         run: @escaping HelperCommand)
    {
        self.paths = paths
        self.exists = exists
        self.run = run
    }

    public var installationState: HelperInstallationState {
        let count = paths.files.filter(exists).count
        return count == 0 ? .notInstalled : count == 3 ? .installed : .partial
    }

    public var isHelperInstalled: Bool {
        installationState == .installed
    }

    public func readSleepDisabled() throws -> Bool {
        let data = try run("/usr/bin/pmset", ["-g"], 5)
        guard let output = String(data: data, encoding: .utf8) else { throw HelperError.invalidSleepDisabled }
        let lines = output.split(whereSeparator: \.isNewline).map { $0.split(whereSeparator: \.isWhitespace) }
            .filter { $0.first == "SleepDisabled" }
        guard lines.count == 1, let fields = lines.first, fields.count == 2,
              fields[1] == "0" || fields[1] == "1" else { throw HelperError.invalidSleepDisabled }
        return fields[1] == "1"
    }

    public func turnOn() throws {
        _ = try run("/usr/bin/sudo", ["-n", paths.helper, "on"], 5)
    }

    public func turnOff() throws {
        _ = try run("/usr/bin/sudo", ["-n", paths.helper, "off"], 5)
    }
}
