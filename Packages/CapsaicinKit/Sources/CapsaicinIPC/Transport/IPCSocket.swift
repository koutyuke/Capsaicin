import Darwin
import Dispatch
import Foundation

enum IPCSocket {
    static func make() throws -> Int32 {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw IPCTransportError.system(errno) }
        do {
            try configure(descriptor)
            return descriptor
        } catch {
            close(descriptor)
            throw error
        }
    }

    static func configure(_ descriptor: Int32) throws {
        var enabled: Int32 = 1
        guard fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0, fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0,
              setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size)) == 0
        else { throw IPCTransportError.system(errno) }
    }

    static func peerUID(_ descriptor: Int32) throws -> uid_t {
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard getpeereid(descriptor, &uid, &gid) == 0 else { throw IPCTransportError.peerRejected }
        return uid
    }

    static func connect(_ descriptor: Int32, endpoint: IPCEndpoint) throws -> Bool {
        var address = try endpoint.address()
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if result == 0 {
            return true
        }
        let code = errno
        if code == EINPROGRESS || code == EAGAIN {
            return false
        }
        if code == ENOENT || code == ECONNREFUSED {
            throw IPCTransportError.unavailable(code)
        }
        throw IPCTransportError.system(code)
    }

    static func bind(_ descriptor: Int32, endpoint: IPCEndpoint) throws {
        var address = try endpoint.address()
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { throw IPCTransportError.system(errno) }
    }
}

struct IPCDeadline: Sendable {
    let instant: DispatchTime
    init(instant: DispatchTime) {
        self.instant = instant
    }

    init(after seconds: Double, now: DispatchTime = .now()) {
        instant = now + seconds
    }

    var expired: Bool {
        DispatchTime.now() >= instant
    }
}

/// 値だけを差し替え、実際の I/O と単調時計のアルゴリズムはテストでも共用する。
struct IPCTiming: Sendable {
    var connect: Double = 0.25
    var requestRead: Double = 2
    var clientRequest: Double = 10
    var responseWrite: Double = 2
}
