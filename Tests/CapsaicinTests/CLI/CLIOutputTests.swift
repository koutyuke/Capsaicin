import CapsaicinCore
import CapsaicinIPC
import Darwin
import Foundation
import Testing

struct CLIOutputTests {
    private let now = Date(timeIntervalSince1970: 19380)
    private let stopped = BlockingStatus(
        session: nil,
        batteryCondition: nil,
        misalignments: [:],
    )

    private func render(_ outcome: IPCOutcome, status: BlockingStatus,
                        stdoutColor: Bool = false, stderrColor: Bool = false) throws -> CLIOutput
    {
        try CLIOutput.response(IPCResponse(outcome: outcome, status: status), now: now,
                               timeZone: #require(TimeZone(secondsFromGMT: 9 * 3600)),
                               stdoutColor: stdoutColor, stderrColor: stderrColor)
    }

    private func active(seconds: TimeInterval? = nil, battery: Bool = false,
                        ignoresOnACPower: Bool = true, source: TimeLimitSource = .timer) throws -> BlockingStatus
    {
        var status = stopped
        status.session = BlockingSession(timeLimit: seconds.map { TimeLimit(
            date: now.addingTimeInterval($0),
            source: source,
        ) })
        if battery {
            status.batteryCondition = try BatteryCondition(threshold: #require(BatteryThreshold(percent: 20)),
                                                           ignoresOnACPower: ignoresOnACPower)
        }
        return status
    }

