import Foundation

public enum IPCTransportError: Error, Hashable, Sendable {
    /// 接続前の ENOENT / ECONNREFUSED だけ。起動を要求してよい。
    case unavailable(Int32)
    case system(Int32)
    case unsafeEndpoint
    case peerRejected
    case invalidFrame
    case timedOut
    case stopped
    case alreadyRunning
}

/// JSON の意味は IPCCoding に任せ、ここでは長さと単一フレームだけを検査する。
struct IPCFrame {
    static let maximumPayload = 16 * 1024
    private var bytes = Data()
    private var length: Int?

    var nextReadSize: Int {
        guard let length else { return 4 - bytes.count }
        return max(1, 4 + length - bytes.count)
    }

    mutating func append(_ data: Data) throws {
        bytes.append(data)
        if length == nil, bytes.count >= 4 {
            let value = bytes.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard value > 0, value <= Self.maximumPayload else { throw IPCTransportError.invalidFrame }
            length = Int(value)
        }
        if let length, bytes.count > length + 4 {
            throw IPCTransportError.invalidFrame
        }
    }

    func finish() throws -> Data {
        guard let length, bytes.count == length + 4 else { throw IPCTransportError.invalidFrame }
        return Data(bytes.dropFirst(4))
    }

    static func encode(_ payload: Data) throws -> Data {
        guard !payload.isEmpty, payload.count <= maximumPayload else { throw IPCTransportError.invalidFrame }
        let size = UInt32(payload.count)
        return Data([UInt8(size >> 24), UInt8((size >> 16) & 255), UInt8((size >> 8) & 255), UInt8(size & 255)]) +
            payload
    }
}
