import Foundation

extension CLIText {
    static var keys: CLIText {
        CLIText { key, arguments in ([key.rawValue] + arguments).joined(separator: " ") }
    }
}
