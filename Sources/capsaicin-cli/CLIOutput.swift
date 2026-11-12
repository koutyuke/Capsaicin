import CapsaicinCore
import CapsaicinIPC
import Foundation

enum CLITextKey: String, CaseIterable {
    case started = "outcome.started"
    case timeLimitReplaced = "outcome.timeLimitReplaced"
    case alreadyBlocking = "outcome.alreadyBlocking"
    case released = "outcome.released"
    case alreadyStopped = "outcome.alreadyStopped"
    case rejected = "outcome.rejected"
    case disabled = "outcome.disabled"
    case version = "error.version"
    case connection = "error.connection"
    case timeout = "error.timeout"
    case launch = "error.launch"
    case protocolFailure = "error.protocol"
    case authentication = "error.authentication"
    case usage = "error.usage"
    case missingCommand = "argument.missingCommand"
    case unknownCommand = "argument.unknownCommand"
    case unexpectedArgument = "argument.unexpected"
    case missingValue = "argument.missingValue"
    case duplicateOption = "argument.duplicate"
    case conflictingOptions = "argument.conflicting"
    case invalidDuration = "argument.invalidDuration"
    case durationOutOfRange = "argument.durationOutOfRange"
    case invalidTime = "argument.invalidTime"
    case blocking = "status.blocking"
    case stopped = "status.stopped"
    case timer = "condition.timer"
    case specifiedTime = "condition.specifiedTime"
    case battery = "condition.battery"
    case ignoresAC = "condition.ignoresAC"
    case noConditions = "condition.none"
    case misalignment = "warning.misalignment"
    case unsaved = "warning.unsaved"
    case leftApplied = "direction.leftApplied"
    case notApplied = "direction.notApplied"
    case systemSleepDisabled = "mechanism.systemSleepDisabled"
    case idleSleepAssertion = "mechanism.idleSleepAssertion"
    case displaySleepAssertion = "mechanism.displaySleepAssertion"
    case led = "mechanism.led"
    case batteryBelowThreshold = "rejection.battery"
    case helperNotInstalled = "rejection.helper"
    case mechanismsFailed = "rejection.mechanisms"
    case recordNotSaved = "rejection.record"
    case separator = "format.separator"
    case listSeparator = "format.listSeparator"
}

struct CLIText {
    var lookup: (CLITextKey, [String]) -> String

    init(bundle: Bundle) {
        lookup = { key, arguments in
            let format = bundle.localizedString(forKey: key.rawValue, value: nil, table: "CLI")
            return String(format: format, locale: Locale(identifier: "ja_JP"), arguments: arguments)
        }
    }

    init(lookup: @escaping (CLITextKey, [String]) -> String) {
        self.lookup = lookup
    }

    func callAsFunction(_ key: CLITextKey, _ arguments: String...) -> String {
        lookup(key, arguments)
    }
}

struct CLIOutput {
    var exitCode: ExitCode
    var standardOutput = ""
    var standardError = ""

    static func response(_ response: IPCResponse, text: CLIText) -> CLIOutput {
        let status = statusLine(response.status, text: text)
        let message: String
        switch response.outcome {
        case .started: message = text(.started)
        case .timeLimitReplaced: message = text(.timeLimitReplaced)
        case .alreadyBlocking: message = text(.alreadyBlocking)
        case .released: message = text(.released)
        case .alreadyStopped: message = text(.alreadyStopped)
        case let .startRejected(reason): message = text(.rejected, rejection(reason, text: text))
        case .cliRequestsDisabled: message = text(.disabled)
        case .unsupportedVersion: message = text(.version)
        case .status: return CLIOutput(exitCode: response.exitCode, standardOutput: status + "\n")
        }
        let line = [message, status].joined(separator: text(.separator)) + "\n"
        if response.exitCode == .unavailable {
            return CLIOutput(exitCode: response.exitCode, standardError: line)
        }
        return CLIOutput(exitCode: response.exitCode, standardOutput: line)
    }

    static func usage(_ error: CLIArgumentError, text: CLIText) -> CLIOutput {
        let reason: String = switch error {
        case .missingSubcommand: text(.missingCommand)
        case let .unknownSubcommand(value): text(.unknownCommand, String(reflecting: value))
        case let .unexpectedArgument(value): text(.unexpectedArgument, String(reflecting: value))
        case let .missingValue(option): text(.missingValue, option)
        case let .duplicateOption(option): text(.duplicateOption, option)
        case .conflictingOptions: text(.conflictingOptions)
        case let .invalidDuration(value): text(.invalidDuration, String(reflecting: value))
        case let .durationOutOfRange(value): text(.durationOutOfRange, String(reflecting: value))
        case let .invalidTime(value): text(.invalidTime, String(reflecting: value))
        }
        return CLIOutput(exitCode: .usage, standardError: text(.usage, reason) + "\n")
    }

    static func failure(_ error: Error, text: CLIText) -> CLIOutput {
        let key: CLITextKey = switch error {
        case IPCTransportError.timedOut: .timeout
        case IPCTransportError.peerRejected, IPCTransportError.unsafeEndpoint: .authentication
        case IPCTransportError.invalidFrame, IPCCoding.DecodingFailure.malformed: .protocolFailure
        case IPCCoding.DecodingFailure.unsupportedVersion: .version
        case CLIRunnerError.launchFailed: .launch
        default: .connection
        }
        return CLIOutput(exitCode: .unavailable, standardError: text(key) + "\n")
    }

    private static func statusLine(_ status: BlockingStatus, text: CLIText) -> String {
        var parts = [text(status.isBlocking ? .blocking : .stopped)]
        if let session = status.session {
            var conditions: [String] = []
            if let limit = session.timeLimit {
                // 応答の壁時計の時刻を UTC の明示付きで表す。設定から時刻を再計算しない。
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                conditions.append(text(
                    limit.source == .timer ? .timer : .specifiedTime,
                    formatter.string(from: limit.date),
                ))
            }
            if let battery = status.batteryCondition {
                let condition = text(.battery, String(battery.threshold.percent))
                conditions.append(battery.ignoresOnACPower ? condition + text(.ignoresAC) : condition)
            }
            parts.append(conditions.isEmpty ? text(.noConditions) : conditions.joined(separator: text(.listSeparator)))
        }
        for mechanism in Mechanism.allCases {
            if let direction = status.misalignments[mechanism] {
                parts.append(text(
                    .misalignment,
                    name(mechanism, text: text),
                    text(direction == .leftApplied ? .leftApplied : .notApplied),
                ))
            }
        }
        if status.isRecordUnsaved {
            parts.append(text(.unsaved))
        }
        return parts.joined(separator: text(.separator))
    }

    private static func name(_ mechanism: Mechanism, text: CLIText) -> String {
        let key: CLITextKey = switch mechanism {
        case .systemSleepDisabled: .systemSleepDisabled
        case .idleSleepAssertion: .idleSleepAssertion
        case .displaySleepAssertion: .displaySleepAssertion
        case .led: .led
        }
        return text(key)
    }

    private static func rejection(_ reason: StartRejection, text: CLIText) -> String {
        switch reason {
        case .batteryBelowThreshold: return text(.batteryBelowThreshold)
        case .helperNotInstalled: return text(.helperNotInstalled)
        case .recordNotSaved: return text(.recordNotSaved)
        case let .mechanismsFailed(mechanisms):
            let names = Mechanism.allCases.filter { mechanisms.contains($0) }.map { name($0, text: text) }
            return text(.mechanismsFailed, names.joined(separator: text(.listSeparator)))
        }
    }
}
