@testable import CapsaicinPlatform
import Testing

@MainActor
struct DisplaySleepCommandTests {
    @Test("SPEC-BLK-002 固定の画面消灯コマンドを使う（実行しない）")
    func fixedCommand() {
        let display = DisplaySleep()
        #expect(display.runner.executable == "/usr/bin/pmset")
        #expect(display.runner.arguments == ["displaysleepnow"])
        #expect(display.runner.outputLimit == 0)
    }

    @Test("SPEC-BLK-002 async API は正常終了とコマンドの失敗を返す")
    func commandResult() async throws {
        let success = DisplaySleep(runner: CommandRunner(executable: "/bin/echo", arguments: ["test"]))
        try await success.sleepDisplay()
        let failure = DisplaySleep(runner: CommandRunner(executable: "/usr/bin/false", arguments: []))
        await #expect(throws: CommandRunnerError.unsuccessfulExit(1)) {
            try await failure.sleepDisplay()
        }
    }

    @Test("SPEC-BLK-002 2 秒の期限後は失敗し、終了前の次の消灯は起動しない")
    func deadline() async throws {
        let display = DisplaySleep(runner: CommandRunner(executable: "/bin/sleep", arguments: ["2.3"]))
        await #expect(throws: CommandRunnerError.timedOut) { try await display.sleepDisplay() }
        await #expect(throws: CommandRunnerError.alreadyRunning) { try await display.sleepDisplay() }
        try await Task.sleep(for: .milliseconds(400))
    }
}
