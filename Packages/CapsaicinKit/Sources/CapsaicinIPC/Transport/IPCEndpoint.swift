import Darwin
import Foundation

public struct IPCEndpoint: Sendable {
    public enum Namespace: Sendable {
        case release
        case debug
    }

    let directory: String
    let socketName: String
    let lockName: String
    let production: Bool
    public var socketPath: String {
        directory + "/" + socketName
    }

    public init(namespace: Namespace) {
        directory = "/private/tmp/io.github.koutyuke.capsaicin-\(geteuid())"
        socketName = namespace == .debug ? "ipc.debug.sock" : "ipc.sock"
        lockName = namespace == .debug ? "ipc.debug.lock" : "ipc.lock"
        production = true
    }

    /// テストだけが、所有する短い一時ディレクトリへ差し替える。
    init(testDirectory: String) {
        directory = testDirectory
        socketName = "ipc.sock"
        lockName = "ipc.lock"
        production = false
    }

    func address() throws -> sockaddr_un {
        var address = sockaddr_un()
        let bytes = Array(socketPath.utf8)
        guard !bytes.contains(0), bytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
            throw IPCTransportError.unsafeEndpoint
        }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: bytes)
        }
        return address
    }
}

struct IPCFileIdentity: Equatable {
    let device: dev_t
    let inode: ino_t

    init(_ info: stat) {
        device = info.st_dev
        inode = info.st_ino
    }
}

/// ディレクトリ FD を固定する。同一 uid の悪意あるプロセス全体を隔離する仕組みではない。
final class IPCDirectory {
    let descriptor: Int32
    let endpoint: IPCEndpoint
    private let identity: IPCFileIdentity

    init(_ endpoint: IPCEndpoint, create: Bool) throws {
        _ = try endpoint.address()
        self.endpoint = endpoint
        let url = URL(filePath: endpoint.directory)
        let parent = open(url.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw Self.fileError(errno, connecting: !create) }
        defer { close(parent) }
        var parentInfo = stat()
        guard fstat(parent, &parentInfo) == 0 else { throw IPCTransportError.system(errno) }
        if endpoint.production {
            guard parentInfo.st_uid == 0, parentInfo.st_mode & S_ISVTX != 0,
                  parentInfo.st_mode & S_IFMT == S_IFDIR
            else { throw IPCTransportError.unsafeEndpoint }
        } else {
            guard parentInfo.st_uid == geteuid(), parentInfo.st_mode & 0o077 == 0 else {
                throw IPCTransportError.unsafeEndpoint
            }
        }
        let name = url.lastPathComponent
        if create, mkdirat(parent, name, 0o700) != 0, errno != EEXIST {
            throw IPCTransportError.system(errno)
        }
        let opened = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard opened >= 0 else { throw Self.fileError(errno, connecting: !create) }
        var info = stat()
        var named = stat()
        guard fstat(opened, &info) == 0,
              fstatat(parent, name, &named, AT_SYMLINK_NOFOLLOW) == 0,
              info.st_uid == geteuid(), info.st_mode & S_IFMT == S_IFDIR,
              info.st_mode & 0o7777 == 0o700, IPCFileIdentity(info) == IPCFileIdentity(named)
        else {
            close(opened)
            throw IPCTransportError.unsafeEndpoint
        }
        descriptor = opened
        identity = IPCFileIdentity(info)
    }

    deinit { close(descriptor) }

    static func fileError(_ code: Int32, connecting: Bool) -> IPCTransportError {
        if connecting, code == ENOENT {
            return .unavailable(code)
        }
        return .system(code)
    }

    func validatePath() throws {
        var info = stat()
        guard lstat(endpoint.directory, &info) == 0, IPCFileIdentity(info) == identity,
              info.st_mode & S_IFMT == S_IFDIR, info.st_uid == geteuid(), info.st_mode & 0o7777 == 0o700
        else { throw IPCTransportError.unsafeEndpoint }
    }

    func socketIdentity() throws -> IPCFileIdentity? {
        var info = stat()
        if fstatat(descriptor, endpoint.socketName, &info, AT_SYMLINK_NOFOLLOW) != 0 {
            if errno == ENOENT {
                return nil
            }
            throw IPCTransportError.system(errno)
        }
        guard info.st_mode & S_IFMT == S_IFSOCK, info.st_uid == geteuid(),
              info.st_mode & 0o7777 == 0o600
        else { throw IPCTransportError.unsafeEndpoint }
        return IPCFileIdentity(info)
    }

    func removeSocket(ifMatching expected: IPCFileIdentity) throws {
        try validatePath()
        guard try socketIdentity() == expected else { throw IPCTransportError.unsafeEndpoint }
        guard unlinkat(descriptor, endpoint.socketName, 0) == 0 else { throw IPCTransportError.system(errno) }
    }

    func acquireLock() throws -> Int32 {
        var lock = openat(descriptor, endpoint.lockName, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        if lock < 0, errno == EEXIST {
            lock = openat(descriptor, endpoint.lockName, O_RDWR | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        }
        guard lock >= 0 else { throw IPCTransportError.system(errno) }
        do {
            var info = stat()
            var named = stat()
            guard fstat(lock, &info) == 0,
                  info.st_mode & S_IFMT == S_IFREG, info.st_uid == geteuid(),
                  info.st_mode & 0o7777 == 0o600, info.st_nlink == 1,
                  fstatat(descriptor, endpoint.lockName, &named, AT_SYMLINK_NOFOLLOW) == 0,
                  IPCFileIdentity(info) == IPCFileIdentity(named)
            else { throw IPCTransportError.unsafeEndpoint }
            guard flock(lock, LOCK_EX | LOCK_NB) == 0 else {
                if errno == EWOULDBLOCK {
                    throw IPCTransportError.alreadyRunning
                }
                throw IPCTransportError.system(errno)
            }
            try validatePath()
            guard fstatat(descriptor, endpoint.lockName, &named, AT_SYMLINK_NOFOLLOW) == 0,
                  IPCFileIdentity(info) == IPCFileIdentity(named)
            else { throw IPCTransportError.unsafeEndpoint }
            return lock
        } catch {
            close(lock)
            throw error
        }
    }
}
