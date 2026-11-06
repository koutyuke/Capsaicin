@testable import CapsaicinIPC
import Darwin
import Foundation
import Testing

/// main queue に到達する前の要求だけを止める。ソケットの実装は差し替えない。
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
        try sendRaw(descriptor, IPCCoding.encode(IPCRequest(command: .stop)))
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

    @Test("SPEC-CLI-007 停止は受信中の接続の期限と後片付けを待つ")
    func stopWaitsForConnections() async throws {
        let fixture = try IPCTransportFixture()
        let server = IPCServer(endpoint: fixture.endpoint, timing: IPCTiming(requestRead: 0.08)) { _ in
            IPCResponse(outcome: .status, status: transportStopped)
        }
        try await server.start()
        var clients: [IPCConnection] = []
        for _ in 0 ..< 3 {
            try await clients.append(fixture.client().connect())
        }
        let started = ContinuousClock.now
        await server.stop()
        #expect(started.duration(to: .now) < .seconds(1))
        for connection in clients {
            await connection.close()
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.endpoint.socketPath))
    }
}
