@testable import CapsaicinPlatform
import Foundation
import Synchronization
import Testing

struct CommandRunnerTests {
    @Test("SPEC-HLP-005 実行時にコマンドを変えても既存 API と実行中の状態を共有する")
    func differentCommandsShareObservation() async throws {
        let runner = CommandRunner(executable: "/bin/echo", arguments: ["default"], outputLimit: 1024)
        #expect(try runner.run(executable: "/bin/echo", arguments: ["$HOME"], timeout: 2) == Data("$HOME\n".utf8))
        let gate = ProcessGate()
        #expect(throws: CommandRunnerError.timedOut) {
            try runner.run(executable: "/bin/sh", arguments: gate.arguments, timeout: 0.02)
        }
        #expect(throws: CommandRunnerError.alreadyRunning) { try runner.run(timeout: 1) }
        #expect(throws: CommandRunnerError.alreadyRunning) {
            try runner.run(executable: "/usr/bin/false", arguments: [], timeout: 1)
        }
        gate.open()
        #expect(try await runner.runWhenIdle() == Data("default\n".utf8))
    }

    @Test("SPEC-HLP-005 標準出力を上限まで返す。引数はシェルを通さない")
    func boundedOutput() throws {
        let text = "$HOME ; test"
        let runner = CommandRunner(executable: "/bin/echo", arguments: [text], outputLimit: text.utf8.count + 1)
        #expect(try runner.run(timeout: 2) == Data("\(text)\n".utf8))
        #expect(try runner.run(timeout: 2) == Data("\(text)\n".utf8))
    }

    @Test("SPEC-HLP-005 出力が上限を超えてもパイプを読み切り、次の呼び出しを受け付ける")
    func excessiveOutput() {
        let runner = CommandRunner(executable: "/bin/echo", arguments: [String(repeating: "x", count: 100_000)],
                                   outputLimit: 32)
        for _ in 0 ..< 2 {
            #expect(throws: CommandRunnerError.outputTooLarge) { try runner.run(timeout: 2) }
        }
    }

    @Test("SPEC-HLP-005 読み取りを指定しない標準出力は捨てる")
    func discardedOutput() throws {
        let runner = CommandRunner(executable: "/bin/echo", arguments: [String(repeating: "x", count: 100_000)])
        #expect(try runner.run(timeout: 2).isEmpty)
    }

    @Test("SPEC-HLP-005 空の環境変数と標準入力で動く")
    func emptyEnvironmentAndInput() throws {
        let environment = CommandRunner(executable: "/usr/bin/env", arguments: [], outputLimit: 1024)
        #expect(try environment.run(timeout: 2).isEmpty)
        let input = CommandRunner(executable: "/bin/cat", arguments: [], outputLimit: 1024)
        #expect(try input.run(timeout: 2).isEmpty)
    }

    @Test("SPEC-HLP-005 非ゼロ終了は失敗として返す")
    func unsuccessfulExit() {
        let runner = CommandRunner(executable: "/usr/bin/false", arguments: [])
        #expect(throws: CommandRunnerError.unsuccessfulExit(1)) { try runner.run(timeout: 2) }
    }

    @Test("SPEC-HLP-005 起動失敗の後も次の起動を試みる")
    func launchFailure() {
        let runner = CommandRunner(executable: "/capsaicin-command-does-not-exist", arguments: [])
        for _ in 0 ..< 2 {
            #expect(throws: CocoaError.self) { try runner.run(timeout: 2) }
        }
    }

    @Test("SPEC-HLP-005 期限を過ぎても止めず、終了までは次の起動を断る")
    func timeoutAndObservation() async throws {
        let gate = ProcessGate()
        let runner = CommandRunner(executable: "/bin/sh", arguments: gate.arguments)
        // 子は開くまで終わらないので、戻ってくれば期限で戻ったことになる。
        #expect(throws: CommandRunnerError.timedOut) { try runner.run(timeout: 0.02) }
        #expect(throws: CommandRunnerError.alreadyRunning) { try runner.run(timeout: 1) }
        gate.open()
        #expect(try await runner.runWhenIdle(executable: "/usr/bin/true", arguments: []).isEmpty)
    }

    @Test("SPEC-HLP-005 別スレッドから同時に呼んでも起動は1つだけ")
    func concurrentCalls() {
        let gate = ProcessGate()
        let runner = CommandRunner(executable: "/bin/sh", arguments: gate.arguments)
        let results = Mutex<[CommandRunnerError?]>([])
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            do {
                _ = try runner.run(timeout: 0.1)
                results.withLock { $0.append(nil) }
            } catch {
                results.withLock { $0.append(error as? CommandRunnerError) }
            }
        }
        gate.open()
        // 子は開くまで終わらないので、起動した1つは期限で戻り、残りは実行中として断られる。
        results.withLock {
            #expect($0.filter { $0 == .timedOut }.count == 1)
            #expect($0.filter { $0 == .alreadyRunning }.count == 7)
        }
    }
}
