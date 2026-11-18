import CapsaicinCore
@testable import CapsaicinPlatform
import Dispatch
import Foundation
import Testing

@MainActor
struct HelperXPCClientTests {
    @Test("SPEC-HLP-005 応答がなければ期限で失敗し、接続を取り消し、遅い応答を無視する")
    func timeout() throws {
        let connection = FakeConnection()
        let client = HelperXPCClient(connect: { _ in connection })
        let started = ContinuousClock.now
        #expect(throws: HelperXPCError.timedOut) { try client.request("on", timeout: 0.01) }
        #expect(ContinuousClock.now - started < .seconds(2))
        #expect(connection.commands == ["on"])
        #expect(connection.cancelled)
        connection.reply?(.success(()))
        connection.reply?(.failure(.requestFailed))
    }

    @Test("SPEC-HLP-002 応答の成功と失敗を伝え、どちらも接続を取り消す", arguments: [true, false])
    func reply(success: Bool) throws {
        let connection = FakeConnection(response: success ? .success(()) : .failure(.requestFailed))
        let client = HelperXPCClient(connect: { _ in connection })
        if success {
            try client.request("off")
        } else {
            #expect(throws: HelperXPCError.requestFailed) { try client.request("off") }
        }
        #expect(connection.cancelled)
        #expect(connection.commands == ["off"])
    }

    @Test("SPEC-HLP-002 on の接続を保持し、同じ接続で off を送ってから閉じる")
    func retainsConnectionUntilOff() throws {
        let connection = FakeConnection(response: .success(()))
        var connectionCount = 0
        let client = HelperXPCClient(connect: { _ in
            connectionCount += 1
            return connection
        })
        try client.request("on")
        #expect(!connection.cancelled)
        try client.request("off")
        #expect(connectionCount == 1)
        #expect(connection.commands == ["on", "off"])
        #expect(connection.cancelled)
    }

    @Test("SPEC-HLP-002 off が失敗しても応答後に保持中の接続を閉じる")
    func failedOffClosesRetainedConnection() throws {
        let connection = FakeConnection(response: .success(()))
        let client = HelperXPCClient(connect: { _ in connection })
        try client.request("on")
        connection.response = .failure(.requestFailed)
        #expect(throws: HelperXPCError.requestFailed) { try client.request("off") }
        #expect(connection.commands == ["on", "off"])
        #expect(connection.cancelled)
    }

    @Test("SPEC-HLP-005 中断・無効の通知は保持中の接続からだけ受け付け、通知前に接続を閉じる",
          arguments: [HelperConnectionLoss.interrupted, .invalid])
    func onlyCurrentConnectionReportsLoss(loss: HelperConnectionLoss) async throws {
        var connections: [FakeConnection] = []
        var events: [HelperConnectionLoss] = []
        let client = HelperXPCClient(connect: { onLoss in
            let connection = FakeConnection(response: .success(()), onLoss: onLoss)
            connections.append(connection)
            return connection
        })
        client.onConnectionLost = { reason in
            #expect(connections[0].cancelled)
            events.append(reason)
        }
        try client.request("on")
        connections[0].onLoss(loss)
        await deliveredEvents()
        #expect(events == [loss])

        try client.request("on")
        try #require(connections.count == 2)
        connections[0].onLoss(.invalid)
        await deliveredEvents()
        #expect(!connections[1].cancelled)
        client.closeConnection()
        connections[1].onLoss(.invalid)
        await deliveredEvents()
        #expect(events == [loss])
        #expect(connections[1].cancelled)
        #expect(connections[1].commands == ["on"])
    }

    private func deliveredEvents() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    @Test("SPEC-HLP-002 接続と署名条件の設定に失敗したら要求を送らない")
    func connectionFailure() {
        let client = HelperXPCClient(connect: { _ in throw HelperXPCError.identityRequirement(1) })
        #expect(throws: HelperXPCError.identityRequirement(1)) { try client.request("on") }
    }
}

final class FakeConnection: HelperXPCConnecting {
    var commands: [String] = []
    var cancelled = false
    var reply: (@Sendable (Result<Void, HelperXPCError>) -> Void)?
    var response: Result<Void, HelperXPCError>?
    let onLoss: HelperXPCClient.LossHandler

    init(response: Result<Void, HelperXPCError>? = nil, onLoss: @escaping HelperXPCClient.LossHandler = { _ in }) {
        self.response = response
        self.onLoss = onLoss
    }

    func send(_ command: String, reply: @escaping @Sendable (Result<Void, HelperXPCError>) -> Void) {
        commands.append(command)
        self.reply = reply
        if let response {
            reply(response)
        }
    }

    func cancel() {
        cancelled = true
    }
}
