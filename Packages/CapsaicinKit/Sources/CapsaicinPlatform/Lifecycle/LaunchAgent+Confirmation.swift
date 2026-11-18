import Darwin
import Foundation

extension LaunchAgent {
    static func processExecutablePath(_ pid: pid_t) -> String? {
        // PROC_PIDPATHINFO_MAXSIZE の式マクロは Swift に取り込まれない。
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(bytes: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, encoding: .utf8)
    }

    static func jobPID(_ output: String) -> pid_t? {
        for line in output.split(separator: "\n") {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("pid = ") else { continue }
            guard let pid = pid_t(line.dropFirst(6)), pid > 0 else { return nil }
            return pid
        }
        return nil
    }
}
