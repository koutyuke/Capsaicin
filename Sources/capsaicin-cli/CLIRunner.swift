import CapsaicinIPC
import Foundation

protocol CLIConnected: Sendable {
    func request(_ request: IPCRequest) async throws -> IPCResponse
    func close() async
}

@MainActor
protocol CLIConnecting {
    func connect(namespace: IPCEndpoint.Namespace, timeout: Double) async throws -> any CLIConnected
}

@MainActor
protocol CLILaunching {
    /// completion の到着や最初のプロセスの生存を readiness とみなさない。
    func launch(_ applicationURL: URL, completion: @escaping @MainActor @Sendable (Bool) -> Void)
}

@MainActor
protocol CLIClock {
    var now: Double { get }
    func sleep(seconds: Double) async throws
}

enum CLIRunnerError: Error { case launchFailed }

@MainActor
struct CLIRunner {
    var resolve: () throws -> CLIApplication
    var connector: any CLIConnecting
    var launcher: any CLILaunching
    var clock: any CLIClock
    var readinessTimeout: Double = 10
    var retryInterval: Double = 0.1

    func run(_ arguments: [String]) async -> CLIOutput {
        let command: IPCCommand
        do { command = try CLIArguments.parse(arguments) }
        catch {
            guard let application = try? resolve() else {
                // バンドルを持たないコピーにだけ必要な、最小限の bootstrap 診断。
                return CLIOutput(exitCode: .usage, standardError: "capsaicin: 引数が正しくありません。on、off、status を指定してください。\n")
            }
            return CLIOutput.usage(error, text: CLIText(bundle: application.bundle))
        }
        let application: CLIApplication
        do { application = try resolve() }
        catch {
            return CLIOutput(exitCode: .unavailable, standardError: "capsaicin: アプリ内のコマンドから実行してください。\n")
        }
        let text = CLIText(bundle: application.bundle)
        do {
            let connection = try await readyConnection(application)
            // この境界より後の失敗には起動も再接続も行わない。
            do {
                let response = try await connection.request(IPCRequest(command: command))
                await connection.close()
                return CLIOutput.response(response, text: text)
            } catch {
                await connection.close()
                throw error
            }
        } catch { return CLIOutput.failure(error, text: text) }
    }

    private func readyConnection(_ application: CLIApplication) async throws -> any CLIConnected {
        do { return try await connector.connect(namespace: application.namespace, timeout: 0.25) }
        catch IPCTransportError.unavailable { /* 起動前に要求はまだ送っていない。 */ }

        let deadline = clock.now + readinessTimeout
        let launch = CLILaunchResult()
        launcher.launch(application.url) { succeeded in launch.failed = !succeeded }
        while clock.now < deadline {
            try Task.checkCancellation()
            if launch.failed {
                throw CLIRunnerError.launchFailed
            }
            do {
                let connection = try await connector.connect(
                    namespace: application.namespace,
                    timeout: min(0.25, deadline - clock.now),
                )
                if clock.now >= deadline {
                    await connection.close()
                    throw IPCTransportError.timedOut
                }
                return connection
            } catch IPCTransportError.unavailable { /* この接続では1バイトも送っていない。 */ }
            let remaining = deadline - clock.now
            if remaining > 0 {
                try await clock.sleep(seconds: min(retryInterval, remaining))
            }
        }
        throw IPCTransportError.timedOut
    }
}

@MainActor
private final class CLILaunchResult {
    var failed = false
}
