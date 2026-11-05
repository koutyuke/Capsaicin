@testable import CapsaicinPlatform
import Darwin
import Foundation
import Testing

struct PowerPlatformDisplaySleepTests {
    @Test("SPEC-BLK-002 KILL 直前の終了でも PID は未回収の子のもの。KILL だけでは完了しない")
    func timeoutEscalation() {
        let fake = DisplaySleepFake()
        defer { fake.clearTimers() }
        let operation = fake.begin()
        fake.queue.sync {
            #expect(fake.timers.map(\.duration) == [.seconds(2), nil])
            fake.fire(.seconds(2))
            fake.afterWait = { fake.child = .zombie(SIGKILL) }
            fake.fire(.milliseconds(500))
            #expect(fake.signals == [SIGTERM, SIGKILL])
            #expect(fake.signalStates == [.running, .zombie(SIGKILL)])
            #expect(fake.results.isEmpty, "KILL の送信だけでは子の回収は完了していない")
            #expect(fake.child == .zombie(SIGKILL))
            #expect(fake.timers.first { $0.duration == nil }?.cancelled == false)
            fake.fire(.milliseconds(500))
            fake.fire(.seconds(2))
            #expect(fake.results.isEmpty)
            #expect(fake.signals == [SIGTERM, SIGKILL])
            fake.fire(nil)
            #expect(fake.child == .reaped)
            #expect(fake.error as? DisplaySleepError == .timedOut)
            fake.child = .reused
            fake.fireAll()
        }
        operation.cancel()
        fake.drain()
        fake.queue.sync {
            #expect(fake.signals == [SIGTERM, SIGKILL])
            #expect(fake.results.count == 1)
            #expect(fake.invalidSignals == 0)
            #expect(fake.allTimersCancelled)
            #expect(fake.calls == ["spawn", "wait", "signal:15", "wait", "signal:9", "wait"])
        }
    }

    @Test("SPEC-BLK-002 TERM 後に回収した PID が再利用されても遅い grace は送信しない")
    func reapedBeforeGrace() {
        let fake = DisplaySleepFake()
        defer { fake.clearTimers() }
        let operation = fake.begin()
        fake.queue.sync { fake.fire(.seconds(2)) }
        operation.cancel()
        fake.drain()
        fake.queue.sync {
            fake.child = .zombie(0)
            fake.fire(nil)
            #expect(fake.error as? DisplaySleepError == .timedOut)
            fake.child = .reused
            fake.fire(.milliseconds(500))
            fake.fireAll()
            #expect(fake.signals == [SIGTERM])
            #expect(fake.results.count == 1)
            #expect(fake.invalidSignals == 0)
        }
    }

    @Test("SPEC-BLK-002 start より先の cancel は記憶され、spawn せず一度だけキャンセルを返す")
    func cancellationBeforeStart() {
        let fake = DisplaySleepFake()
        defer { fake.clearTimers() }
        let operation = fake.operation()
        operation.cancel()
        operation.start { fake.complete($0) }
        fake.drain()
        operation.start { _ in Issue.record("二度目の start が完了してはいけない") }
        operation.cancel()
        fake.drain()
        fake.queue.sync {
            #expect(fake.error is CancellationError)
            #expect(fake.results.count == 1)
            #expect(fake.calls.isEmpty)
            #expect(fake.timers.isEmpty)
        }
    }

    @Test("SPEC-BLK-002 spawn 中の cancel でも PID を保存し、停止して回収する")
    func cancellationDuringSpawn() {
        let fake = DisplaySleepFake()
        defer { fake.clearTimers() }
        let operation = fake.operation()
        fake.queue.sync { fake.onSpawn = { operation.cancel() } }
        operation.start { fake.complete($0) }
        fake.drain()
        fake.queue.sync {
            #expect(fake.calls == ["spawn", "wait", "signal:15"])
            #expect(fake.child == .running)
            #expect(fake.results.isEmpty)
            fake.fire(.seconds(2))
            fake.child = .zombie(0)
            fake.fire(nil)
            fake.child = .reused
            fake.fireAll()
            #expect(fake.error is CancellationError)
            #expect(fake.results.count == 1)
            #expect(fake.signals == [SIGTERM])
        }
    }

