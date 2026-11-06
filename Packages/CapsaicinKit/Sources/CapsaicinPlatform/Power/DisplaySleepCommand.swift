import Foundation

@MainActor
public final class DisplaySleep {
    let runner: CommandRunner

    public convenience init() {
        self.init(runner: CommandRunner(executable: "/usr/bin/pmset", arguments: ["displaysleepnow"]))
    }

    init(runner: CommandRunner) {
        self.runner = runner
    }

    public func sleepDisplay() async throws {
        let runner = runner
        try await Task.detached { _ = try runner.run(timeout: 2) }.value
    }
}
