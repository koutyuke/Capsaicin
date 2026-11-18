@testable import CapsaicinPlatform
import Foundation
import Testing

@MainActor
struct HelperSleepControllerTests {
    @Test("SPEC-HLP-005 SleepDisabled の 0 と 1 だけを読む", arguments: ["0", "1"])
    func parseValue(value: String) throws {
        let controller = HelperSleepController(run: { executable, arguments, timeout in
            #expect(executable == "/usr/bin/pmset")
            #expect(arguments == ["-g"])
            #expect(timeout == 5)
            return Data("System-wide power settings:\nCurrently in use:\n  SleepDisabled\t\(value)\n sleep 1\n".utf8)
        })
        #expect(try controller.readSleepDisabled() == (value == "1"))
    }

    @Test("SPEC-HLP-005 読めない値を 0 や 1 とみなさない", arguments: [
        "", "SleepDisabled", "SleepDisabled 2", "SleepDisabled -1", "SleepDisabled 01",
        "SleepDisabled true", "OtherSleepDisabled 1", "SleepDisabled 1 extra", "SleepDisabled 0\nSleepDisabled 1",
    ])
    func invalidOutput(output: String) {
        let controller = HelperSleepController(run: { _, _, _ in Data(output.utf8) })
        #expect(throws: HelperError.invalidSleepDisabled) { try controller.readSleepDisabled() }
    }

    @Test("SPEC-HLP-002 on と off だけを XPC に渡し、応答の失敗を返す")
    func fixedCommands() throws {
        let connection = FakeConnection(response: .success(()))
        let controller = HelperSleepController(client: HelperXPCClient(connect: { _ in connection }), run: { _, _, _ in
            Issue.record("XPC の操作で子プロセスを起動した")
            return Data()
        })
        try controller.turnOn()
        try controller.turnOff()
        #expect(connection.commands == ["on", "off"])
        for failure in [HelperXPCError.connectionFailed, .requestFailed, .timedOut, .invalidReply] {
            let client = HelperXPCClient(connect: { _ in FakeConnection(response: .failure(failure)) })
            let failing = HelperSleepController(client: client, run: { _, _, _ in Data() })
            #expect(throws: failure) { try failing.turnOn() }
            #expect(throws: failure) { try failing.turnOff() }
        }
    }

    @Test("SPEC-HLP-005 読み取りの失敗と見届け中の拒否をそのまま返す")
    func commandFailures() {
        for failure in [CommandRunnerError.timedOut, .alreadyRunning, .unsuccessfulExit(1), .outputTooLarge] {
            let controller = HelperSleepController(run: { _, _, _ in throw failure })
            #expect(throws: failure) { try controller.readSleepDisabled() }
        }
        let invalidUTF8 = HelperSleepController(run: { _, _, _ in Data([0xFF]) })
        #expect(throws: HelperError.invalidSleepDisabled) { try invalidUTF8.readSleepDisabled() }
    }

    @Test("SPEC-HLP-004 許可済みの状態だけが利用できる", arguments: [
        HelperInstallationState.notInstalled, .requiresApproval, .installed, .unavailable,
    ])
    func installationStates(state: HelperInstallationState) {
        let controller = HelperSleepController(state: { state }, run: { _, _, _ in Data() })
        #expect(controller.installationState == state)
        #expect(controller.isHelperInstalled == (state == .installed))
        #expect(controller.isHelperAwaitingApproval == (state == .requiresApproval))
    }

    @Test("SPEC-HLP-005 読み取りの期限後は子プロセスを見届け、次の読み取りを断る")
    func sharedRunner() throws {
        let gate = ProcessGate()
        let runner = CommandRunner(executable: "/bin/sh", arguments: gate.arguments, outputLimit: 65536)
        #expect(throws: CommandRunnerError.timedOut) { try runner.run(timeout: 0.02) }
        let controller = HelperSleepController(run: { _, _, timeout in
            try runner.run(executable: "/bin/echo", arguments: [], timeout: timeout)
        })
        #expect(throws: CommandRunnerError.alreadyRunning) { try controller.readSleepDisabled() }
        gate.open()
    }
}
