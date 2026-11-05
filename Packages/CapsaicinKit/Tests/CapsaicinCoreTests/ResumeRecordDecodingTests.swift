@testable import CapsaicinCore
import Foundation
import Testing

struct ResumeRecordDecodingTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var runningRecord: ResumeRecord {
        var record = ResumeRecord(lastUpdated: now)
        record.session = BlockingSession(timeLimit: TimeLimit(date: now.addingTimeInterval(60), source: .timer))
        record.ownsSleepDisabled = true
        record.isRunning = true
        record.exitReason = .sessionEnd
        record.misalignments = [.systemSleepDisabled: .leftApplied, .led: .notApplied]
        record.crashLaunches = [now.addingTimeInterval(-60), now.addingTimeInterval(-30)]
        return record
    }

    private func data(replacing key: String, with value: Any?) throws -> Data {
        let encoded = try JSONEncoder().encode(runningRecord)
        var fields = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        fields[key] = value
        return try JSONSerialization.data(withJSONObject: fields)
    }

    @Test("SPEC-LCY-007 通常の記録と全項目を持つ記録と解除の時刻のないセッションを読み戻せる")
    func roundTrip() throws {
        var indefinite = runningRecord
        indefinite.session = BlockingSession(timeLimit: nil)
        for record in [ResumeRecord(lastUpdated: now), runningRecord, indefinite] {
            let encoded = try JSONEncoder().encode(record)
            #expect(try JSONDecoder().decode(ResumeRecord.self, from: encoded) == record)
        }
    }

    @Test("SPEC-LCY-007 最終更新以外のキーが欠けていれば既定値で補う")
    func missingKeysUseDefaults() throws {
        let encoded = Data(#"{"lastUpdated":0}"#.utf8)
        let expected = ResumeRecord(lastUpdated: Date(timeIntervalSinceReferenceDate: 0))
        #expect(try JSONDecoder().decode(ResumeRecord.self, from: encoded) == expected)
    }

    @Test("SPEC-LCY-007 未知のキーを無視し、既知の値を保つ")
    func unknownKeysAreIgnored() throws {
        let encoded = try data(replacing: "futureField", with: ["nested": NSNull()])
        #expect(try JSONDecoder().decode(ResumeRecord.self, from: encoded) == runningRecord)
    }

    @Test("SPEC-LCY-007 最終更新のキーは省略できない")
    func missingLastUpdatedThrows() throws {
        let encoded = try data(replacing: "lastUpdated", with: nil)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ResumeRecord.self, from: encoded) }
    }

    @Test("SPEC-LCY-007 任意のセッションと終了理由は null を許す", arguments: ["session", "exitReason"])
    func optionalNullsAreAccepted(key: String) throws {
        let encoded = try data(replacing: key, with: NSNull())
        var expected = runningRecord
        if key == "session" {
            expected.session = nil
        } else {
            expected.exitReason = nil
        }
        #expect(try JSONDecoder().decode(ResumeRecord.self, from: encoded) == expected)
    }

    @Test(
        "SPEC-LCY-007 実行中の記録の既知の値が不正なら記録全体を拒否する",
        arguments: [
            "session",
            "ownsSleepDisabled",
            "isRunning",
            "exitReason",
            "misalignments",
            "lastUpdated",
            "crashLaunches",
        ],
    )
    func malformedFieldsThrow(key: String) throws {
        let encoded = try data(replacing: key, with: "invalid")
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ResumeRecord.self, from: encoded) }
    }

    @Test(
        "SPEC-LCY-007 必須の値が null なら既定値で補わず記録全体を拒否する",
        arguments: ["ownsSleepDisabled", "isRunning", "misalignments", "lastUpdated", "crashLaunches"],
    )
    func nonoptionalNullsThrow(key: String) throws {
        let encoded = try data(replacing: key, with: NSNull())
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ResumeRecord.self, from: encoded) }
    }

    @Test(
        "SPEC-LCY-007 セッションや一覧の内部の値が不正でも記録全体を拒否する",
        arguments: [
            ("session", #"{"timeLimit":{"date":"invalid","source":"timer"}}"#),
            ("session", #"{"timeLimit":{"date":0,"source":"invalid"}}"#),
            ("misalignments", #"{"led":"invalid"}"#),
            ("crashLaunches", #"[0,"invalid"]"#),
        ],
    )
    func malformedNestedValuesThrow(key: String, json: String) throws {
        let value = try JSONSerialization.jsonObject(with: Data(json.utf8))
        let encoded = try data(replacing: key, with: value)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ResumeRecord.self, from: encoded) }
    }

    @Test("SPEC-LCY-007 クラッシュ履歴だけが壊れた記録を部分的に読み込んで再開しない")
    func corruptedCrashHistoryCannotResume() throws {
        let encoded = try data(replacing: "crashLaunches", with: "invalid")
        let record = try? JSONDecoder().decode(ResumeRecord.self, from: encoded)
        #expect(record == nil)
        let reason = LaunchRules.launchReason(record: record, bootTime: now.addingTimeInterval(-120))
        #expect(reason == .normal)
        let launches = LaunchRules.updatingCrashLaunches(
            record?.crashLaunches ?? [], at: now, afterCrash: reason == .afterCrash,
        )
        #expect(!LaunchRules.shouldResume(
            reason: reason, policy: .afterAppOrMacRestart, session: record?.session,
            isCrashLimitReached: LaunchRules.isCrashLimitReached(launches), now: now,
        ))
    }
}
