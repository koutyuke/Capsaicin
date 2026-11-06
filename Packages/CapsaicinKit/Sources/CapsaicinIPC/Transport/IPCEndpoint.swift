import Darwin
import Foundation

public struct IPCEndpoint: Sendable {
    public enum Namespace: Sendable { case release, debug }
    let directory: String
    let socketName: String
    public var socketPath: String {
        directory + "/" + socketName
    }

    public init(namespace: Namespace) {
        directory = "/private/tmp/io.github.koutyuke.capsaicin-\(geteuid())"
        socketName = namespace == .debug ? "ipc.debug.sock" : "ipc.sock"
    }

    init(testDirectory: String) {
        directory = testDirectory
        socketName = "ipc.sock"
    }

    func address() throws -> sockaddr_un {
        var address = sockaddr_un()
        let bytes = Array(socketPath.utf8)
        guard !bytes.contains(0), bytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
            throw IPCTransportError.unsafeEndpoint
        }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return address
    }

    func prepare() throws {
        _ = try address()
        try FileManager.default.createDirectory(
            atPath: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700],
        )
        var info = stat()
        guard lstat(directory, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == geteuid(), info.st_mode & 0o7777 == 0o700
        else { throw IPCTransportError.unsafeEndpoint }
        if lstat(socketPath, &info) != 0 {
            guard errno == ENOENT else { throw IPCTransportError.system(errno) }
            return
        }
        guard info.st_mode & S_IFMT == S_IFSOCK, info.st_uid == geteuid() else {
            throw IPCTransportError.unsafeEndpoint
        }
        let probe = try IPCSocket()
        try IPCSocket.timeout(probe.descriptor, until: .now() + 0.25)
        do {
            try IPCSocket.connect(probe.descriptor, endpoint: self)
            throw IPCTransportError.alreadyRunning
        } catch IPCTransportError.unavailable(ECONNREFUSED) {
            guard unlink(socketPath) == 0 else { throw IPCTransportError.system(errno) }
        }
    }
}
