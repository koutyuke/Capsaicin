import Darwin
import Foundation

/// 所有者の直列キューからだけ呼ぶ、同期・非ブロッキングの OS 境界。
struct DisplaySleepProcess: Sendable {
    enum WaitResult { case running, status(Int32), failure(Int32) }

    var spawn: @Sendable () throws -> pid_t
    var wait: @Sendable (pid_t) -> WaitResult
    var signal: @Sendable (pid_t, Int32) -> Int32

    static let executable = "/usr/bin/pmset"
    static let arguments = ["pmset", "displaysleepnow"]
    static let nullDevice = "/dev/null"
    static let streams: [(descriptor: Int32, flags: Int32)] = [
        (STDIN_FILENO, O_RDONLY),
        (STDOUT_FILENO, O_WRONLY),
        (STDERR_FILENO, O_WRONLY),
    ]
    static let spawnFlags = Int16(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF)

    static let live = Self(spawn: spawnNative, wait: { pid in
        var status: Int32 = 0
        let result = waitpid(pid, &status, WNOHANG)
        let code = errno
        if result == pid {
            return .status(status)
        }
        return result == 0 ? .running : .failure(code)
    }, signal: { pid, signal in
        let result = Darwin.kill(pid, signal)
        let code = errno
        return result == 0 ? 0 : code
    })

    /// Darwin の sys/wait.h の低 7 bit が 0 なら exit、0x7f なら停止・継続通知。
    static func exitResult(_ status: Int32) -> Result<Void, any Error>? {
        let signal = status & 0x7F
        if signal == 0x7F {
            return nil
        }
        if signal != 0 {
            return .failure(DisplaySleepError.abnormalTermination(signal))
        }
        let exitCode = (status >> 8) & 0xFF
        return exitCode == 0 ? .success(()) : .failure(DisplaySleepError.unsuccessfulExit(exitCode))
    }

    static func validateChildDisposition(handlerIsDefault: Bool, flags: Int32) throws {
        guard handlerIsDefault, flags & SA_NOCLDWAIT == 0 else {
            throw DisplaySleepError.unsafeChildSignalDisposition
        }
    }

    private static func spawnNative() throws -> pid_t {
        var action = sigaction()
        guard sigaction(SIGCHLD, nil, &action) == 0 else {
            throw DisplaySleepError.systemCall(operation: "sigaction(SIGCHLD)", code: errno)
        }
        // Darwin の SIG_DFL は null。SIG_IGN と独自 handler の両方を拒否する。
        try validateChildDisposition(handlerIsDefault: action.__sigaction_u.__sa_handler == nil, flags: action.sa_flags)

        var actions: posix_spawn_file_actions_t?
        try check(posix_spawn_file_actions_init(&actions), "posix_spawn_file_actions_init")
        defer { posix_spawn_file_actions_destroy(&actions) }
        for stream in streams {
            try check(posix_spawn_file_actions_addopen(&actions, stream.descriptor, nullDevice, stream.flags, 0),
                      "posix_spawn_file_actions_addopen")
        }

        var attributes: posix_spawnattr_t?
        try check(posix_spawnattr_init(&attributes), "posix_spawnattr_init")
        defer { posix_spawnattr_destroy(&attributes) }
        try configureAttributes(&attributes)
        return try spawn(actions: &actions, attributes: &attributes)
    }

    private static func configureAttributes(_ attributes: inout posix_spawnattr_t?) throws {
        var mask = sigset_t()
        sigemptyset(&mask)
        try check(posix_spawnattr_setsigmask(&attributes, &mask), "posix_spawnattr_setsigmask")
        var defaults = sigset_t()
        sigemptyset(&defaults)
        sigaddset(&defaults, SIGTERM)
        try check(posix_spawnattr_setsigdefault(&attributes, &defaults), "posix_spawnattr_setsigdefault")
        try check(posix_spawnattr_setflags(&attributes, spawnFlags), "posix_spawnattr_setflags")
    }

    private static func spawn(actions: inout posix_spawn_file_actions_t?,
                              attributes: inout posix_spawnattr_t?) throws -> pid_t
    {
        // Process と同様に親の環境を継承し、この同期呼び出しの間だけ C 配列を保持する。
        let environment = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
        var strings: [UnsafeMutablePointer<CChar>] = []
        defer { strings.forEach { free($0) } }
        for string in arguments + environment {
            guard let copy = strdup(string) else {
                throw DisplaySleepError.systemCall(operation: "strdup", code: ENOMEM)
            }
            strings.append(copy)
        }
        var argv = strings.prefix(arguments.count).map(Optional.some) + [nil]
        var envp = strings.dropFirst(arguments.count).map(Optional.some) + [nil]
        var pid: pid_t = 0
        // 失敗時の出力 PID は未定義。成功するまで所有者へ渡さない。
        try check(posix_spawn(&pid, executable, &actions, &attributes, &argv, &envp), "posix_spawn")
        return pid
    }

    private static func check(_ code: Int32, _ operation: String) throws {
        guard code == 0 else { throw DisplaySleepError.systemCall(operation: operation, code: code) }
    }
}

struct DisplaySleepScheduler: Sendable {
    /// action と返すキャンセル処理は、指定キューでのみ実行する。
    var after: @Sendable (Duration, DispatchQueue, @escaping @Sendable () -> Void) -> () -> Void
    var poll: @Sendable (DispatchQueue, @escaping @Sendable () -> Void) -> () -> Void

    static let live = Self(after: { delay, queue, action in
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: delay)
        let task = Task {
            do { try await clock.sleep(until: deadline) } catch { return }
            queue.async(execute: action)
        }
        return { task.cancel() }
    }, poll: { queue, action in
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(20))
        // 強参照で実際の回収まで owner を保持し、キャンセル時に循環を切る。
        timer.setEventHandler(handler: action)
        timer.resume()
        return {
            timer.setEventHandler(handler: nil)
            timer.cancel()
        }
    })
}
