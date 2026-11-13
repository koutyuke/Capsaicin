@testable import CapsaicinIPC
import Darwin
import Foundation
import Testing

struct IPCTransportTests {
    @Test("SPEC-CLI-003 同じ uid の往復は MainActor で1回だけ処理し、接続を再利用しない")
    func roundTrip() async throws {
        let fixture = try IPCTransportFixture()
        let spy = IPCHandlerSpy()
        let server = IPCServer(
            endpoint: fixture.endpoint,
            timing: IPCTiming(),
            peerUID: verifiedTestPeer,
            handler: spy.handle,
        )
        try await server.start()
        do {
            let connection = try await fixture.client(peerUID: verifiedTestPeer).connect()
            let response = try await connection.request(IPCRequest(command: .status))
            #expect(response.outcome == .status)
            #expect(response.status == transportStopped)
            await #expect(throws: IPCTransportError.stopped) { try await connection.request(IPCRequest(command: .stop))
            }
            await connection.close()
            await connection.close()
            #expect(await spy.calls == 1)
        } catch { await server.stop(); throw error }
        await server.stop()
    }

    @Test("SPEC-CLI-007 uid の不一致と照合失敗はクライアントとサーバーの両方向で拒否する", arguments: [false, true])
    func authentication(failing: Bool) async throws {
        let fixture = try IPCTransportFixture()
        let spy = IPCHandlerSpy()
        let badPeer: @Sendable (Int32) throws -> uid_t = { _ in
            if failing {
                throw IPCTransportError.peerRejected
            }
            return geteuid() + 1
        }
        let server = IPCServer(endpoint: fixture.endpoint, handler: spy.handle)
        try await server.start()
        await #expect(throws: IPCTransportError.peerRejected) { try await fixture.client(peerUID: badPeer).connect() }
        await server.stop()
        let rejecting = IPCServer(
            endpoint: fixture.endpoint,
            timing: IPCTiming(),
            peerUID: badPeer,
            handler: spy.handle,
        )
        try await rejecting.start()
        let descriptor = try fixture.makeRawConnection()
        _ = try receiveRaw(descriptor)
        close(descriptor)
        await rejecting.stop()
        #expect(await spy.calls == 0)
    }

    @Test("SPEC-CLI-007 分割した JSON も EOF 後だけ処理し、64 KiB 超・欠落・余剰・壊れた JSON は処理しない")
    func wireBoundaries() async throws {
        let fixture = try IPCTransportFixture()
        let spy = IPCHandlerSpy()
        let server = IPCServer(endpoint: fixture.endpoint, handler: spy.handle)
        try await server.start()
        do {
            let valid = try IPCCoding.encode(IPCRequest(command: .status))
            let descriptor = try fixture.makeRawConnection()
            for byte in valid {
                try sendRaw(descriptor, Data([byte]), eof: false)
            }
            #expect(await spy.calls == 0)
            try sendRaw(descriptor, Data())
            let wire = try await ipcBackground { try receiveRaw(descriptor) }
            close(descriptor)
            #expect(try IPCCoding.decodeResponse(wire).outcome == .status)
            for input in [
                Data(repeating: 32, count: IPCSocket.maximumPayload + 1),
                Data(),
                Data(valid.dropLast()), valid + Data([0]), valid + valid,
                Data("bad".utf8),
            ] {
                let raw = try fixture.makeRawConnection()
                try sendRaw(raw, input, eof: input.count <= IPCSocket.maximumPayload)
                #expect(try receiveRaw(raw).isEmpty)
                close(raw)
            }
            let boundary = try fixture.makeRawConnection()
            try sendRaw(boundary, valid + Data(repeating: 32, count: IPCSocket.maximumPayload - valid.count))
            let response = try await ipcBackground { try receiveRaw(boundary) }
            close(boundary)
            #expect(try IPCCoding.decodeResponse(response).outcome == .status)
            #expect(await spy.calls == 2)
        } catch { await server.stop(); throw error }
        await server.stop()
    }

    @Test(
        "SPEC-CLI-007 未対応バージョンと現行版の未知コマンドは handler を予約も実行もせず切断する",
        arguments: [
            #"{"version":77,"anything":true}"#,
            "{\"version\":\(IPCProtocol.version),\"command\":{\"unknown\":{}}}",
        ],
    )
    func unsupportedVersion(payload: String) async throws {
        let fixture = try IPCTransportFixture()
        let spy = IPCHandlerSpy()
        let scheduler = IPCHandlerScheduleSpy()
        let server = IPCServer(
            endpoint: fixture.endpoint, timing: IPCTiming(requestRead: 0.1),
            scheduleHandler: scheduler.enqueue, handler: spy.handle,
        )
        try await server.start()
        do {
            let descriptor = try fixture.makeRawConnection()
            defer { close(descriptor) }
            let started = ContinuousClock.now
            try sendRaw(descriptor, Data(payload.utf8))
            let wire = try await ipcBackground { try receiveRaw(descriptor) }
            #expect(started.duration(to: .now) < .seconds(1))
            #expect(wire.isEmpty)
            #expect(scheduler.calls == 0)
            #expect(await spy.calls == 0)
        } catch { await server.stop(); throw error }
        await server.stop()
    }

    @Test("SPEC-CLI-007 受信の進捗で期限を延長せず、止まった接続が別の要求を塞がない")
    func deadlineAndConcurrentClient() async throws {
        let fixture = try IPCTransportFixture()
        let spy = IPCHandlerSpy()
        let server = IPCServer(endpoint: fixture.endpoint, timing: IPCTiming(requestRead: 0.12), handler: spy.handle)
        try await server.start()
        do {
            let stalled = try fixture.makeRawConnection()
            try sendRaw(stalled, Data([0]), eof: false)
            let connection = try await fixture.client().connect()
            #expect(try await connection.request(IPCRequest(command: .status)).outcome == .status)
            await connection.close()
            try await Task.sleep(for: .milliseconds(65))
            // 期限どおりにサーバーが先に閉じていれば EPIPE になる。どちらでも期限は延びていない。
            _ = try? sendRaw(stalled, Data([0]), eof: false)
            try await Task.sleep(for: .milliseconds(80))
            #expect(try receiveRaw(stalled).isEmpty)
            close(stalled)
            #expect(await spy.calls == 1)
        } catch { await server.stop(); throw error }
        await server.stop()
    }

    @Test("SPEC-CLI-007 クライアントの応答期限は相手の無応答でも切れ、再送しない")
    func clientDeadline() async throws {
        let fixture = try IPCTransportFixture()
        let listener = try fixture.staleSocket(listening: true)
        defer { close(listener) }
        let client = fixture.client(timing: IPCTiming(clientRequest: 0.08))
        let connection = try await client.connect()
        await #expect(throws: IPCTransportError.timedOut) { try await connection.request(IPCRequest(command: .stop)) }
        await connection.close()
    }

    @Test("SPEC-CLI-004 活動中のソケットを残し、停止完了後は再起動できる")
    func stopAndRestart() async throws {
        let fixture = try IPCTransportFixture()
        let spy = IPCHandlerSpy()
        let server = IPCServer(endpoint: fixture.endpoint, timing: IPCTiming(requestRead: 0.08), handler: spy.handle)
        try await server.start()
        let second = IPCServer(endpoint: fixture.endpoint, handler: spy.handle)
        await #expect(throws: IPCTransportError.alreadyRunning) { try await second.start() }
        let stalled = try fixture.makeRawConnection()
        async let firstStop: Void = server.stop()
        async let secondStop: Void = server.stop()
        _ = await (firstStop, secondStop)
        close(stalled)
        #expect(!FileManager.default.fileExists(atPath: fixture.endpoint.socketPath))
        #expect(!FileManager.default.fileExists(atPath: fixture.endpoint.directory + "/ipc.lock"))
        try await second.start()
        let connection = try await fixture.client().connect()
        #expect(try await connection.request(IPCRequest(command: .status)).outcome == .status)
        await connection.close()
        await second.stop()
        try await server.start()
        await server.stop()
    }
}
