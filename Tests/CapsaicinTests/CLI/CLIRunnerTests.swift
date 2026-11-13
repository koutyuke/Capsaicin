import CapsaicinCore
import CapsaicinIPC
import Darwin
import Foundation
import Testing

@MainActor
private final class FakeCLIClock: CLIClock {
    var now: Double = 0
    var sleeps: [Double] = []
    func sleep(seconds: Double) async throws {
        sleeps.append(seconds)
        now += seconds
    }
}

@MainActor
private final class FakeCLIConnection: CLIConnected {
    var requests: [IPCRequest] = []
    var closes = 0
    var response = IPCResponse(
        outcome: .status,
        status: BlockingStatus(session: nil, batteryCondition: nil, misalignments: [:], isRecordUnsaved: false),
    )
    var error: Error?
    func request(_ request: IPCRequest) async throws -> IPCResponse {
        requests.append(request)
        if let error {
            throw error
        }
        return response
    }

    func close() async {
        closes += 1
    }
}

@MainActor
private final class FakeCLIConnector: CLIConnecting {
    var attempts = 0
    var unavailableAttempts = 0
    var error: Error?
    var timeouts: [Double] = []
    var namespaces: [IPCEndpoint.Namespace] = []
    let connection = FakeCLIConnection()
    var onConnect: (() -> Void)?

    func connect(namespace: IPCEndpoint.Namespace, timeout: Double) async throws -> any CLIConnected {
        attempts += 1
        timeouts.append(timeout)
        namespaces.append(namespace)
        onConnect?()
        if let error {
            throw error
        }
        if attempts <= unavailableAttempts {
            throw IPCTransportError.unavailable(ENOENT)
        }
        return connection
    }
}

@MainActor
private final class FakeCLILauncher: CLILaunching {
    var urls: [URL] = []
    var callbackResult: Bool?
    func launch(_ applicationURL: URL, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        urls.append(applicationURL)
        if let callbackResult {
            completion(callbackResult)
        }
    }
}

@MainActor
struct CLIRunnerTests {
    @Test(
        "SPEC-CLI-007 引数エラーを先に決め、接続も起動もしない",
        arguments: [
            ([String](), "missing command"),
            (["unexpected", "argument"], "unknown command \"unexpected\""),
            (["on", "--for", "0m"], "duration \"0m\" for --for is out of range; use 1m to 24h"),
        ],
    )
    func parseFirst(arguments: [String], reason: String) async {
        let connector = FakeCLIConnector()
        let launcher = FakeCLILauncher()
        var resolutions = 0
        let runner = CLIRunner(
            resolve: { resolutions += 1; throw CLIApplicationError.invalidBundle },
            connector: connector,
            launcher: launcher,
            clock: FakeCLIClock(),
        )
        let output = await runner.run(arguments)
        #expect(output.exitCode == .usage)
        #expect(output.standardError == "error: " + reason + "\nRun 'capsaicin --help' for usage.\n")
        #expect(output.standardOutput.isEmpty)
        #expect(resolutions == 0)
        #expect(connector.attempts == 0)
        #expect(launcher.urls.isEmpty)
    }

    @Test("SPEC-CLI-008 ヘルプを最優先し、バンドル確認・接続・起動をしない",
          arguments: [["--help"], ["-h"], ["on", "--help"], ["status", "-h"], ["on", "--for", "x", "--help"]])
    func helpFirst(arguments: [String]) async {
        let connector = FakeCLIConnector()
        let launcher = FakeCLILauncher()
        var resolutions = 0
        let runner = CLIRunner(
            resolve: { resolutions += 1; throw CLIApplicationError.invalidBundle },
            connector: connector,
            launcher: launcher,
            clock: FakeCLIClock(),
            stdoutColor: true,
            stderrColor: true,
        )
        let output = await runner.run(arguments)
        #expect(output.exitCode == .success)
        #expect(output.standardOutput == CLIOutput.help.standardOutput)
        #expect(output.standardError.isEmpty)
        #expect(resolutions == 0)
        #expect(connector.attempts == 0)
        #expect(launcher.urls.isEmpty)
    }

