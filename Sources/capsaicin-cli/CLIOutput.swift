import CapsaicinCore
import CapsaicinIPC
import Foundation

struct CLIOutput {
    var exitCode: ExitCode
    var standardOutput = ""
    var standardError = ""

    static let help = CLIOutput(exitCode: .success, standardOutput: """
    Turn Capsaicin's sleep prevention on and off from the command line.

    Usage: capsaicin <command> [options]

    Commands:
      on        Turn on sleep prevention
      off       Turn off sleep prevention
      status    Show whether sleep prevention is on

    Options for on:
      --for <duration>    Turn off after a duration: 30m, 2h, 1h30m (1m to 24h)
      --until <time>      Turn off at a time of day: 4:00, 23:30 (24-hour)
      --no-time-limit     Don't turn off at a set time
      Without these options, on uses the timer and time set in Settings.
      While on, these options change when it turns off.

    Options:
      -h, --help          Show this help

    Exit status:
      0   Success. For status, sleep prevention is on.
      1   For status, sleep prevention is off.
      64  Invalid command or option.
      69  The request couldn't be completed.

    """)

    private static let unsaved = "couldn't save the state used to resume after a relaunch"
    private static let version = "this command and the running Capsaicin are different versions"

    static func usesColor(isTerminal: Bool, environment: [String: String]) -> Bool {
        isTerminal && (environment["NO_COLOR"] ?? "").isEmpty && environment["TERM"] != "dumb"
    }

    static func response(_ response: IPCResponse, now: Date, timeZone: TimeZone,
                         stdoutColor: Bool = false, stderrColor: Bool = false) -> CLIOutput
    {
        var output = result(response, stdoutColor: stdoutColor, stderrColor: stderrColor)
        if !output.standardOutput.isEmpty {
            output.standardOutput += details(response.status, now: now, timeZone: timeZone, color: stdoutColor)
            if response.outcome == .alreadyBlocking {
                output.standardOutput += styled(
                    "  Use --for, --until or --no-time-limit to change when it turns off.",
                    "2",
                    color: stdoutColor,
                ) + "\n"
            }
        }
        for mechanism in Mechanism.allCases {
            if let direction = response.status.misalignments[mechanism] {
                output.standardError += diagnostic(
                    "warning",
                    misalignment(mechanism, direction: direction),
                    color: stderrColor,
                )
            }
        }
        if response.status.isRecordUnsaved {
            output.standardError += diagnostic("warning", unsaved, color: stderrColor)
        }
        return output
    }

    private static func result(_ response: IPCResponse, stdoutColor: Bool, stderrColor: Bool) -> CLIOutput {
        var output = CLIOutput(exitCode: response.exitCode)
        switch response.outcome {
        case .started: output.standardOutput = headline("✓", "Sleep prevention on", color: stdoutColor)
        case .timeLimitReplaced: output.standardOutput = headline("✓", "Turn-off time updated", color: stdoutColor)
        case .alreadyBlocking: output.standardOutput = headline(
                "•",
                "Sleep prevention is already on",
                color: stdoutColor,
            )
        case .released: output.standardOutput = headline("✓", "Sleep prevention off", color: stdoutColor)
        case .alreadyStopped: output.standardOutput = headline(
                "•",
                "Sleep prevention is already off",
                color: stdoutColor,
            )
        case .status:
            output.standardOutput = response.status.isBlocking
                ? headline("●", "Sleep prevention on", color: stdoutColor)
                : headline("○", "Sleep prevention off", color: stdoutColor)
        case let .startRejected(reason):
            output.standardError = diagnostic("error", "couldn't turn on sleep prevention: "
                + rejection(reason, status: response.status), color: stderrColor)
        case .cliRequestsDisabled:
            output.standardError = diagnostic(
                "error",
                "commands from the CLI are turned off in Capsaicin Settings",
                color: stderrColor,
            )
        case .unsupportedVersion:
            output.standardError = diagnostic("error", version, color: stderrColor)
        }
        return output
    }

    static func usage(_ error: CLIArgumentError, color: Bool = false) -> CLIOutput {
        let reason = switch error {
        case .missingSubcommand: "missing command"
        case let .unknownSubcommand(value): "unknown command \(String(reflecting: value))"
        case let .unexpectedArgument(value): "unexpected argument \(String(reflecting: value))"
        case let .missingValue(option): "\(option) requires a value"
        case let .duplicateOption(option): "\(option) can only be used once"
        case .conflictingOptions: "--for, --until and --no-time-limit can't be used together"
        case let .invalidDuration(value): "invalid duration \(String(reflecting: value)) for --for; use 30m, 2h or 1h30m"
        case let .durationOutOfRange(value): "duration \(String(reflecting: value)) for --for is out of range; use 1m to 24h"
        case let .invalidTime(value): "invalid time \(String(reflecting: value)) for --until; use H:MM, e.g. 4:00"
        }
        return CLIOutput(
            exitCode: .usage,
            standardError: diagnostic("error", reason, color: color) + "Run 'capsaicin --help' for usage.\n",
        )
    }

