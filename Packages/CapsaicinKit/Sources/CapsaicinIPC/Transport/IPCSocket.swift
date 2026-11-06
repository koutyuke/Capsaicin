import Darwin
import Dispatch
import Foundation

public enum IPCTransportError: Error, Hashable, Sendable {
    /// 接続前の ENOENT / ECONNREFUSED だけ。起動を要求してよい。
    case unavailable(Int32)
    case system(Int32)
    case unsafeEndpoint, peerRejected, invalidFrame, timedOut, stopped, alreadyRunning
}

struct IPCTiming: Sendable {
    var connect: Double = 0.25
    var requestRead: Double = 2
    var clientRequest: Double = 10
    var responseWrite: Double = 2
}

final class IPCSocket: Sendable {
    static let maximumPayload = 64 * 1024
    let descriptor: Int32

    init(descriptor: Int32 = socket(AF_UNIX, SOCK_STREAM, 0)) throws {
        guard descriptor >= 0 else { throw IPCTransportError.system(errno) }
        do { try Self.configure(descriptor) }
        catch { close(descriptor); throw error }
        self.descriptor = descriptor
    }

    deinit { close(descriptor) }

    static func configure(_ descriptor: Int32) throws {
        var enabled: Int32 = 1
        guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0,
              setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size)) == 0
        else { throw IPCTransportError.system(errno) }
    }

    static func peerUID(_ descriptor: Int32) throws -> uid_t {
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard getpeereid(descriptor, &uid, &gid) == 0 else { throw IPCTransportError.peerRejected }
        return uid
    }

    static func connect(_ descriptor: Int32, endpoint: IPCEndpoint) throws {
        var address = try endpoint.address()
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if result != 0 {
            if errno == ENOENT || errno == ECONNREFUSED {
                throw IPCTransportError.unavailable(errno)
            }
            throw failure()
        }
    }

    /// 毎回残り時間を設定する。少量ずつ送られても、期限は延長しない。
    static func timeout(_ descriptor: Int32, until deadline: DispatchTime) throws {
        let now = DispatchTime.now().uptimeNanoseconds
        guard deadline.uptimeNanoseconds > now else { throw IPCTransportError.timedOut }
        let remaining = max(1, (deadline.uptimeNanoseconds - now) / 1000)
        var value = timeval(tv_sec: Int(remaining / 1_000_000), tv_usec: Int32(remaining % 1_000_000))
        for option in [SO_RCVTIMEO, SO_SNDTIMEO] {
            // Darwin は双方の half-close 後の変更を EINVAL にする。残ったデータと EOF は読める。
            guard setsockopt(descriptor, SOL_SOCKET, option, &value, socklen_t(MemoryLayout<timeval>.size)) == 0 ||
                errno == EINVAL
            else { throw IPCTransportError.system(errno) }
        }
    }

    static func read(_ descriptor: Int32, until deadline: DispatchTime) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            try timeout(descriptor, until: deadline)
            let count = recv(descriptor, &buffer, min(buffer.count, maximumPayload + 1 - data.count), 0)
            if count == 0 {
                return data
            }
            if count < 0 {
                if errno == EINTR {
                    continue
                }
                throw failure()
            }
            data.append(contentsOf: buffer.prefix(count))
            guard data.count <= maximumPayload else { throw IPCTransportError.invalidFrame }
        }
    }

    static func write(_ descriptor: Int32, _ data: Data, until deadline: DispatchTime) throws {
        guard data.count <= maximumPayload else { throw IPCTransportError.invalidFrame }
        var offset = 0
        while offset < data.count {
            try timeout(descriptor, until: deadline)
            let count = data.withUnsafeBytes {
                send(descriptor, $0.baseAddress!.advanced(by: offset), data.count - offset, 0)
            }
            if count < 0, errno == EINTR {
                continue
            }
            guard count > 0 else { throw failure() }
            offset += count
        }
        guard shutdown(descriptor, SHUT_WR) == 0 else { throw failure() }
    }

    private static func failure() -> IPCTransportError {
        errno == EAGAIN || errno == ETIMEDOUT ? .timedOut : .system(errno)
    }
}

func ipcBackground<T: Sendable>(_ body: @escaping @Sendable () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        Thread.detachNewThread { continuation.resume(with: Result(catching: body)) }
    }
}
