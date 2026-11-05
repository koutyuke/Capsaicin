@testable import CapsaicinCore
import Foundation
import Testing

struct LaunchRulesTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func record(running: Bool, exit: ExitReason? = nil, lastUpdated: Date) -> ResumeRecord {
        var record = ResumeRecord(lastUpdated: lastUpdated)
        record.isRunning = running
        record.exitReason = exit
        return record
    }

    @Test("SPEC-LCY-007 記録がなければ通常の起動")
    func noRecord() {
        #expect(LaunchRules.launchReason(record: nil, bootTime: now) == .normal)
        #expect(LaunchRules.launchReason(record: nil, bootTime: .distantPast) == .normal)
    }

    @Test(
        "SPEC-LCY-007 起動時刻が取得不能なら、前回が実行中でもセッションの終了でも通常の起動とする",
        arguments: [(true, ExitReason?.none), (false, .sessionEnd), (false, .userQuit)],
    )
    func unavailableBootTime(running: Bool, exit: ExitReason?) {
        let stored = record(running: running, exit: exit, lastUpdated: now)
        #expect(LaunchRules.launchReason(record: stored, bootTime: .distantPast) == .normal)
        let ancient = record(running: running, exit: exit, lastUpdated: .distantPast.addingTimeInterval(-1))
        #expect(!LaunchRules.hasMacBooted(since: ancient, bootTime: .distantPast))
    }

    @Test("SPEC-LCY-007 実行中の印が立っていれば、起動時刻が最終更新より後なら Mac の再起動の後、そうでなければクラッシュ後")
    func runningFlag() {
        let running = record(running: true, lastUpdated: now)
        #expect(LaunchRules.launchReason(record: running, bootTime: now.addingTimeInterval(1)) == .afterMacRestart)
        #expect(LaunchRules.launchReason(record: running, bootTime: now.addingTimeInterval(-1)) == .afterCrash)
        #expect(LaunchRules.launchReason(record: running, bootTime: now) == .afterCrash)
    }

    @Test("SPEC-LCY-007 起動時刻が記録の最終更新より後なら、Mac が起動したとみなす")
    func macBooted() {
        let stored = record(running: false, exit: .sessionEnd, lastUpdated: now)
        #expect(LaunchRules.hasMacBooted(since: stored, bootTime: now.addingTimeInterval(1)))
        #expect(!LaunchRules.hasMacBooted(since: stored, bootTime: now))
        #expect(!LaunchRules.hasMacBooted(since: stored, bootTime: .distantPast))
    }

    @Test("SPEC-LCY-007 実行中の印がなければ、終了の理由で決める")
    func exitReason() {
        let boot = now.addingTimeInterval(-60)
        let session = record(running: false, exit: .sessionEnd, lastUpdated: now)
        let quit = record(running: false, exit: .userQuit, lastUpdated: now)
        #expect(LaunchRules.launchReason(record: session, bootTime: boot) == .afterMacRestart)
        #expect(LaunchRules.launchReason(record: quit, bootTime: boot) == .normal)
    }

    @Test("SPEC-LCY-007 起動のたびに 10 分より古いものを除き、クラッシュ後なら今回の時刻を加え、3 件以上で上限に達する")
    func crashLimit() {
        let old = now.addingTimeInterval(-601)
        let recent = now.addingTimeInterval(-600)
        let launches = LaunchRules.updatingCrashLaunches([old, recent], at: now, afterCrash: true)
        #expect(launches == [recent, now])
        #expect(LaunchRules.updatingCrashLaunches([old, recent], at: now, afterCrash: false) == [recent])
        #expect(!LaunchRules.isCrashLimitReached(launches))
        #expect(LaunchRules.isCrashLimitReached(launches + [now]))
    }

    @Test(
        "SPEC-LCY-004 起動の理由と再開の設定から再開を試みるかを決める",
        arguments: [
            (LaunchReason.afterCrash, ResumePolicy.never, false),
            (.afterCrash, .afterAppRestart, true),
            (.afterCrash, .afterAppOrMacRestart, true),
            (.afterMacRestart, .never, false),
            (.afterMacRestart, .afterAppRestart, false),
            (.afterMacRestart, .afterAppOrMacRestart, true),
            (.normal, .never, false),
            (.normal, .afterAppRestart, false),
            (.normal, .afterAppOrMacRestart, false),
        ],
    )
    func resumeTable(reason: LaunchReason, policy: ResumePolicy, expected: Bool) {
        let resumes = LaunchRules.shouldResume(
            reason: reason, policy: policy, session: BlockingSession(timeLimit: nil),
            isCrashLimitReached: false, now: now,
        )
        #expect(resumes == expected)
    }

    @Test("SPEC-LCY-004 セッションがない、解除の時刻を過ぎた、連続クラッシュの上限に達したときは再開しない")
    func resumeBlockers() {
        func resumes(_ session: BlockingSession?, limitReached: Bool = false) -> Bool {
            LaunchRules.shouldResume(
                reason: .afterCrash, policy: .afterAppRestart, session: session,
                isCrashLimitReached: limitReached, now: now,
            )
        }
        let expired = BlockingSession(timeLimit: TimeLimit(date: now, source: .timer))
        let future = BlockingSession(timeLimit: TimeLimit(date: now.addingTimeInterval(1), source: .timer))
        #expect(!resumes(nil))
        #expect(!resumes(expired))
        #expect(resumes(future))
        #expect(!resumes(future, limitReached: true))
    }

    @Test("SPEC-LCY-007 記録を読み直すと同じ値になり、欠けたキーは既定値で補う")
    func recordCoding() throws {
        var original = ResumeRecord(lastUpdated: now)
        original.session = BlockingSession(timeLimit: TimeLimit(date: now, source: .specifiedTime))
        original.ownsSleepDisabled = true
        original.isRunning = true
        original.misalignments = [.systemSleepDisabled: .leftApplied, .led: .notApplied]
        original.crashLaunches = [now]
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(ResumeRecord.self, from: data) == original)

        let partialJSON = #"{"lastUpdated": 0, "isRunning": true, "x": 1}"#
        let partial = try JSONDecoder().decode(ResumeRecord.self, from: Data(partialJSON.utf8))
        var expected = ResumeRecord(lastUpdated: Date(timeIntervalSinceReferenceDate: 0))
        expected.isRunning = true
        #expect(partial == expected)
    }

    @Test("SPEC-LCY-007 最終更新の時刻のない記録は読めない記録とする")
    func recordWithoutLastUpdated() {
        let json = Data(#"{"isRunning": true, "ownsSleepDisabled": true}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ResumeRecord.self, from: json) }
    }

    @Test("SPEC-LCY-007 セッションがあって解除の時刻を持たない記録と、セッションのない記録を区別する")
    func sessionWithoutTimeLimit() throws {
        var original = ResumeRecord(lastUpdated: now)
        original.session = BlockingSession(timeLimit: nil)
        let decoded = try JSONDecoder().decode(ResumeRecord.self, from: JSONEncoder().encode(original))
        #expect(decoded.session == BlockingSession(timeLimit: nil))
    }
}
