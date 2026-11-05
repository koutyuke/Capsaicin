import CapsaicinCore
import Darwin
import Foundation

/// 起動時に一度だけ読み、判定と所有の更新で同じ値を使えるよう保持する。
@MainActor
public final class BootTimeProvider: BootTimeProviding {
    public let bootTime: Date

    public convenience init() {
        self.init(read: { sysctlbyname("kern.boottime", $0, $1, nil, 0) })
    }

    init(read: (UnsafeMutablePointer<timeval>, UnsafeMutablePointer<Int>) -> Int32) {
        var value = timeval()
        var size = MemoryLayout<timeval>.size
        let status = read(&value, &size)
        bootTime = Self.date(status: status, size: size, value: value)
    }

    static func date(status: Int32, size: Int, value: timeval) -> Date {
        guard status == 0, size == MemoryLayout<timeval>.size,
              value.tv_sec > 0, value.tv_usec >= 0, value.tv_usec < 1_000_000
        else { return .distantPast }
        return Date(timeIntervalSince1970: Double(value.tv_sec) + Double(value.tv_usec) / 1_000_000)
    }
}