    @Test("SPEC-BLK-002 EINTR・停止・継続通知では所有権を捨てない",
          arguments: [
              DisplaySleepProcess.WaitResult.failure(EINTR),
              .status((SIGSTOP << 8) | 0x7F),
              .status((SIGCONT << 8) | 0x7F)
          ])
    func nonterminalWait(result: DisplaySleepProcess.WaitResult) {
        let fake = DisplaySleepFake()
        defer { fake.clearTimers() }
        _ = fake.begin()
        fake.queue.sync {
            fake.waitResults = [result]
            fake.fire(nil)
            #expect(fake.results.isEmpty)
            #expect(fake.child == .running)
            #expect(fake.calls == ["spawn", "wait"])
            fake.fire(.seconds(2))
            #expect(fake.signals == [SIGTERM])
            fake.child = .zombie(0)
            fake.fire(nil)
            #expect(fake.error as? DisplaySleepError == .timedOut)
        }
    }

    @Test("SPEC-BLK-002 ECHILD は所有を失ったエラー。以後 KILL も遅いイベントも送信しない",
          arguments: [false, true])
    func lostOwnership(afterTerm: Bool) {
        let fake = DisplaySleepFake()
        defer { fake.clearTimers() }
        _ = fake.begin()
        fake.queue.sync {
            if afterTerm {
                fake.fire(.seconds(2))
            }
            fake.waitResults = [.failure(ECHILD)]
            fake.fire(afterTerm ? .milliseconds(500) : nil)
            fake.fireAll()
            let error = fake.error as? DisplaySleepCleanupError
            #expect(error?.failure == .systemCall(operation: "waitpid", code: ECHILD))
            #expect(error?.stopReason as? DisplaySleepError == (afterTerm ? .timedOut : nil))
            #expect(fake.signals == (afterTerm ? [SIGTERM] : []))
            #expect(fake.results.count == 1)
            #expect(fake.invalidSignals == 0)
        }
    }

    @Test("SPEC-BLK-002 ESRCH でも回収まで待つ。EPERM は停止成功とせずエラーを保持する",
          arguments: [ESRCH, EPERM], [SIGTERM, SIGKILL])
    func signalFailures(code: Int32, failedSignal: Int32) {
        let fake = DisplaySleepFake()
        defer { fake.clearTimers() }
        _ = fake.begin()
        fake.queue.sync {
            fake.signalErrors[failedSignal] = code
            fake.fire(.seconds(2))
            fake.fire(.milliseconds(500))
            #expect(fake.results.isEmpty)
            #expect(fake.child == .running)
            #expect(fake.signals == [SIGTERM, SIGKILL])
            fake.child = .zombie(0)
            fake.fire(nil)
            if code == ESRCH {
                #expect(fake.error as? DisplaySleepError == .timedOut)
            } else {
                let error = fake.error as? DisplaySleepCleanupError
                let name = failedSignal == SIGTERM ? "kill(SIGTERM)" : "kill(SIGKILL)"
                #expect(error?.failure == .systemCall(operation: name, code: EPERM))
                #expect(error?.stopReason as? DisplaySleepError == .timedOut)
            }
            #expect(fake.results.count == 1)
        }
    }

    @Test("SPEC-BLK-002 その他の wait エラーでも回収済みと偽らず、再試行後にも診断を保持")
    func waitFailure() {
        let fake = DisplaySleepFake()
        defer { fake.clearTimers() }
        _ = fake.begin()
        fake.queue.sync {
            fake.waitResults = [.failure(EIO), .running]
            fake.fire(nil)
            fake.fire(nil)
            #expect(fake.results.isEmpty)
            #expect(fake.child == .running)
            fake.child = .zombie(0)
            fake.fire(nil)
            let error = fake.error as? DisplaySleepCleanupError
            #expect(error?.failure == .systemCall(operation: "waitpid", code: EIO))
            #expect(error?.stopReason == nil)
            #expect(fake.allTimersCancelled)
        }
    }

