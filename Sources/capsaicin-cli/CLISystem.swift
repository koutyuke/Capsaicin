import AppKit
import CapsaicinIPC
import Foundation

@MainActor
struct CLISystemConnector: CLIConnecting {
    func connect(namespace: IPCEndpoint.Namespace, timeout: Double) async throws -> any CLIConnected {
        let connection = try await IPCClient(endpoint: IPCEndpoint(namespace: namespace)).connect(timeout: timeout)
        return CLISystemConnection(connection: connection)
    }
}

@MainActor
private struct CLISystemConnection: CLIConnected {
    let connection: IPCConnection
    func request(_ request: IPCRequest) async throws -> IPCResponse {
        try await connection.request(request)
    }

    func close() async {
        await connection.close()
    }
}

@MainActor
struct CLISystemLauncher: CLILaunching {
    func launch(_ applicationURL: URL, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: Self.configuration()) { _, error in
            let succeeded = error == nil
            Task { @MainActor in completion(succeeded) }
        }
    }

    static func configuration() -> NSWorkspace.OpenConfiguration {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.promptsUserIfNeeded = false
        configuration.allowsRunningApplicationSubstitution = false
        configuration.createsNewApplicationInstance = false
        return configuration
    }
}

@MainActor
struct CLISystemClock: CLIClock {
    var now: Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }

    func sleep(seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}
