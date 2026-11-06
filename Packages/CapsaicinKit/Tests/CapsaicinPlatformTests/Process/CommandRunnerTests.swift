@testable import CapsaicinPlatform
import Foundation
import Synchronization
import Testing

struct CommandRunnerTests {
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
        let runner = CommandRunner(executable: "/bin/sleep", arguments: ["0.4"])
        let start = ContinuousClock.now
        #expect(throws: CommandRunnerError.timedOut) { try runner.run(timeout: 0.02) }
        #expect(start.duration(to: .now) < .milliseconds(300))
        #expect(throws: CommandRunnerError.alreadyRunning) { try runner.run(timeout: 1) }
        try await Task.sleep(for: .milliseconds(100))
        #expect(throws: CommandRunnerError.alreadyRunning) { try runner.run(timeout: 1) }
        try await Task.sleep(for: .milliseconds(400))
        #expect(try runner.run(timeout: 2).isEmpty)
    }

    @Test("SPEC-HLP-005 別スレッドから同時に呼んでも起動は1つだけ")
    func concurrentCalls() {
        let runner = CommandRunner(executable: "/bin/sleep", arguments: ["0.4"])
        let results = Mutex<[CommandRunnerError?]>([])
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            do {
                _ = try runner.run(timeout: 2)
                results.withLock { $0.append(nil) }
            } catch {
                #expect(error as? CommandRunnerError == .alreadyRunning)
                results.withLock { $0.append(error as? CommandRunnerError) }
            }
        }
        results.withLock {
            #expect($0.filter { $0 == nil }.count == 1)
            #expect($0.filter { $0 == .alreadyRunning }.count == 7)
        }
    }
}
