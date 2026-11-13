import CapsaicinCore
@testable import CapsaicinIPC
import Darwin
import Dispatch
import Foundation
import Testing

let transportStopped = BlockingStatus(session: nil, batteryCondition: nil, misalignments: [:], isRecordUnsaved: false)

final class IPCTransportFixture {
    let root: URL
    let endpoint: IPCEndpoint

    init() throws {
        // .build の絶対パスは Darwin の sun_path に収まらないので、承認済みの短い一時領域を使う。
        let size = confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
        guard size > 0 else { throw IPCTransportError.unsafeEndpoint }
        var buffer = [CChar](repeating: 0, count: size)
        guard confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, size) > 0 else { throw IPCTransportError.unsafeEndpoint }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        guard let path = String(bytes: bytes, encoding: .utf8) else { throw IPCTransportError.unsafeEndpoint }
        let temporary = URL(filePath: path).appending(path: "opencode")
        try FileManager.default.createDirectory(
            at: temporary,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700],
        )
        root = temporary.appending(path: "i" + UUID().uuidString.prefix(8))
        guard mkdir(root.path, 0o700) == 0 else { throw IPCTransportError.system(errno) }
        endpoint = IPCEndpoint(testDirectory: root.appending(path: "d").path)
        _ = try endpoint.address()
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func client(
        timing: IPCTiming = IPCTiming(),
        peerUID: @escaping @Sendable (Int32) throws -> uid_t = IPCSocket.peerUID,
    ) -> IPCClient {
        IPCClient(endpoint: endpoint, timing: timing, peerUID: peerUID)
    }

    func makeRawConnection() throws -> Int32 {
        let descriptor = try makeTestSocket()
        do {
            try IPCSocket.timeout(descriptor, until: .now() + 1)
            try IPCSocket.connect(descriptor, endpoint: endpoint)
            return descriptor
        } catch { close(descriptor); throw error }
    }

    func staleSocket(listening: Bool = false) throws -> Int32 {
        try FileManager.default.createDirectory(
            atPath: endpoint.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700],
        )
        let descriptor = try makeTestSocket()
        do {
            var address = try endpoint.address()
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard result == 0, chmod(endpoint.socketPath, 0o600) == 0 else { throw IPCTransportError.system(errno) }
            if listening {
                #expect(listen(descriptor, 8) == 0)
            }
            return descriptor
        } catch { close(descriptor); throw error }
    }
}

private func makeTestSocket() throws -> Int32 {
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else { throw IPCTransportError.system(errno) }
    do { try IPCSocket.configure(descriptor); return descriptor }
    catch { close(descriptor); throw error }
}

/// 受け付けた接続を、本番と同じ設定にして返す。
/// 相手の Task がスレッドプールで進めるよう、ブロックする accept は専用のスレッドで待つ。
/// スレッドプールの小さい環境（CI のランナー）では、テスト本体がプールを塞ぐと相手の Task が始まらない。
func acceptRaw(_ listener: Int32) async throws -> Int32 {
    try await ipcBackground {
        let accepted = accept(listener, nil, nil)
        guard accepted >= 0 else { throw IPCTransportError.system(errno) }
        do { try IPCSocket.configure(accepted); return accepted }
        catch { close(accepted); throw error }
    }
}

func sendRaw(_ descriptor: Int32, _ data: Data, eof: Bool = true) throws {
    var offset = 0
    while offset < data.count {
        let sent = data
            .withUnsafeBytes { send(descriptor, $0.baseAddress!.advanced(by: offset), data.count - offset, 0) }
        if sent < 0 {
            if errno == EINTR {
                continue
            }
            if errno == EAGAIN {
                try waitRaw(descriptor, events: Int16(POLLOUT)); continue
            }
            throw IPCTransportError.system(errno)
        }
        guard sent > 0 else { throw IPCTransportError.invalidFrame }
        offset += sent
    }
    if eof {
        #expect(shutdown(descriptor, SHUT_WR) == 0)
    }
}

func waitRaw(_ descriptor: Int32, events: Int16) throws {
    var readiness = pollfd(fd: descriptor, events: events, revents: 0)
    let result = poll(&readiness, 1, 1000)
    guard result > 0 else { throw IPCTransportError.timedOut }
}

func receiveRaw(_ descriptor: Int32) throws -> Data {
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while true {
        let count = recv(descriptor, &buffer, buffer.count, 0)
        if count == 0 {
            return data
        }
        if count < 0 {
            if errno == EINTR {
                continue
            }
            if errno == EAGAIN {
                try waitRaw(descriptor, events: Int16(POLLIN)); continue
            }
            // 読み残した不正な本文があれば Darwin が reset で切ることもある。
            if errno == ECONNRESET {
                return data
            }
            throw IPCTransportError.system(errno)
        }
        data.append(contentsOf: buffer.prefix(count))
    }
}

func verifiedTestPeer(_ descriptor: Int32) throws -> uid_t {
    #expect(fcntl(descriptor, F_GETFL) & O_NONBLOCK == 0)
    #expect(fcntl(descriptor, F_GETFD) & FD_CLOEXEC != 0)
    var enabled: Int32 = 0
    var size = socklen_t(MemoryLayout<Int32>.size)
    #expect(getsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, &size) == 0)
    #expect(enabled == 1)
    return try IPCSocket.peerUID(descriptor)
}

@MainActor
final class IPCHandlerSpy {
    var calls = 0
    func handle(_: IPCRequest) -> IPCResponse {
        calls += 1
        MainActor.preconditionIsolated()
        return IPCResponse(outcome: .status, status: transportStopped)
    }
}

final class IPCHandlerScheduleSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var calls: Int {
        lock.withLock { count }
    }

    func enqueue(_ body: @escaping @MainActor @Sendable () -> Void) {
        lock.withLock { count += 1 }
        DispatchQueue.main.async(execute: body)
    }
}
