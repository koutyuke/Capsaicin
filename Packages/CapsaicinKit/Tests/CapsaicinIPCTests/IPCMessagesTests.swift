import CapsaicinCore
@testable import CapsaicinIPC
import Foundation
import Testing

struct IPCMessagesTests {
    private let stopped = BlockingStatus(
        session: nil,
        batteryCondition: nil,
        misalignments: [:],
    )
    private var blocking: BlockingStatus {
        var status = stopped
        status.session = BlockingSession(timeLimit: TimeLimit(date: Date(timeIntervalSince1970: 0), source: .timer))
        return status
    }

    @Test("SPEC-CLI-001 要求はバージョン付きで読み書きでき、時間の指定を保つ")
    func requestRoundTrip() throws {
        for command in try [IPCCommand.start(nil), .start(.timer(#require(TimerDuration(minutes: 90)))),
                            .start(.specifiedTime(#require(TimeOfDay(hour: 4, minute: 0)))),
                            .start(.noTimeLimit), .stop, .status]
        {
            let request = IPCRequest(command: command)
            #expect(try IPCCoding.decodeRequest(IPCCoding.encode(request)) == request)
        }
    }

    @Test("SPEC-CLI-003 応答は状態と輝度の記録の警告を読み書きできる")
    func responseRoundTrip() throws {
        var status = blocking
        status.misalignments = [.systemSleepDisabled: .leftApplied]
        status.brightnessWarnings = [.saveFailed, .deletionFailed]
        status.batteryCondition = try BatteryCondition(
            threshold: #require(BatteryThreshold(percent: 20)),
            ignoresOnACPower: true,
        )
        for outcome: IPCOutcome in [.timeLimitReplaced, .startRejected(.mechanismsFailed([.displaySleepAssertion]))] {
            let response = IPCResponse(outcome: outcome, status: status)
            #expect(try IPCCoding.decodeResponse(IPCCoding.encode(response)) == response)
        }
    }

    @Test("SPEC-CLI-007 バージョンの違う要求は中身を読まずに拒む", arguments: [1, 2])
    func versionMismatch(version: Int) {
        let data = Data(#"{"version": \#(version), "command": {"unknown": {}}}"#.utf8)
        #expect(throws: IPCCoding.DecodingFailure.unsupportedVersion(version)) { try IPCCoding.decodeRequest(data) }
    }

    @Test("SPEC-CLI-001 範囲外の時間や壊れた要求は境界で拒む")
    func malformedRequests() throws {
        let request = try IPCRequest(command: .start(.timer(#require(TimerDuration(minutes: 30)))))
        let valid = try #require(String(bytes: IPCCoding.encode(request), encoding: .utf8))
        let outOfRange = valid.replacingOccurrences(of: "30", with: "0")
        #expect(throws: IPCCoding.DecodingFailure.malformed) { try IPCCoding.decodeRequest(Data(outOfRange.utf8)) }
        #expect(throws: IPCCoding.DecodingFailure.malformed) { try IPCCoding.decodeRequest(Data("not json".utf8)) }
        let missing = Data("{\"version\":\(IPCProtocol.version)}".utf8)
        #expect(throws: IPCCoding.DecodingFailure.malformed) { try IPCCoding.decodeRequest(missing) }
    }

    @Test("SPEC-CLI-007 SPEC-BLK-011 開始の結果から終了コードを決める")
    func startExitCodes() {
        var leftover = blocking
        leftover.misalignments = [.led: .notApplied]
        #expect(IPCResponse(outcome: .started, status: leftover).exitCode == .success)
        leftover.brightnessWarnings = [.saveFailed]
        #expect(IPCResponse(outcome: .timeLimitReplaced, status: leftover).exitCode == .success)
        #expect(IPCResponse(outcome: .alreadyBlocking, status: leftover).exitCode == .success)
        #expect(IPCResponse(outcome: .startRejected(.helperNotInstalled), status: stopped).exitCode == .unavailable)
        #expect(IPCResponse(outcome: .cliRequestsDisabled, status: blocking).exitCode == .unavailable)
        #expect(IPCResponse(outcome: .unsupportedVersion, status: stopped).exitCode == .unavailable)
    }

    @Test("SPEC-CLI-007 SPEC-BLK-011 輝度の記録の警告だけなら解除は 0、合わせられていない制御が残れば 69")
    func stopExitCodes() {
        var leftover = stopped
        leftover.misalignments = [.systemSleepDisabled: .leftApplied]
        var deletionFailed = stopped
        deletionFailed.brightnessWarnings = [.deletionFailed]
        #expect(IPCResponse(outcome: .released, status: stopped).exitCode == .success)
        #expect(IPCResponse(outcome: .alreadyStopped, status: stopped).exitCode == .success)
        #expect(IPCResponse(outcome: .released, status: leftover).exitCode == .unavailable)
        #expect(IPCResponse(outcome: .released, status: deletionFailed).exitCode == .success)
        #expect(IPCResponse(outcome: .alreadyStopped, status: deletionFailed).exitCode == .success)
    }

    @Test("SPEC-CLI-003 SPEC-CLI-007 status は警告によらず、抑止中なら 0、停止中なら 1")
    func statusExitCodes() {
        var leftover = stopped
        leftover.misalignments = [.led: .leftApplied]
        leftover.brightnessWarnings = [.deletionFailed]
        var saveFailed = blocking
        saveFailed.brightnessWarnings = [.saveFailed]
        #expect(IPCResponse(outcome: .status, status: saveFailed).exitCode == .success)
        #expect(IPCResponse(outcome: .status, status: leftover).exitCode == .stopped)
        #expect(ExitCode.usage.rawValue == 64)
        #expect(ExitCode.unavailable.rawValue == 69)
    }
}