    @Test("SPEC-CLI-004 有効な引数の単独コピーは69であり、起動しない")
    func validStandalone() async {
        let connector = FakeCLIConnector()
        let launcher = FakeCLILauncher()
        let runner = CLIRunner(
            resolve: { throw CLIApplicationError.invalidBundle },
            connector: connector,
            launcher: launcher,
            clock: FakeCLIClock(),
        )
        let output = await runner.run(["status"])
        #expect(output.exitCode == .unavailable)
        #expect(output.standardOutput.isEmpty)
        #expect(output.standardError == "error: run this command from inside Capsaicin.app\n")
        #expect(connector.attempts == 0)
        #expect(launcher.urls.isEmpty)
    }

    @Test("SPEC-CLI-004 SPEC-LCY-005 起動は1回だけ、callback がなくてもソケットの readiness を待つ", arguments: [false, true])
    func launchOnce(noCallback: Bool) async throws {
        let fixture = try CLIApplicationFixture()
        let connector = FakeCLIConnector()
        connector.unavailableAttempts = 3
        let launcher = FakeCLILauncher()
        launcher.callbackResult = noCallback ? nil : true
        let clock = FakeCLIClock()
        let runner = CLIRunner(resolve: fixture.resolve, connector: connector, launcher: launcher, clock: clock)
        let output = await runner.run(["status"])
        #expect(output.exitCode == .stopped)
        #expect(launcher.urls.map(\.path) == [fixture.app.resolvingSymlinksInPath().path])
        #expect(connector.attempts == 4)
        #expect(connector.connection.requests.map(\.command) == [.status])
        #expect(connector.connection.closes == 1)
        #expect(connector.namespaces.allSatisfy { $0 == .debug })
        #expect(clock.sleeps == [0.1, 0.1])
    }

    @Test("SPEC-CLI-004 起動 callback が来なくても期限で終了し、待ちと接続の期限を残り時間に切る")
    func neverCallbackTimeout() async throws {
        let fixture = try CLIApplicationFixture()
        let connector = FakeCLIConnector()
        connector.unavailableAttempts = 100
        let launcher = FakeCLILauncher()
        let clock = FakeCLIClock()
        let runner = CLIRunner(
            resolve: fixture.resolve,
            connector: connector,
            launcher: launcher,
            clock: clock,
            readinessTimeout: 0.23,
        )
        #expect(await runner.run(["on"]).exitCode == .unavailable)
        #expect(launcher.urls.count == 1)
        #expect(connector.connection.requests.isEmpty)
        #expect(abs(clock.now - 0.23) < 0.00001)
        #expect(abs((connector.timeouts.last ?? 0) - 0.03) < 0.00001)
        #expect(abs((clock.sleeps.last ?? 0) - 0.03) < 0.00001)
    }

    @Test("SPEC-CLI-004 接続に成功しても readiness の期限を越えれば要求を送らない")
    func connectionAfterDeadline() async throws {
        let fixture = try CLIApplicationFixture()
        let connector = FakeCLIConnector()
        let clock = FakeCLIClock()
        connector.unavailableAttempts = 1
        connector.onConnect = {
            if connector.attempts == 2 {
                clock.now = 11
            }
        }
        let runner = CLIRunner(
            resolve: fixture.resolve,
            connector: connector,
            launcher: FakeCLILauncher(),
            clock: clock,
        )
        #expect(await runner.run(["on"]).exitCode == .unavailable)
        #expect(connector.connection.requests.isEmpty)
        #expect(connector.connection.closes == 1)
        connector.onConnect = nil
    }

    @Test(
        "SPEC-CLI-007 権限・認証・通信形式・タイムアウトの接続失敗では起動しない",
        arguments: [IPCTransportError.system(EACCES), .peerRejected, .invalidFrame, .timedOut],
    )
    func noLaunchOnOtherErrors(error: IPCTransportError) async throws {
        let fixture = try CLIApplicationFixture()
        let connector = FakeCLIConnector()
        connector.error = error
        let launcher = FakeCLILauncher()
        let runner = CLIRunner(
            resolve: fixture.resolve,
            connector: connector,
            launcher: launcher,
            clock: FakeCLIClock(),
        )
        #expect(await runner.run(["off"]).exitCode == .unavailable)
        #expect(connector.attempts == 1)
        #expect(launcher.urls.isEmpty)
        #expect(connector.connection.requests.isEmpty)
    }

