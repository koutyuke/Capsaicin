@testable import CapsaicinPlatform
import Foundation
import Synchronization
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

    @Test("SPEC-HLP-002 SPEC-HLP-005 固定パスを sudo -n と5秒期限で呼ぶ")
    func fixedCommands() throws {
        for debug in [false, true] {
            let paths = HelperPaths(debug: debug)
            let calls = Mutex<[[String]]>([])
            let controller = HelperSleepController(paths: paths, run: { executable, arguments, timeout in
                #expect(executable == "/usr/bin/sudo")
                calls.withLock { $0.append(arguments) }
                #expect(timeout == 5)
                return Data()
            })
            try controller.turnOn()
            try controller.turnOff()
            calls.withLock { #expect($0 == [["-n", paths.helper, "on"], ["-n", paths.helper, "off"]]) }
        }
    }

    @Test("SPEC-HLP-005 通信の失敗と見届け中の拒否をそのまま返す")
    func commandFailures() {
        for failure in [CommandRunnerError.timedOut, .alreadyRunning, .unsuccessfulExit(1), .outputTooLarge] {
            let controller = HelperSleepController(run: { _, _, _ in throw failure })
            #expect(throws: failure) { try controller.turnOn() }
            #expect(throws: failure) { try controller.turnOff() }
            #expect(throws: failure) { try controller.readSleepDisabled() }
        }
        let invalidUTF8 = HelperSleepController(run: { _, _, _ in Data([0xFF]) })
        #expect(throws: HelperError.invalidSleepDisabled) { try invalidUTF8.readSleepDisabled() }
    }

    @Test("SPEC-HLP-004 3ファイルの全組み合わせで状態と利用可否を判定する")
    func installationStates() {
        let paths = HelperPaths(debug: true)
        for mask in 0 ..< 8 {
            let existing = Set(paths.files.enumerated().compactMap { index, path in
                mask & (1 << index) != 0 ? path : nil
            })
            let controller = HelperSleepController(paths: paths, exists: { existing.contains($0) },
                                                   run: { _, _, _ in Issue.record("状態判定でコマンドを起動した"); return Data() })
            #expect(controller.installationState == (mask == 0 ? .notInstalled : mask == 7 ? .installed : .partial))
            #expect(controller.isHelperInstalled == (mask == 7))
        }
    }

    @Test("SPEC-HLP-005 共有 runner の見届け中は読み取りと on/off を断る（起動先は echo に差し替える）")
    func sharedRunner() async throws {
        let runner = CommandRunner(executable: "/bin/sleep", arguments: ["0.4"], outputLimit: 65536)
        #expect(throws: CommandRunnerError.timedOut) { try runner.run(timeout: 0.02) }
        let controller = HelperSleepController(run: { _, _, timeout in
            try runner.run(executable: "/bin/echo", arguments: [], timeout: timeout)
        })
        #expect(throws: CommandRunnerError.alreadyRunning) { try controller.turnOn() }
        #expect(throws: CommandRunnerError.alreadyRunning) { try controller.turnOff() }
        #expect(throws: CommandRunnerError.alreadyRunning) { try controller.readSleepDisabled() }
        try await Task.sleep(for: .milliseconds(500))
    }
}
