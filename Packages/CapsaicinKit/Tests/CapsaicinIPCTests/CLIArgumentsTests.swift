import CapsaicinCore
@testable import CapsaicinIPC
import Testing

struct CLIArgumentsTests {
    private func parse(_ line: String) -> Result<IPCCommand, CLIArgumentError> {
        let arguments = line.split(separator: " ").map(String.init)
        return Result { () throws(CLIArgumentError) in try CLIArguments.parse(arguments) }
    }

    @Test("SPEC-CLI-001 on、off、status を受け付ける")
    func subcommands() {
        #expect(parse("on") == .success(.start(nil)))
        #expect(parse("on --no-time-limit") == .success(.start(.noTimeLimit)))
        #expect(parse("off") == .success(.stop))
        #expect(parse("status") == .success(.status))
    }

    @Test(
        "SPEC-CLI-001 --for は h と m の組み合わせを受け付ける",
        arguments: [("30m", 30), ("2h", 120), ("1h30m", 90), ("24h", 1440), ("1m", 1), ("0h5m", 5)],
    )
    func validDurations(text: String, expected: Int) throws {
        #expect(try parse("on --for \(text)") == .success(.start(.timer(#require(TimerDuration(minutes: expected))))))
    }

    @Test(
        "SPEC-CLI-001 --for の書式の誤りを拒む",
        arguments: ["1.5h", "30m1h", "90", "1h1h", "", "h", "m", "1H", "-1h", "1h 30m", "１h"],
    )
    func invalidDurationFormats(text: String) {
        #expect(throws: CLIArgumentError.invalidDuration(text)) { try CLIArguments.parseDuration(text) }
    }

    @Test(
        "SPEC-CLI-001 --for の長さがタイマーの範囲に収まらなければ拒む",
        arguments: ["0m", "0h", "25h", "24h1m", "1441m", "99999999999999999999h"],
    )
    func durationsOutOfRange(text: String) {
        #expect(throws: CLIArgumentError.durationOutOfRange(text)) { try CLIArguments.parseDuration(text) }
    }

    @Test(
        "SPEC-CLI-001 --until は H:MM と HH:MM を受け付ける",
        arguments: [("4:00", 4, 0), ("04:05", 4, 5), ("23:59", 23, 59), ("0:00", 0, 0)],
    )
    func validTimes(text: String, hour: Int, minute: Int) throws {
        #expect(try parse("on --until \(text)") == .success(.start(.specifiedTime(#require(TimeOfDay(
            hour: hour,
            minute: minute,
        ))))))
    }

    @Test(
        "SPEC-CLI-001 --until の書式の誤りと範囲外を拒む",
        arguments: ["4:5", "24:00", "12:60", "123:00", "4:000", "4", "4.00", ":30"],
    )
    func invalidTimes(text: String) {
        #expect(throws: CLIArgumentError.invalidTime(text)) { try CLIArguments.parseTime(text) }
    }

    @Test("SPEC-CLI-001 --for と --until の同時指定、同じオプションの重複、値の欠けを拒む")
    func optionCombinations() {
        #expect(parse("on --for 30m --until 4:00") == .failure(.conflictingOptions))
        #expect(parse("on --until 4:00 --for 30m") == .failure(.conflictingOptions))
        #expect(parse("on --for 1h --for 2h") == .failure(.duplicateOption("--for")))
        #expect(parse("on --until 1:00 --until 2:00") == .failure(.duplicateOption("--until")))
        #expect(parse("on --for") == .failure(.missingValue(option: "--for")))
    }

    @Test("SPEC-CLI-001 --no-time-limit は値を取らず、ほかの時間指定と排他で重複を拒む")
    func noTimeLimitOptions() {
        #expect(parse("on --for 30m --no-time-limit") == .failure(.conflictingOptions))
        #expect(parse("on --no-time-limit --for 30m") == .failure(.conflictingOptions))
        #expect(parse("on --no-time-limit --until 4:00") == .failure(.conflictingOptions))
        #expect(parse("on --until 4:00 --no-time-limit") == .failure(.conflictingOptions))
        #expect(parse("on --no-time-limit --no-time-limit") == .failure(.duplicateOption("--no-time-limit")))
        #expect(parse("on --no-time-limit 1h") == .failure(.unexpectedArgument("1h")))
    }

    @Test("SPEC-CLI-007 不明なサブコマンドと余分な引数は使い方の誤り")
    func usageErrors() {
        #expect(parse("") == .failure(.missingSubcommand))
        #expect(parse("start") == .failure(.unknownSubcommand("start")))
        #expect(parse("off now") == .failure(.unexpectedArgument("now")))
        #expect(parse("status --for 1h") == .failure(.unexpectedArgument("--for")))
        #expect(parse("on 1h") == .failure(.unexpectedArgument("1h")))
    }
}