    @Test("SPEC-CLI-007 送信後に応答を失っても再接続も再送もしない")
    func neverResend() async throws {
        let fixture = try CLIApplicationFixture()
        let connector = FakeCLIConnector()
        connector.connection.error = IPCTransportError.unavailable(ECONNREFUSED)
        let launcher = FakeCLILauncher()
        let runner = CLIRunner(
            resolve: fixture.resolve,
            connector: connector,
            launcher: launcher,
            clock: FakeCLIClock(),
        )
        #expect(await runner.run(["off"]).exitCode == .unavailable)
        #expect(connector.attempts == 1)
        #expect(connector.connection.requests.count == 1)
        #expect(connector.connection.closes == 1)
        #expect(launcher.urls.isEmpty)
    }

    @Test("SPEC-CLI-007 応答のプロトコル違反は69と stderr にし、再接続・起動・再送しない")
    func protocolFailureNeverResends() async throws {
        let fixture = try CLIApplicationFixture()
        let connector = FakeCLIConnector()
        connector.connection.error = IPCCoding.DecodingFailure.malformed
        let launcher = FakeCLILauncher()
        let clock = FakeCLIClock()
        let runner = CLIRunner(resolve: fixture.resolve, connector: connector, launcher: launcher, clock: clock)
        let output = await runner.run(["off"])
        #expect(output.exitCode.rawValue == 69)
        #expect(output.standardOutput.isEmpty)
        #expect(output.standardError == "error: received an invalid response from Capsaicin\n")
        #expect(connector.attempts == 1)
        #expect(connector.connection.requests.map(\.command) == [.stop])
        #expect(connector.connection.closes == 1)
        #expect(launcher.urls.isEmpty)
        #expect(clock.sleeps.isEmpty)
    }

    @Test("SPEC-CLI-004 起動の失敗を callback が知らせたら送信せずに69")
    func launchFailure() async throws {
        let fixture = try CLIApplicationFixture()
        let connector = FakeCLIConnector()
        connector.unavailableAttempts = 100
        let launcher = FakeCLILauncher()
        launcher.callbackResult = false
        let runner = CLIRunner(
            resolve: fixture.resolve,
            connector: connector,
            launcher: launcher,
            clock: FakeCLIClock(),
        )
        #expect(await runner.run(["on"]).exitCode == .unavailable)
        #expect(connector.attempts == 1)
        #expect(launcher.urls.count == 1)
    }

    @Test("SPEC-CLI-004 起動構成は UI・最近使った項目・別コピーへの置換を無効にする")
    func launchConfiguration() {
        let configuration = CLISystemLauncher.configuration()
        #expect(!configuration.activates)
        #expect(!configuration.addsToRecentItems)
        #expect(!configuration.promptsUserIfNeeded)
        #expect(!configuration.allowsRunningApplicationSubstitution)
        #expect(!configuration.createsNewApplicationInstance)
    }

    @Test("SPEC-CLI-001 SPEC-CLI-003 現在時刻とタイムゾーンを差し込み、時間条件なしの要求をそのまま送る")
    func injectedWallClock() async throws {
        let fixture = try CLIApplicationFixture()
        let connector = FakeCLIConnector()
        let now = Date(timeIntervalSince1970: 0)
        connector.connection.response = IPCResponse(outcome: .timeLimitReplaced, status: BlockingStatus(
            session: BlockingSession(timeLimit: TimeLimit(date: now.addingTimeInterval(5399), source: .timer)),
            batteryCondition: nil, misalignments: [:], isRecordUnsaved: false,
        ))
        let runner = try CLIRunner(resolve: fixture.resolve, connector: connector,
                                   launcher: FakeCLILauncher(), clock: FakeCLIClock(), now: { now },
                                   timeZone: #require(TimeZone(secondsFromGMT: -5 * 3600)))
        let output = await runner.run(["on", "--no-time-limit"])
        #expect(connector.connection.requests.map(\.command) == [.start(.noTimeLimit)])
        #expect(output.exitCode == .success)
        #expect(output.standardOutput == "✓ Turn-off time updated\n  Turns off  20:29 (in 1h 29m)\n")
        #expect(output.standardError.isEmpty)
    }
}
