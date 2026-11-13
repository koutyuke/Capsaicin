import CapsaicinCore

/// CLI の引数の誤り。どれも使い方の誤り（終了コード 64）になる。
public enum CLIArgumentError: Error, Hashable, Sendable {
    case missingSubcommand
    case unknownSubcommand(String)
    case unexpectedArgument(String)
    case missingValue(option: String)
    case duplicateOption(String)
    /// 異なる時間指定のオプションを同時に指定した。
    case conflictingOptions
    case invalidDuration(String)
    /// 書式は正しいが、タイマーの範囲に収まらない。
    case durationOutOfRange(String)
    case invalidTime(String)
}

/// `capsaicin` の引数を要求にする。
public enum CLIArguments {
    /// - Parameter arguments: プログラム名を除いた引数。
    public static func parse(_ arguments: [String]) throws(CLIArgumentError) -> IPCCommand {
        guard let subcommand = arguments.first else { throw .missingSubcommand }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "on":
            return try .start(parseTimeOverride(rest))
        case "off", "status":
            if let extra = rest.first {
                throw .unexpectedArgument(extra)
            }
            return subcommand == "off" ? .stop : .status
        default:
            throw .unknownSubcommand(subcommand)
        }
    }

    private static func parseTimeOverride(_ arguments: [String]) throws(CLIArgumentError) -> StartTimeOverride? {
        var result: StartTimeOverride?
        var remaining = arguments[...]
        while let option = remaining.popFirst() {
            guard ["--for", "--until", "--no-time-limit"].contains(option) else { throw .unexpectedArgument(option) }
            switch (option, result) {
            case ("--for", .timer?), ("--until", .specifiedTime?), ("--no-time-limit", .noTimeLimit?):
                throw .duplicateOption(option)
            case (_, _?):
                throw .conflictingOptions
            case ("--no-time-limit", nil):
                result = .noTimeLimit
            default:
                guard let value = remaining.popFirst() else { throw .missingValue(option: option) }
                result = try option == "--for" ? .timer(parseDuration(value)) : .specifiedTime(parseTime(value))
            }
        }
        return result
    }

    /// `<時間>h`、`<分>m`、`<時間>h<分>m` のどれか。
    static func parseDuration(_ text: String) throws(CLIArgumentError) -> TimerDuration {
        guard let match = text.wholeMatch(of: /(?:([0-9]+)h)?(?:([0-9]+)m)?/),
              match.output.1 != nil || match.output.2 != nil
        else { throw .invalidDuration(text) }
        // 桁が多すぎて Int に収まらない値も、範囲外として扱う。
        guard let hours = Int(match.output.1 ?? "0"), let minutes = Int(match.output.2 ?? "0"),
              hours <= TimerDuration.allowedMinutes.upperBound, minutes <= TimerDuration.allowedMinutes.upperBound,
              let duration = TimerDuration(minutes: hours * 60 + minutes)
        else { throw .durationOutOfRange(text) }
        return duration
    }

    /// `H:MM` か `HH:MM`。
    static func parseTime(_ text: String) throws(CLIArgumentError) -> TimeOfDay {
        guard let match = text.wholeMatch(of: /([0-9]{1,2}):([0-9]{2})/),
              let hour = Int(match.output.1), let minute = Int(match.output.2),
              let time = TimeOfDay(hour: hour, minute: minute)
        else { throw .invalidTime(text) }
        return time
    }
}
