@testable import CapsaicinPlatform
import Darwin
import Foundation
import Testing

struct PowerPlatformDisplaySleepProcessTests {
    @Test("SPEC-BLK-002 固定コマンド・標準 FD・子専用 signal 属性。native 実行はしない")
    func fixedCommand() {
        #expect(DisplaySleepProcess.executable == "/usr/bin/pmset")
        #expect(DisplaySleepProcess.arguments == ["pmset", "displaysleepnow"])
        #expect(DisplaySleepProcess.streams.map(\.descriptor) == [STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO])
        #expect(DisplaySleepProcess.nullDevice == "/dev/null")
        #expect(DisplaySleepProcess.streams.map(\.flags) == [O_RDONLY, O_WRONLY, O_WRONLY])
        #expect(DisplaySleepProcess.spawnFlags ==
            Int16(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF))
    }

    @Test("SPEC-BLK-002 SIGCHLD の既定以外・自動回収設定は起動前に拒否")
    func childDisposition() throws {
        try DisplaySleepProcess.validateChildDisposition(handlerIsDefault: true, flags: 0)
        try DisplaySleepProcess.validateChildDisposition(handlerIsDefault: true, flags: SA_NOCLDSTOP)
        for (isDefault, flags) in [(false, Int32(0)), (true, SA_NOCLDWAIT), (false, SA_NOCLDWAIT)] {
            #expect(throws: DisplaySleepError.unsafeChildSignalDisposition) {
                try DisplaySleepProcess.validateChildDisposition(handlerIsDefault: isDefault, flags: flags)
            }
        }
    }

    @Test("SPEC-BLK-002 Darwin wait status の終了・signal・core・停止・継続の区別")
    func waitStatus() throws {
        try #require(DisplaySleepProcess.exitResult(0)).get()
        #expect(throws: DisplaySleepError.unsuccessfulExit(255)) {
            try #require(DisplaySleepProcess.exitResult(255 << 8)).get()
        }
        #expect(throws: DisplaySleepError.abnormalTermination(SIGKILL)) {
            try #require(DisplaySleepProcess.exitResult(SIGKILL)).get()
        }
        #expect(throws: DisplaySleepError.abnormalTermination(SIGSEGV)) {
            try #require(DisplaySleepProcess.exitResult(SIGSEGV | 0x80)).get()
        }
        #expect(DisplaySleepProcess.exitResult((SIGSTOP << 8) | 0x7F) == nil)
        #expect(DisplaySleepProcess.exitResult((SIGCONT << 8) | 0x7F) == nil)
    }
}

/// fake の可変状態も本物の所有者と同じ queue に隔離する。テスト側は sync で読む。
/// signal は安全判定を代行せず、不正な宛先も記録する。PID の再利用は回収後だけ可能。
final class DisplaySleepFake: @unchecked Sendable {
    enum Child: Equatable { case notSpawned, running, zombie(Int32), reaped, reused }

    struct Timer {
        let duration: Duration?
        let action: @Sendable () -> Void
        var cancelled = false
    }

    let queue = DispatchQueue(label: "DisplaySleepFake")
    let pid: pid_t
    var child = Child.notSpawned
    var timers: [Timer] = []
    var results: [Result<Void, any Error>] = []
    var calls: [String] = []
    var signals: [Int32] = []
    var signalStates: [Child] = []
    var invalidSignals = 0
    var waitResults: [DisplaySleepProcess.WaitResult] = []
    var afterWait: (() -> Void)?
    var onSpawn: (() -> Void)?
    var spawnError: DisplaySleepError?
    var signalErrors: [Int32: Int32] = [:]

    init(pid: pid_t = 41) {
        self.pid = pid
    }

    var allTimersCancelled: Bool {
        dispatchPrecondition(condition: .onQueue(queue))
        return timers.allSatisfy(\.cancelled)
    }

    var error: any Error? {
        dispatchPrecondition(condition: .onQueue(queue))
        if case let .failure(error) = results.first {
            return error
        }
        return nil
    }

    func operation() -> DisplaySleepOperation {
        let process = DisplaySleepProcess(spawn: {
            dispatchPrecondition(condition: .onQueue(self.queue))
            self.calls.append("spawn")
            if let error = self.spawnError {
                throw error
            }
            self.child = .running
            let hook = self.onSpawn
            self.onSpawn = nil
            hook?()
            return self.pid
        }, wait: { pid in
            self.wait(pid)
        }, signal: { pid, signal in
            dispatchPrecondition(condition: .onQueue(self.queue))
            self.calls.append("signal:\(signal)")
            self.signals.append(signal)
            self.signalStates.append(self.child)
            if pid != self.pid || self.child == .reused || self.child == .reaped || self.child == .notSpawned {
                self.invalidSignals += 1
            }
            return self.signalErrors[signal, default: 0]
        })
        let scheduler = DisplaySleepScheduler(after: { delay, _, action in
            self.schedule(delay, action)
        }, poll: { _, action in self.schedule(nil, action) })
        return DisplaySleepOperation(process: process, scheduler: scheduler, queue: queue)
    }

    func begin() -> DisplaySleepOperation {
        let operation = operation()
        operation.start { self.complete($0) }
        drain()
        return operation
    }

    func drain() {
        // spawn 内で enqueue した cancel も、二つ目の barrier までには処理される。
        queue.sync {}
        queue.sync {}
    }

    func complete(_ result: Result<Void, any Error>) {
        dispatchPrecondition(condition: .onQueue(queue))
        results.append(result)
    }

    func fire(_ duration: Duration?) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let timer = timers.first(where: { $0.duration == duration }) else {
            Issue.record("未登録のタイマー: \(String(describing: duration))")
            return
        }
        timer.action()
    }

    func fireAll() {
        dispatchPrecondition(condition: .onQueue(queue))
        for timer in timers {
            timer.action()
        }
    }

    func clearTimers() {
        queue.sync { timers.removeAll() }
    }

    private func schedule(_ delay: Duration?, _ action: @escaping @Sendable () -> Void) -> () -> Void {
        dispatchPrecondition(condition: .onQueue(queue))
        let index = timers.count
        timers.append(Timer(duration: delay, action: action))
        return {
            dispatchPrecondition(condition: .onQueue(self.queue))
            self.timers[index].cancelled = true
        }
    }

    private func wait(_ pid: pid_t) -> DisplaySleepProcess.WaitResult {
        dispatchPrecondition(condition: .onQueue(queue))
        #expect(pid == self.pid)
        calls.append("wait")
        let hook = afterWait
        afterWait = nil
        defer { hook?() }
        if !waitResults.isEmpty {
            let result = waitResults.removeFirst()
            if case .failure(ECHILD) = result {
                child = .reused
            }
            return result
        }
        if case let .zombie(status) = child {
            child = .reaped
            return .status(status)
        }
        return .running
    }
}
