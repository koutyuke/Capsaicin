import Darwin
import Foundation
import OSLog

public enum DisplaySleepError: Error, Equatable, Sendable {
    case unsuccessfulExit(Int32)
    case abnormalTermination(Int32)
    case timedOut
    case systemCall(operation: String, code: Int32)
    case unsafeChildSignalDisposition
}

/// 停止理由と、停止・回収中の OS エラーを両方保持する。
public struct DisplaySleepCleanupError: Error, Sendable {
    public let stopReason: any Error?
    public let failure: DisplaySleepError
}

/// 固定コマンドを実行する。2 秒は停止開始の期限であり、回収完了の期限ではない。
/// ホストは SIGCHLD を既定・SA_NOCLDWAIT なしに保ち、この子を別経路で回収してはならない。
/// 起動直前にも検査するが、検査後のホストによる変更までは防げない。
@MainActor
public final class DisplaySleep {
    private let process: DisplaySleepProcess
    private let scheduler: DisplaySleepScheduler

    public convenience init() {
        self.init(process: .live, scheduler: .live)
    }

    init(process: DisplaySleepProcess, scheduler: DisplaySleepScheduler) {
        self.process = process
        self.scheduler = scheduler
    }

    public func sleepDisplay() async throws {
        let operation = DisplaySleepOperation(process: process, scheduler: scheduler)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                operation.start { continuation.resume(with: $0) }
            }
        } onCancel: {
            operation.cancel()
        }
    }
}

/// 可変状態と全 syscall を queue に隔離する。外からはイベントを enqueue するだけ。
/// 終了済みでも未回収の子は PID を保持する。signal と唯一の wait を同じ queue で行い、
/// 回収直後に PID を消すことで、再利用された PID へ signal を送る隙間を作らない。
final class DisplaySleepOperation: @unchecked Sendable {
    private enum State { case beforeStart, active, finished }

    private let queue: DispatchQueue
    private let process: DisplaySleepProcess
    private let scheduler: DisplaySleepScheduler
    private var state = State.beforeStart
    private var pid: pid_t?
    private var completion: (@Sendable (Result<Void, any Error>) -> Void)?
    private var cancelDeadline: (() -> Void)?
    private var cancelGrace: (() -> Void)?
    private var cancelPoll: (() -> Void)?
    private var stoppingError: any Error?
    private var cleanupFailure: DisplaySleepError?
    private var didEscalate = false

    init(process: DisplaySleepProcess, scheduler: DisplaySleepScheduler,
         queue: DispatchQueue = DispatchQueue(label: "Capsaicin.DisplaySleep"))
    {
        self.process = process
        self.scheduler = scheduler
        self.queue = queue
    }

    func start(_ completion: @escaping @Sendable (Result<Void, any Error>) -> Void) {
        queue.async { self.begin(completion) }
    }

    func cancel() {
        queue.async { self.stop(with: CancellationError()) }
    }

    private func begin(_ completion: @escaping @Sendable (Result<Void, any Error>) -> Void) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard state == .beforeStart else { return }
        self.completion = completion
        state = .active
        if let stoppingError {
            finish(.failure(stoppingError))
            return
        }
        cancelDeadline = scheduler.after(.seconds(2), queue) { self.stop(with: DisplaySleepError.timedOut) }
        do {
            // spawn 中の cancel は queue に残る。返された PID を必ず保存してから処理する。
            pid = try process.spawn()
            cancelPoll = scheduler.poll(queue) { self.poll() }
        } catch {
            finish(.failure(error))
        }
    }

    private func stop(with error: any Error) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard state != .finished, stoppingError == nil else { return }
        stoppingError = error
        guard state == .active else { return }
        cancelDeadline?()
        cancelDeadline = nil
        poll()
        guard state == .active, pid != nil else { return }
        send(SIGTERM)
        cancelGrace = scheduler.after(.milliseconds(500), queue) { self.escalate() }
    }

    private func escalate() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard state == .active, !didEscalate else { return }
        didEscalate = true
        cancelGrace?()
        cancelGrace = nil
        poll()
        guard state == .active, pid != nil else { return }
        send(SIGKILL)
        // KILL は回収ではない。OS エラーで回収できなくても所有者と poll を残す。
    }

    private func send(_ signal: Int32) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let pid else { return }
        let code = process.signal(pid, signal)
        if code != 0, code != ESRCH {
            recordFailure(.systemCall(operation: signal == SIGTERM ? "kill(SIGTERM)" : "kill(SIGKILL)", code: code))
        }
    }

    private func poll() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard state == .active, let pid else { return }
        switch process.wait(pid) {
        case .running:
            break
        case let .status(status):
            guard let result = DisplaySleepProcess.exitResult(status) else { return }
            self.pid = nil
            if let cleanupFailure {
                finish(.failure(DisplaySleepCleanupError(stopReason: stoppingError, failure: cleanupFailure)))
            } else if let stoppingError {
                finish(.failure(stoppingError))
            } else {
                finish(result)
            }
        case let .failure(code):
            guard code != EINTR else { return }
            let failure = DisplaySleepError.systemCall(operation: "waitpid", code: code)
            recordFailure(failure)
            if code == ECHILD {
                // ホスト契約が破られた可能性がある。以後この PID へは一切送信しない。
                self.pid = nil
                finish(.failure(DisplaySleepCleanupError(stopReason: stoppingError, failure: failure)))
            }
        }
    }

    private func recordFailure(_ error: DisplaySleepError) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard cleanupFailure == nil else { return }
        cleanupFailure = error
        // 回収が無期限になった場合も診断を残す。環境やコマンドの出力は記録しない。
        Logger(subsystem: "io.github.koutyuke.capsaicin", category: "DisplaySleep")
            .error("子プロセスの停止・回収に失敗: \(String(describing: error), privacy: .public)")
    }

    private func finish(_ result: Result<Void, any Error>) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard state != .finished else { return }
        precondition(pid == nil)
        state = .finished
        cancelDeadline?()
        cancelGrace?()
        cancelPoll?()
        cancelDeadline = nil
        cancelGrace = nil
        cancelPoll = nil
        let completion = completion
        self.completion = nil
        completion?(result)
    }
}
