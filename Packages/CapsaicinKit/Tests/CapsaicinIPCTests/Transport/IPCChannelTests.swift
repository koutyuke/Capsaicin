@testable import CapsaicinIPC
import Darwin
import Dispatch
import Foundation
import Testing

struct IPCChannelTests {
    @Test("SPEC-CLI-007 小さな送信バッファでも部分書き込みを完了し、書き込み後に EOF を送る")
    func partialWrites() async throws {
        let pair = try socketPair()
        defer { close(pair.1) }
        let queue = DispatchQueue(label: "IPCChannelTests.partial")
        let channel = queue.sync {
            IPCChannel(descriptor: pair.0, queue: queue, deadline: IPCDeadline(after: 1))
        }
        let payload = Data(repeating: 42, count: IPCFrame.maximumPayload)
        let wire = try IPCFrame.encode(payload)
        async let received = Task.detached { try receiveRaw(pair.1) }.value
        let error: Error? = await withCheckedContinuation { continuation in
            queue.async {
                channel.closed = { continuation.resume(returning: $0) }
                channel.write(wire) { channel.finish() }
            }
        }
        #expect(error == nil)
        #expect(try await received == wire)
    }

    @Test("SPEC-CLI-007 相手が読まない部分書き込みにも延長しない期限があり、二重 cancel は安全である")
    func writeDeadline() async throws {
        let pair = try socketPair()
        defer { close(pair.1) }
        let queue = DispatchQueue(label: "IPCChannelTests.deadline")
        let channel = queue.sync {
            IPCChannel(descriptor: pair.0, queue: queue, deadline: IPCDeadline(after: 0.08))
        }
        let wire = try IPCFrame.encode(Data(repeating: 42, count: IPCFrame.maximumPayload))
        let error: Error? = await withCheckedContinuation { continuation in
            queue.async {
                channel.closed = { continuation.resume(returning: $0) }
                channel.write(wire) { Issue.record("読まない相手への書き込みを完了したと扱わない"); channel.finish() }
            }
        }
        #expect(error as? IPCTransportError == .timedOut)
        queue.sync { channel.finish(); channel.finish() }
    }

    private func socketPair() throws -> (Int32, Int32) {
        var descriptors: [Int32] = [-1, -1]
        guard socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else { throw IPCTransportError.system(errno) }
        do {
            for descriptor in descriptors {
                try IPCSocket.configure(descriptor)
            }
            var capacity: Int32 = 1024
            guard setsockopt(descriptors[0], SOL_SOCKET, SO_SNDBUF, &capacity, socklen_t(MemoryLayout<Int32>.size)) ==
                0
            else {
                throw IPCTransportError.system(errno)
            }
            return (descriptors[0], descriptors[1])
        } catch {
            for descriptor in descriptors {
                close(descriptor)
            }
            throw error
        }
    }
}
