@testable import CapsaicinPlatform
import Foundation
import Synchronization
import Testing

struct HelperXPCClientTests {
    @Test("SPEC-HLP-005 応答がなければ期限で失敗し、接続を取り消し、遅い応答を無視する")
    func timeout() throws {
        let connection = FakeConnection()
        let client = HelperXPCClient(connect: { connection })
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
        let client = HelperXPCClient(connect: { connection })
        if success {
            try client.request("off")
        } else {
            #expect(throws: HelperXPCError.requestFailed) { try client.request("off") }
        }
        #expect(connection.cancelled)
        #expect(connection.commands == ["off"])
    }

    @Test("SPEC-HLP-002 接続と署名条件の設定に失敗したら要求を送らない")
    func connectionFailure() {
        let client = HelperXPCClient(connect: { throw HelperXPCError.identityRequirement(1) })
        #expect(throws: HelperXPCError.identityRequirement(1)) { try client.request("on") }
    }
}

private final class FakeConnection: HelperXPCConnecting {
    var commands: [String] = []
    var cancelled = false
    var reply: (@Sendable (Result<Void, HelperXPCError>) -> Void)?
    let response: Result<Void, HelperXPCError>?

    init(response: Result<Void, HelperXPCError>? = nil) {
        self.response = response
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
