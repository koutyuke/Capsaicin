import CapsaicinCore
import Foundation

enum HelperError: Error, Equatable {
    case invalidSleepDisabled
}

typealias HelperCommand = @Sendable (String, [String], TimeInterval) throws -> Data

@MainActor
public final class HelperSleepController: HelperSleepControlling {
    private let state: () -> HelperInstallationState
    private let run: HelperCommand
    private let client: HelperXPCClient

    public convenience init(registration: HelperRegistration = HelperRegistration()) {
        let runner = CommandRunner(executable: "/usr/bin/pmset", arguments: ["-g"], outputLimit: 65536)
        self.init(state: { registration.state },
                  run: { try runner.run(executable: $0, arguments: $1, timeout: $2) })
    }

    init(state: @escaping () -> HelperInstallationState = { .notInstalled },
         client: HelperXPCClient = HelperXPCClient(),
         run: @escaping HelperCommand)
    {
        self.state = state
        self.client = client
        self.run = run
    }

    public var installationState: HelperInstallationState {
        state()
    }

    public var isHelperInstalled: Bool {
        installationState == .installed
    }

    public var isHelperAwaitingApproval: Bool {
        installationState == .requiresApproval
    }

    public var onConnectionLost: ((HelperConnectionLoss) -> Void)? {
        get { client.onConnectionLost }
        set { client.onConnectionLost = newValue }
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
        try client.request("on")
    }

    public func turnOff() throws {
        try client.request("off")
    }

    public func closeConnection() {
        client.closeConnection()
    }
}
