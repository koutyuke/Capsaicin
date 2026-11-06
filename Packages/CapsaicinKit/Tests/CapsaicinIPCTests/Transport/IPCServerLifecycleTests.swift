@testable import CapsaicinIPC
import Darwin
import Foundation
import Testing

/// main queue に到達する前の要求だけを止める。syscall や frame の実装は差し替えない。
private final class HeldIPCHandler: @unchecked Sendable {
    private let lock = NSLock()
    private var body: (@MainActor @Sendable () -> Void)?
    private var arrival: CheckedContinuation<Void, Never>?

    func enqueue(_ body: @escaping @MainActor @Sendable () -> Void) {
        lock.lock()
        self.body = body
        let arrival = arrival
        self.arrival = nil
        lock.unlock()
        arrival?.resume()
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if body != nil {
                lock.unlock(); continuation.resume()
            } else {
                arrival = continuation; lock.unlock()
            }
        }
    }

    @MainActor
    func run() {
        let callback = lock.withLock { let value = body; body = nil; return value }
        callback?()
    }
}

struct IPCServerLifecycleTests {
    @Test("SPEC-CLI-007 停止・世代変更・期限切れの後に古い要求を実行しない", arguments: [false, true])
    func queuedHandler(expire: Bool) async throws {
        let fixture = try IPCTransportFixture()
        let held = HeldIPCHandler()
        let spy = IPCHandlerSpy()
        let server = IPCServer(
            endpoint: fixture.endpoint, timing: IPCTiming(requestRead: 0.08),
            scheduleHandler: held.enqueue, handler: spy.handle,
        )
        try await server.start()
        let descriptor = try fixture.makeRawConnection()
        defer { close(descriptor) }
        try sendRaw(descriptor, IPCFrame.encode(IPCCoding.encode(IPCRequest(command: .stop))))
        await held.wait()
        if expire {
            #expect(try receiveRaw(descriptor).isEmpty)
        } else {
            await server.stop()
            // FD が再利用され得る次の世代を開始してから、古い main queue の仕事を取り出す。
            try await server.start()
        }
        await held.run()
        #expect(await spy.calls == 0)
        await server.stop()
    }

    @Test("SPEC-CLI-007 同時接続は8つに制限し、停止で全接続の FD を閉じる")
    func connectionLimit() async throws {
        let fixture = try IPCTransportFixture()
        let server = IPCServer(endpoint: fixture.endpoint) { _ in
            IPCResponse(outcome: .status, status: transportStopped)
        }
        try await server.start()
        var clients: [IPCConnection] = []
        for _ in 0 ..< 8 {
            try await clients.append(fixture.client().connect())
        }
        let ninth = try fixture.makeRawConnection()
        #expect(try receiveRaw(ninth).isEmpty)
        close(ninth)
        await server.stop()
        for connection in clients {
            await connection.close()
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.endpoint.socketPath))
    }
}