    @Test("SPEC-CLI-003 SPEC-CLI-007 開始時は応答の時刻とバッテリー条件を英語で表示する",
          arguments: [TimeLimitSource.timer, .specifiedTime], [false, true])
    func started(source: TimeLimitSource, ignoresAC: Bool) throws {
        let output = try render(
            .started,
            status: active(seconds: 5400, battery: true, ignoresOnACPower: ignoresAC, source: source),
        )
        #expect(output.exitCode == .success)
        #expect(output.standardOutput == "✓ Sleep prevention on\n  Turns off  15:53 (in 1h 30m)\n"
            + "  Battery    turns off below 20%" + (ignoresAC ? ", except on AC power" : "") + "\n")
        #expect(output.standardError.isEmpty)
    }

    @Test("SPEC-CLI-003 SPEC-CLI-007 抑止中の各結果を詳細とともに標準出力へ出す", arguments: [
        (IPCOutcome.started, "✓ Sleep prevention on\n"),
        (.timeLimitReplaced, "✓ Turn-off time updated\n"),
        (.alreadyBlocking, "• Sleep prevention is already on\n"),
        (.status, "● Sleep prevention on\n"),
    ])
    func activeOutcomes(outcome: IPCOutcome, firstLine: String) throws {
        let output = try render(outcome, status: active())
        let hint = outcome == .alreadyBlocking ?
            "  Use --for, --until or --no-time-limit to change when it turns off.\n" : ""
        #expect(output.exitCode == .success)
        #expect(output.standardOutput == firstLine + "  Turns off  when you turn it off\n" + hint)
        #expect(output.standardError.isEmpty)
    }

    @Test("SPEC-CLI-003 SPEC-CLI-007 停止中の各結果には詳細を出さない", arguments: [
        (IPCOutcome.released, "✓ Sleep prevention off\n", ExitCode.success),
        (.alreadyStopped, "• Sleep prevention is already off\n", .success),
        (.status, "○ Sleep prevention off\n", .stopped),
    ])
    func stoppedOutcomes(outcome: IPCOutcome, expected: String, code: ExitCode) throws {
        var status = stopped
        status.batteryCondition = try active(battery: true).batteryCondition
        let output = try render(outcome, status: status)
        #expect(output.exitCode == code)
        #expect(output.standardOutput == expected)
        #expect(output.standardError.isEmpty)
    }

    @Test("SPEC-CLI-003 残り時間は分に切り捨て、時刻は固定タイムゾーンの24時間制で示す", arguments: [
        (5400.0, "15:53 (in 1h 30m)"),
        (7200.0, "16:23 (in 2h)"),
        (2700.0, "15:08 (in 45m)"),
        (59.0, "14:23 (in under a minute)"),
        (3599.0, "15:22 (in 59m)"),
    ])
    func remainingTime(seconds: TimeInterval, expected: String) throws {
        let output = try render(.status, status: active(seconds: seconds))
        #expect(output.exitCode == .success)
        #expect(output.standardOutput == "● Sleep prevention on\n  Turns off  " + expected + "\n")
        #expect(output.standardError.isEmpty)
    }

    @Test("SPEC-CLI-001 SPEC-CLI-007 時間の置き換えは新しい時刻を表示する")
    func replacement() throws {
        let output = try render(.timeLimitReplaced, status: active(seconds: 5399))
        #expect(output.exitCode == .success)
        #expect(output.standardOutput == "✓ Turn-off time updated\n  Turns off  15:52 (in 1h 29m)\n")
        #expect(output.standardError.isEmpty)
    }

    @Test("SPEC-CLI-007 開始拒否と要求の拒否は標準エラーだけに理由を出す", arguments: [
        (IPCOutcome.startRejected(.batteryBelowThreshold), "the battery is below the threshold set in Settings"),
        (.startRejected(.helperNotInstalled), "the helper isn't installed; install or repair it in Settings"),
        (.startRejected(.mechanismsFailed([.displaySleepAssertion, .systemSleepDisabled, .idleSleepAssertion, .led])),
         "couldn't prevent system sleep; couldn't prevent idle sleep; couldn't prevent display sleep; couldn't light the Caps Lock LED"),
    ])
    func rejected(outcome: IPCOutcome, reason: String) throws {
        let output = try render(outcome, status: stopped)
        #expect(output.exitCode == .unavailable)
        #expect(output.standardOutput.isEmpty)
        #expect(output.standardError == "error: couldn't turn on sleep prevention: " + reason + "\n")
    }

    @Test("SPEC-CLI-007 バッテリーによる拒否は応答のしきい値を表示する")
    func batteryRejected() throws {
        var status = stopped
        status.batteryCondition = try BatteryCondition(
            threshold: #require(BatteryThreshold(percent: 35)),
            ignoresOnACPower: false,
        )
        let output = try render(.startRejected(.batteryBelowThreshold), status: status)
        #expect(output.exitCode == .unavailable)
        #expect(output.standardOutput.isEmpty)
        #expect(output.standardError == "error: couldn't turn on sleep prevention: the battery is below 35%\n")
    }

    @Test("SPEC-CLI-007 CLI 無効とバージョン違いは、抑止中でも標準出力に何も出さない", arguments: [
        (IPCOutcome.cliRequestsDisabled, "commands from the CLI are turned off in Capsaicin Settings"),
        (.unsupportedVersion, "this command and the running Capsaicin are different versions"),
    ])
    func requestRejected(outcome: IPCOutcome, reason: String) throws {
        let output = try render(outcome, status: active())
        #expect(output.exitCode == .unavailable)
        #expect(output.standardOutput.isEmpty)
        #expect(output.standardError == "error: " + reason + "\n")
    }
}

