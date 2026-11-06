@testable import CapsaicinIPC
import Darwin
import Dispatch
import Foundation
import Testing

struct IPCSocketTests {
    @Test("SPEC-CLI-007 双方の書き込みを閉じた後も応答の残りと EOF を読む")
    func bufferedResponseAfterHalfClose() throws {
        let pair = try socketPair()
        defer { close(pair.0); close(pair.1) }
        let payload = Data("message".utf8)
        try IPCSocket.write(pair.0, payload, until: .now() + 1)
        #expect(try IPCSocket.read(pair.1, until: .now() + 1) == payload)
        try IPCSocket.write(pair.1, payload, until: .now() + 1)
        #expect(try IPCSocket.read(pair.0, until: .now() + 1) == payload)
    }

    @Test("SPEC-CLI-007 小さな送信バッファでも64 KiBを送り、書き込み後に EOF を送る")
    func partialWrites() async throws {
        let pair = try socketPair()
        defer { close(pair.0); close(pair.1) }
        let payload = Data(repeating: 42, count: IPCSocket.maximumPayload)
        async let received = Task.detached { try IPCSocket.read(pair.1, until: .now() + 1) }.value
        try await Task.detached { try IPCSocket.write(pair.0, payload, until: .now() + 1) }.value
        #expect(try await received == payload)
    }

    @Test("SPEC-CLI-007 読まない相手への部分書き込みにも期限がある")
    func writeDeadline() async throws {
        let pair = try socketPair()
        defer { close(pair.0); close(pair.1) }
        let started = ContinuousClock.now
        await #expect(throws: IPCTransportError.timedOut) {
            try await Task.detached {
                try IPCSocket.write(pair.0, Data(repeating: 42, count: IPCSocket.maximumPayload), until: .now() + 0.08)
            }.value
        }
        #expect(started.duration(to: .now) < .seconds(1))
    }

    @Test("SPEC-CLI-007 受信の進捗があっても全体の期限を延長しない")
    func readDeadline() async throws {
        let pair = try socketPair()
        defer { close(pair.0); close(pair.1) }
        let reading = Task.detached { try IPCSocket.read(pair.0, until: .now() + 0.12) }
        for _ in 0 ..< 3 {
            try sendRaw(pair.1, Data([42]), eof: false)
            try await Task.sleep(for: .milliseconds(50))
        }
        await #expect(throws: IPCTransportError.timedOut) { try await reading.value }
    }

    private func socketPair() throws -> (Int32, Int32) {
        var descriptors: [Int32] = [-1, -1]
        guard socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else { throw IPCTransportError.system(errno) }
        do {
            for descriptor in descriptors {
                try IPCSocket.configure(descriptor)
            }
            var capacity: Int32 = 1024
            guard setsockopt(descriptors[0], SOL_SOCKET, SO_SNDBUF, &capacity, socklen_t(MemoryLayout<Int32>.size)) == 0
            else { throw IPCTransportError.system(errno) }
            return (descriptors[0], descriptors[1])
        } catch { close(descriptors[0]); close(descriptors[1]); throw error }
    }
}