    @Test("SPEC-BLK-002 spawn の失敗では PID を所有せず、予約した期限も解除する")
    func spawnFailure() {
        let fake = DisplaySleepFake()
        defer { fake.clearTimers() }
        fake.queue.sync { fake.spawnError = .systemCall(operation: "posix_spawn", code: ENOENT) }
        let operation = fake.begin()
        operation.cancel()
        fake.drain()
        fake.queue.sync {
            fake.fireAll()
            #expect(fake.error as? DisplaySleepError == .systemCall(operation: "posix_spawn", code: ENOENT))
            #expect(fake.calls == ["spawn"])
            #expect(fake.child == .notSpawned)
            #expect(fake.allTimersCancelled)
            #expect(fake.results.count == 1)
        }
    }
}

extension PowerPlatformDisplaySleepTests {
    @Test("SPEC-BLK-002 正常・非ゼロ・signal 終了を区別し、二重通知では再開しない",
          arguments: [Int32(0), 7 << 8, SIGTERM, SIGSEGV | 0x80])
    func exitStatus(status: Int32) {
        let fake = DisplaySleepFake()
        defer { fake.clearTimers() }
        let operation = fake.begin()
        fake.queue.sync {
            fake.child = .zombie(status)
            fake.fire(nil)
            if status == 0 {
                #expect(fake.error == nil)
            } else if status == 7 << 8 {
                #expect(fake.error as? DisplaySleepError == .unsuccessfulExit(7))
            } else {
                #expect(fake.error as? DisplaySleepError == .abnormalTermination(status & 0x7F))
            }
            fake.child = .reused
            fake.fireAll()
        }
        operation.cancel()
        fake.drain()
        fake.queue.sync {
            #expect(fake.results.count == 1)
            #expect(fake.signals.isEmpty)
            #expect(fake.allTimersCancelled)
        }
    }

    @Test("SPEC-BLK-002 同時の所有者は別 PID のみを回収・停止する")
    func simultaneousOperations() {
        let first = DisplaySleepFake(pid: 41)
        let second = DisplaySleepFake(pid: 42)
        defer { first.clearTimers(); second.clearTimers() }
        _ = first.begin()
        _ = second.begin()
        first.queue.sync {
            first.fire(.seconds(2))
            first.fire(.milliseconds(500))
        }
        second.queue.sync {
            second.child = .zombie(0)
            second.fire(nil)
            #expect(second.results.count == 1)
            #expect(second.signals.isEmpty)
        }
        first.queue.sync {
            #expect(first.results.isEmpty)
            first.child = .zombie(SIGKILL)
            first.fire(nil)
            #expect(first.error as? DisplaySleepError == .timedOut)
            #expect(first.invalidSignals == 0)
        }
    }

    @Test("SPEC-BLK-002 呼び出し側が所有者を手放しても回収まで保持し、最後に循環を解く")
    func retainedUntilReaped() {
        let fake = DisplaySleepFake()
        var operation: DisplaySleepOperation? = fake.begin()
        weak let retained = operation
        operation = nil
        #expect(retained != nil)
        fake.queue.sync {
            fake.fire(.seconds(2))
            fake.fire(.milliseconds(500))
        }
        #expect(retained != nil)
        fake.queue.sync {
            fake.child = .zombie(SIGKILL)
            fake.fire(nil)
            #expect(fake.allTimersCancelled)
        }
        // fake は stale event 検証のため解除後も callback を保持している。
        fake.clearTimers()
        #expect(retained == nil)
    }

    @MainActor
    @Test("SPEC-BLK-002 公開 async API は起動失敗と事前キャンセルを continuation で返す")
    func publicAPI() async {
        let process = DisplaySleepProcess(spawn: {
            throw DisplaySleepError.systemCall(operation: "fake_spawn", code: ENOENT)
        }, wait: { _ in Issue.record("spawn 失敗後の wait"); return .running }, signal: { _, _ in
            Issue.record("spawn 失敗後の signal"); return 0
        })
        let scheduler = DisplaySleepScheduler(after: { _, _, _ in {} }, poll: { _, _ in
            Issue.record("spawn 失敗後の poll"); return {}
        })
        let display = DisplaySleep(process: process, scheduler: scheduler)
        await #expect(throws: DisplaySleepError.systemCall(operation: "fake_spawn", code: ENOENT)) {
            try await display.sleepDisplay()
        }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await display.sleepDisplay()
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