extension CLIOutputTests {
    @Test("SPEC-CLI-003 SPEC-CLI-007 全結果で制御、輝度の記録の保存・削除の順に警告を標準エラーへ出す",
          arguments: [IPCOutcome.started, .timeLimitReplaced, .alreadyBlocking, .released, .alreadyStopped, .status,
                      .cliRequestsDisabled, .unsupportedVersion, .startRejected(.batteryBelowThreshold),
                      .startRejected(.helperNotInstalled),
                      .startRejected(.mechanismsFailed([.idleSleepAssertion]))],
          [MisalignmentDirection.leftApplied, .notApplied])
    func warnings(outcome: IPCOutcome, direction: MisalignmentDirection) throws {
        let base = try render(outcome, status: stopped)
        var status = stopped
        for mechanism in Mechanism.allCases.reversed() {
            status.misalignments[mechanism] = direction
        }
        status.brightnessWarnings = [.saveFailed, .deletionFailed]
        let output = try render(outcome, status: status)
        let warnings = direction == .leftApplied
            ? "warning: couldn't restore system sleep\nwarning: couldn't restore idle sleep\n"
            + "warning: couldn't restore display sleep\nwarning: couldn't turn off the Caps Lock LED\n"
            : "warning: couldn't prevent system sleep\nwarning: couldn't prevent idle sleep\n"
            + "warning: couldn't prevent display sleep\nwarning: couldn't light the Caps Lock LED\n"
        #expect(output.standardOutput == base.standardOutput)
        #expect(output.standardError == base.standardError + warnings
            + "warning: couldn't save the display brightness record\n"
            + "warning: couldn't delete the display brightness record\n")
        #expect(output.exitCode == IPCResponse(outcome: outcome, status: status).exitCode)
        if outcome == .released || outcome == .alreadyStopped {
            #expect(output.exitCode == .unavailable)
        }
    }

    @Test("SPEC-CLI-003 SPEC-CLI-007 輝度の記録だけの警告は標準出力と終了コードを変えない",
          arguments: [IPCOutcome.started, .alreadyBlocking, .released, .alreadyStopped, .status],
          [BrightnessRecordWarning.saveFailed, .deletionFailed])
    func brightnessWarning(outcome: IPCOutcome, warning: BrightnessRecordWarning) throws {
        var status = warning == .saveFailed ? try active() : stopped
        let base = try render(outcome, status: status)
        status.brightnessWarnings = [warning]
        let output = try render(outcome, status: status)
        #expect(output.standardOutput == base.standardOutput)
        #expect(output.exitCode == base.exitCode)
        let action = warning == .saveFailed ? "save" : "delete"
        #expect(output.standardError == "warning: couldn't \(action) the display brightness record\n")
    }

    @Test("SPEC-CLI-007 引数の各誤りは理由とヘルプの案内を出す", arguments: [
        (CLIArgumentError.missingSubcommand, "missing command"),
        (.unknownSubcommand("foo"), "unknown command \"foo\""),
        (.unexpectedArgument("foo"), "unexpected argument \"foo\""),
        (.missingValue(option: "--for"), "--for requires a value"),
        (.duplicateOption("--for"), "--for can only be used once"),
        (.duplicateOption("--no-time-limit"), "--no-time-limit can only be used once"),
        (.conflictingOptions, "--for, --until and --no-time-limit can't be used together"),
        (.invalidDuration("90"), "invalid duration \"90\" for --for; use 30m, 2h or 1h30m"),
        (.durationOutOfRange("25h"), "duration \"25h\" for --for is out of range; use 1m to 24h"),
        (.invalidTime("24:00"), "invalid time \"24:00\" for --until; use H:MM, e.g. 4:00"),
        (.unknownSubcommand("bad\ncommand"), "unknown command \"bad\\ncommand\""),
        (.unexpectedArgument("bad\nargument"), "unexpected argument \"bad\\nargument\""),
        (.invalidDuration("x\ny"), "invalid duration \"x\\ny\" for --for; use 30m, 2h or 1h30m"),
        (.durationOutOfRange("25h\n"), "duration \"25h\\n\" for --for is out of range; use 1m to 24h"),
        (.invalidTime("x\ny"), "invalid time \"x\\ny\" for --until; use H:MM, e.g. 4:00"),
    ])
    func usageErrors(error: CLIArgumentError, reason: String) {
        let output = CLIOutput.usage(error)
        #expect(output.exitCode == .usage)
        #expect(output.standardOutput.isEmpty)
        #expect(output.standardError == "error: " + reason + "\nRun 'capsaicin --help' for usage.\n")
    }

    @Test("SPEC-CLI-007 接続失敗は種類ごとの文言と終了コード69を返す")
    func connectionFailures() {
        let cases: [(any Error, String)] = [
            (
                IPCTransportError.system(EACCES),
                "couldn't communicate with Capsaicin; the request may already have taken effect",
            ),
            (
                IPCTransportError.unavailable(ECONNREFUSED),
                "couldn't communicate with Capsaicin; the request may already have taken effect",
            ),
            (IPCTransportError.timedOut, "Capsaicin didn't respond in time; the request may already have taken effect"),
            (CLIRunnerError.launchFailed, "couldn't launch Capsaicin"),
            (IPCTransportError.invalidFrame, "received an invalid response from Capsaicin"),
            (IPCCoding.DecodingFailure.malformed, "received an invalid response from Capsaicin"),
            (IPCTransportError.peerRejected, "couldn't verify the connection to Capsaicin"),
            (IPCTransportError.unsafeEndpoint, "couldn't verify the connection to Capsaicin"),
            (
                IPCCoding.DecodingFailure.unsupportedVersion(0),
                "this command and the running Capsaicin are different versions",
            ),
            (CLIApplicationError.invalidBundle, "run this command from inside Capsaicin.app"),
        ]
        for (error, reason) in cases {
            let output = CLIOutput.failure(error)
            #expect(output.exitCode == .unavailable)
            #expect(output.standardOutput.isEmpty)
            #expect(output.standardError == "error: " + reason + "\n")
        }
    }
}

