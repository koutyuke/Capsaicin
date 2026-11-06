import Darwin
import Foundation

let runner = CLIRunner(
    resolve: CLIApplication.current,
    connector: CLISystemConnector(),
    launcher: CLISystemLauncher(),
    clock: CLISystemClock(),
)
let output = await runner.run(Array(CommandLine.arguments.dropFirst()))
FileHandle.standardOutput.write(Data(output.standardOutput.utf8))
FileHandle.standardError.write(Data(output.standardError.utf8))
exit(output.exitCode.rawValue)
