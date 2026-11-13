import Testing

struct CLIHelpTests {
    @Test("SPEC-CLI-008 ヘルプ全文は英語で色を含まず、改行で終わる")
    func helpText() {
        let output = CLIOutput.help
        #expect(output.exitCode == .success)
        #expect(output.standardError.isEmpty)
        #expect(output.standardOutput == """
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
    }
}