extension CLIOutputTests {
    @Test("SPEC-CLI-003 SPEC-CLI-007 色は端末・NO_COLOR・TERM の組み合わせで決まる",
          arguments: [false, true], [
              ([String: String](), true), (["NO_COLOR": ""], true),
              (["NO_COLOR": "1"], false), (["NO_COLOR": "0"], false),
              (["TERM": "dumb"], false), (["TERM": "xterm-256color"], true),
              (["NO_COLOR": "", "TERM": "dumb"], false),
              (["NO_COLOR": "1", "TERM": "xterm-256color"], false),
          ])
    func colorPolicy(isTerminal: Bool, configuration: ([String: String], Bool)) {
        #expect(CLIOutput
            .usesColor(isTerminal: isTerminal, environment: configuration.0) == (isTerminal && configuration.1))
    }

    @Test("SPEC-CLI-003 SPEC-CLI-007 色ありの結果・詳細・警告の全体を確かめる")
    func coloredOutput() throws {
        var status = try active(seconds: 5400, battery: true)
        status.misalignments = [.led: .notApplied]
        let output = try render(.started, status: status, stdoutColor: true, stderrColor: true)
        #expect(output.exitCode == .success)
        #expect(output.standardOutput == "\u{1B}[32m✓\u{1B}[0m \u{1B}[1mSleep prevention on\u{1B}[0m\n"
            + "  \u{1B}[2mTurns off\u{1B}[0m  15:53 (in 1h 30m)\n"
            + "  \u{1B}[2mBattery  \u{1B}[0m  turns off below 20%, except on AC power\n")
        #expect(output.standardError == "\u{1B}[1;33mwarning:\u{1B}[0m couldn't light the Caps Lock LED\n")
    }

    @Test("SPEC-CLI-003 記号と太字の色、変更の案内を確かめる", arguments: [
        (IPCOutcome.status, true, "32", "●", "Sleep prevention on"),
        (.status, false, "2", "○", "Sleep prevention off"),
        (.alreadyBlocking, true, "2", "•", "Sleep prevention is already on"),
        (.alreadyStopped, false, "2", "•", "Sleep prevention is already off"),
    ])
    func coloredHeadlines(outcome: IPCOutcome, blocking: Bool, code: String, symbol: String, message: String) throws {
        let output = try render(outcome, status: blocking ? active() : stopped, stdoutColor: true)
        var expected = "\u{1B}[\(code)m\(symbol)\u{1B}[0m \u{1B}[1m\(message)\u{1B}[0m\n"
        if blocking {
            expected += "  \u{1B}[2mTurns off\u{1B}[0m  when you turn it off\n"
        }
        if outcome == .alreadyBlocking {
            expected += "\u{1B}[2m  Use --for, --until or --no-time-limit to change when it turns off.\u{1B}[0m\n"
        }
        #expect(output.standardOutput == expected)
        #expect(output.standardError.isEmpty)
    }

    @Test("SPEC-CLI-007 エラーの接頭辞だけを太字の赤にする")
    func coloredError() {
        let output = CLIOutput.usage(.missingSubcommand, color: true)
        #expect(output.standardOutput.isEmpty)
        #expect(output
            .standardError == "\u{1B}[1;31merror:\u{1B}[0m missing command\nRun 'capsaicin --help' for usage.\n")
    }

    @Test("SPEC-CLI-003 SPEC-CLI-007 stdout と stderr の色は独立している",
          arguments: [(false, true), (true, false)])
    func separateStreamColors(stdout: Bool, stderr: Bool) throws {
        var status = stopped
        status.brightnessWarnings = [.deletionFailed]
        let output = try render(.released, status: status, stdoutColor: stdout, stderrColor: stderr)
        #expect(output.standardOutput.contains("\u{1B}[") == stdout)
        #expect(output.standardError.contains("\u{1B}[") == stderr)
    }
}
