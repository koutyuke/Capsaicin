import Foundation

enum CommandRunnerError: Error, Equatable {
    case alreadyRunning
    case timedOut
    case outputTooLarge
    case unsuccessfulExit(Int32)
}

/// 実行中の状態だけをロックで守る。期限後も子の終了まで次の起動を受け付けない。
final class CommandRunner: @unchecked Sendable {
    let executable: String
    let arguments: [String]
    let outputLimit: Int
    private let lock = NSLock()
    private var isRunning = false

    init(executable: String, arguments: [String], outputLimit: Int = 0) {
        self.executable = executable
        self.arguments = arguments
        self.outputLimit = outputLimit
    }

    func run(timeout: TimeInterval) throws -> Data {
        let deadline = DispatchTime.now() + timeout
        let process = Process()
        let pipe = Pipe()
        let completion = CommandCompletion()
        try lock.withLock {
            guard !isRunning else { throw CommandRunnerError.alreadyRunning }
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = [:]
            process.standardInput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.standardOutput = outputLimit > 0 ? pipe : FileHandle.nullDevice
            try process.run()
            isRunning = true
        }
        // 呼び出し元がブロックして待つので、GCD の共有スレッドを使わず専用のスレッドで見届ける。
        Thread.detachNewThread {
            var output = Data()
            var failure: any Error?
            do {
                if self.outputLimit > 0 {
                    while let chunk = try pipe.fileHandleForReading.read(upToCount: 4096), !chunk.isEmpty {
                        if chunk.count > self.outputLimit - output.count {
                            failure = CommandRunnerError.outputTooLarge
                        } else if failure == nil {
                            output.append(chunk)
                        }
                    }
                }
            } catch { failure = error }
            try? pipe.fileHandleForReading.close()
            process.waitUntilExit()
            if failure == nil, process.terminationStatus != 0 {
                failure = CommandRunnerError.unsuccessfulExit(process.terminationStatus)
            }
            completion.result = failure.map { .failure($0) } ?? .success(output)
            self.lock.withLock { self.isRunning = false }
            completion.finished.signal()
        }
        guard completion.finished.wait(timeout: deadline) == .success else { throw CommandRunnerError.timedOut }
        return try completion.result.get()
    }
}

/// 結果はワーカーだけが書き、呼び出し元はセマフォの完了後だけ読む。
private final class CommandCompletion: @unchecked Sendable {
    let finished = DispatchSemaphore(value: 0)
    var result: Result<Data, any Error> = .success(Data())
}
