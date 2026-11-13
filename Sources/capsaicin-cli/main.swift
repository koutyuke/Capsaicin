import Darwin
import Foundation

let runner = CLIRunner(
    resolve: CLIApplication.current,
    connector: CLISystemConnector(),
    launcher: CLISystemLauncher(),
    clock: CLISystemClock(),
    stdoutColor: CLIOutput.usesColor(
        isTerminal: isatty(STDOUT_FILENO) != 0,
        environment: ProcessInfo.processInfo.environment,
    ),
    stderrColor: CLIOutput.usesColor(
        isTerminal: isatty(STDERR_FILENO) != 0,
        environment: ProcessInfo.processInfo.environment,
    ),
)
let output = await runner.run(Array(CommandLine.arguments.dropFirst()))
FileHandle.standardOutput.write(Data(output.standardOutput.utf8))
FileHandle.standardError.write(Data(output.standardError.utf8))
exit(output.exitCode.rawValue)