    static func failure(_ error: Error, color: Bool = false) -> CLIOutput {
        let reason: String = switch error {
        case IPCTransportError.timedOut: "Capsaicin didn't respond in time; the request may already have taken effect"
        case IPCTransportError.peerRejected, IPCTransportError.unsafeEndpoint: "couldn't verify the connection to Capsaicin"
        case IPCTransportError.invalidFrame, IPCCoding.DecodingFailure.malformed: "received an invalid response from Capsaicin"
        case IPCCoding.DecodingFailure.unsupportedVersion: version
        case CLIRunnerError.launchFailed: "couldn't launch Capsaicin"
        case CLIApplicationError.invalidBundle: "run this command from inside Capsaicin.app"
        default: "couldn't communicate with Capsaicin; the request may already have taken effect"
        }
        return CLIOutput(exitCode: .unavailable, standardError: diagnostic("error", reason, color: color))
    }

    private static func details(_ status: BlockingStatus, now: Date, timeZone: TimeZone, color: Bool) -> String {
        guard let session = status.session else { return "" }
        let turnsOff: String
        if let limit = session.timeLimit {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = "H:mm"
            turnsOff = "\(formatter.string(from: limit.date)) (in \(duration(limit.date.timeIntervalSince(now))))"
        } else {
            turnsOff = "when you turn it off"
        }
        var lines = detail("Turns off", turnsOff, color: color)
        if let battery = status.batteryCondition {
            var value = "turns off below \(battery.threshold.percent)%"
            if battery.ignoresOnACPower {
                value += ", except on AC power"
            }
            lines += detail("Battery", value, color: color)
        }
        return lines
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return "under a minute" }
        let minutes = Int(seconds / 60)
        guard minutes >= 60 else { return "\(minutes)m" }
        let hours = "\(minutes / 60)h"
        return minutes % 60 == 0 ? hours : "\(hours) \(minutes % 60)m"
    }

    private static func rejection(_ reason: StartRejection, status: BlockingStatus) -> String {
        switch reason {
        case .batteryBelowThreshold:
            if let battery = status.batteryCondition {
                return "the battery is below \(battery.threshold.percent)%"
            }
            return "the battery is below the threshold set in Settings"
        case .helperNotInstalled: return "the helper isn't installed; install or repair it in Settings"
        case .recordNotSaved: return unsaved
        case let .mechanismsFailed(mechanisms):
            return Mechanism.allCases.filter { mechanisms.contains($0) }
                .map { misalignment($0, direction: .notApplied) }.joined(separator: "; ")
        }
    }

    private static func misalignment(_ mechanism: Mechanism, direction: MisalignmentDirection) -> String {
        switch (mechanism, direction) {
        case (.systemSleepDisabled, .leftApplied): "couldn't restore system sleep"
        case (.systemSleepDisabled, .notApplied): "couldn't prevent system sleep"
        case (.idleSleepAssertion, .leftApplied): "couldn't restore idle sleep"
        case (.idleSleepAssertion, .notApplied): "couldn't prevent idle sleep"
        case (.displaySleepAssertion, .leftApplied): "couldn't restore display sleep"
        case (.displaySleepAssertion, .notApplied): "couldn't prevent display sleep"
        case (.led, .leftApplied): "couldn't turn off the Caps Lock LED"
        case (.led, .notApplied): "couldn't light the Caps Lock LED"
        }
    }

    private static func headline(_ symbol: String, _ message: String, color: Bool) -> String {
        styled(symbol, symbol == "✓" || symbol == "●" ? "32" : "2", color: color)
            + " " + styled(message, "1", color: color) + "\n"
    }

    private static func detail(_ label: String, _ value: String, color: Bool) -> String {
        "  " + styled(label.padding(toLength: 9, withPad: " ", startingAt: 0), "2", color: color) + "  " + value + "\n"
    }

    private static func diagnostic(_ prefix: String, _ message: String, color: Bool) -> String {
        styled(prefix + ":", prefix == "error" ? "1;31" : "1;33", color: color) + " " + message + "\n"
    }

    private static func styled(_ text: String, _ code: String, color: Bool) -> String {
        color ? "\u{1B}[\(code)m\(text)\u{1B}[0m" : text
    }
}
