import CapsaicinCore
import CapsaicinIPC
import Foundation
import Testing

struct CLIOutputTests {
    private let stopped = BlockingStatus(
        session: nil,
        batteryCondition: nil,
        misalignments: [:],
        isRecordUnsaved: false,
    )

    @Test("SPEC-CLI-003 SPEC-CLI-007 status の警告は stdout の1行に収まり終了コードを変えない")
    func statusWarnings() {
        var status = stopped
        status.misalignments = [.led: .leftApplied]
        status.isRecordUnsaved = true
        let output = CLIOutput.response(IPCResponse(outcome: .status, status: status), text: .keys)
        #expect(output.exitCode == .stopped)
        #expect(output.standardError.isEmpty)
        #expect(output.standardOutput.split(separator: "\n").count == 1)
        #expect(output.standardOutput.contains("warning.unsaved"))
        #expect(output.standardOutput.contains("direction.leftApplied"))
    }

    @Test("SPEC-BLK-011 指定のない開始では、すでに抑止中であることを伝える")
    func alreadyBlocking() {
        let output = CLIOutput.response(IPCResponse(outcome: .alreadyBlocking, status: stopped), text: .keys)
        #expect(output.exitCode == .success)
        #expect(output.standardOutput.contains("outcome.alreadyBlocking"))
    }

    @Test("SPEC-CLI-007 SPEC-BLK-011 全結果の終了コードとエラーのストリームは応答をそのまま使う")
    func allOutcomes() {
        let outcomes: [IPCOutcome] = [
            .started, .timeLimitReplaced, .alreadyBlocking, .released, .alreadyStopped, .status,
            .cliRequestsDisabled, .unsupportedVersion,
            .startRejected(.batteryBelowThreshold), .startRejected(.helperNotInstalled),
            .startRejected(.recordNotSaved), .startRejected(.mechanismsFailed([.idleSleepAssertion])),
        ]
        for outcome in outcomes {
            for warnings in [false, true] {
                var status = stopped
                status.isRecordUnsaved = warnings
                let response = IPCResponse(outcome: outcome, status: status)
                let output = CLIOutput.response(response, text: .keys)
                #expect(output.exitCode == response.exitCode)
                #expect(output.standardError.isEmpty == (response.exitCode != .unavailable))
                #expect(output.standardOutput.isEmpty == (response.exitCode == .unavailable))
                #expect((output.standardError + output.standardOutput).split(separator: "\n").count == 1)
            }
        }
    }

    @Test("SPEC-CLI-003 解除の日時・由来とバッテリー条件は応答の値を表示する", arguments: [TimeLimitSource.timer, .specifiedTime])
    func responseConditions(source: TimeLimitSource) throws {
        var status = stopped
        status.session = BlockingSession(timeLimit: TimeLimit(date: Date(timeIntervalSince1970: 0), source: source))
        status.batteryCondition = try BatteryCondition(
            threshold: #require(BatteryThreshold(percent: 35)),
            ignoresOnACPower: true,
        )
        let output = CLIOutput.response(IPCResponse(outcome: .status, status: status), text: .keys)
        #expect(output.exitCode == .success)
        #expect(output.standardOutput.contains("1970-01-01T00:00:00Z"))
        #expect(output.standardOutput.contains(source == .timer ? "condition.timer" : "condition.specifiedTime"))
        #expect(output.standardOutput.contains("condition.battery 35"))
        #expect(output.standardOutput.contains("condition.ignoresAC"))
    }

    @Test("SPEC-CLI-007 引数の各エラーを標準エラーへ出し、入力の改行をそのまま表示しない")
    func usageErrors() {
        let errors: [CLIArgumentError] = [
            .missingSubcommand, .unknownSubcommand("bad\ncommand"), .unexpectedArgument("bad\nargument"),
            .missingValue(option: "--for"), .duplicateOption("--for"), .conflictingOptions,
            .invalidDuration("x\ny"), .durationOutOfRange("99999h"), .invalidTime("x\ny"),
        ]
        for error in errors {
            let output = CLIOutput.usage(error, text: .keys)
            #expect(output.exitCode == .usage)
            #expect(output.standardOutput.isEmpty)
            #expect(output.standardError.hasPrefix("error.usage"))
            #expect(output.standardError.split(separator: "\n").count == 1)
        }
    }
}
