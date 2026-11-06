import CapsaicinCore
@testable import CapsaicinIPC
import Darwin
import Foundation
import Testing

struct IPCClientWireTests {
    struct ResponseExpectation: Sendable {
        let command: IPCCommand
        let allowed: [IPCOutcome]
    }

    static let responseExpectations: [ResponseExpectation] = [
        ResponseExpectation(command: .start(nil), allowed: [
            .started, .alreadyBlocking, .startRejected(.helperNotInstalled), .cliRequestsDisabled, .unsupportedVersion,
        ]),
        ResponseExpectation(command: .stop, allowed: [
            .released, .alreadyStopped, .cliRequestsDisabled, .unsupportedVersion,
        ]),
        ResponseExpectation(command: .status, allowed: [.status, .cliRequestsDisabled, .unsupportedVersion]),
    ]
    static let responseOutcomes: [IPCOutcome] = [
        .started, .alreadyBlocking, .startRejected(.helperNotInstalled), .released, .alreadyStopped,
        .status, .cliRequestsDisabled, .unsupportedVersion,
    ]

    @Test(
        "SPEC-CLI-007 要求と応答の種類を照合し、不一致でも再送せず接続を閉じる",
        .serialized,
        arguments: responseExpectations, responseOutcomes,
    )
    func responseCorrelation(expectation: ResponseExpectation, outcome: IPCOutcome) async throws {
        let fixture = try IPCTransportFixture()
        let listener = try fixture.staleSocket(listening: true)
        defer { close(listener) }
        let connection = try await fixture.client().connect()
        let request = IPCRequest(command: expectation.command)
        let operation = Task { try await connection.request(request) }
        let accepted = accept(listener, nil, nil)
        #expect(accepted >= 0)
        defer { close(accepted) }
        try IPCSocket.configure(accepted)
        var frame = IPCFrame()
        try frame.append(receiveRaw(accepted))
        #expect(try IPCCoding.decodeRequest(frame.finish()) == request)
        var status = transportStopped
        status.session = BlockingSession(timeLimit: nil)
        let response = IPCResponse(outcome: outcome, status: status)
        try sendRaw(accepted, IPCFrame.encode(IPCCoding.encode(response)))
        if expectation.allowed.contains(outcome) {
            #expect(try await operation.value == response)
        } else {
            await #expect(throws: IPCCoding.DecodingFailure.malformed) { try await operation.value }
        }
        await #expect(throws: IPCTransportError.stopped) { try await connection.request(request) }
        #expect(try receiveRaw(accepted).isEmpty)
        var probe: UInt8 = 0
        let sent = send(accepted, &probe, 1, 0)
        let sendError = errno
        #expect(sent == -1)
        #expect(sendError == EPIPE || sendError == ECONNRESET)
        var pending = pollfd(fd: listener, events: Int16(POLLIN), revents: 0)
        #expect(poll(&pending, 1, 0) == 0)
        await connection.close()
    }

    @Test(
        "SPEC-CLI-007 クライアントも分割・余剰・欠落・巨大ヘッダー・バージョンを検査する",
        arguments: ["valid", "extra", "truncated", "oversized", "version", "json"],
    )
    func responseFrames(kind: String) async throws {
        let fixture = try IPCTransportFixture()
        let listener = try fixture.staleSocket(listening: true)
        defer { close(listener) }
        let connection = try await fixture.client().connect()
        let operation = Task { try await connection.request(IPCRequest(command: .status)) }
        let accepted = accept(listener, nil, nil)
        #expect(accepted >= 0)
        defer { close(accepted) }
        try IPCSocket.configure(accepted)
        _ = try receiveRaw(accepted)
        let wire = try responseWire(kind)
        for byte in wire {
            try sendRaw(accepted, Data([byte]), eof: false)
        }
        if kind != "oversized" {
            try sendRaw(accepted, Data())
        }
        switch kind {
        case "valid": #expect(try await operation.value.outcome == .status)
        case "version": await #expect(throws: IPCCoding.DecodingFailure.unsupportedVersion(77)) {
                try await operation.value
            }
        case "json": await #expect(throws: IPCCoding.DecodingFailure.malformed) { try await operation.value }
        default: await #expect(throws: IPCTransportError.invalidFrame) { try await operation.value }
        }
        await connection.close()
    }

    private func responseWire(_ kind: String) throws -> Data {
        let valid = try IPCFrame.encode(IPCCoding.encode(IPCResponse(outcome: .status, status: transportStopped)))
        return switch kind {
        case "extra": valid + Data([0])
        case "truncated": Data(valid.dropLast())
        case "oversized": Data([0, 0, 64, 1])
        case "version": try IPCFrame.encode(Data(#"{"version":77}"#.utf8))
        case "json": try IPCFrame.encode(Data("bad".utf8))
        default: valid
        }
    }

    @Test("SPEC-CLI-007 応答が正しい長さでも EOF がなければ期限まで受理しない")
    func responseNeedsEOF() async throws {
        let fixture = try IPCTransportFixture()
        let listener = try fixture.staleSocket(listening: true)
        defer { close(listener) }
        let connection = try await fixture.client(timing: IPCTiming(clientRequest: 0.1)).connect()
        let operation = Task { try await connection.request(IPCRequest(command: .status)) }
        let accepted = accept(listener, nil, nil)
        defer { close(accepted) }
        try IPCSocket.configure(accepted)
        _ = try receiveRaw(accepted)
        try sendRaw(
            accepted,
            IPCFrame.encode(IPCCoding.encode(IPCResponse(outcome: .status, status: transportStopped))),
            eof: false,
        )
        await #expect(throws: IPCTransportError.timedOut) { try await operation.value }
        await connection.close()
    }

    @Test("SPEC-CLI-007 キャンセルは IO queue に渡し、close を重複させず接続を再利用しない")
    func cancellation() async throws {
        let fixture = try IPCTransportFixture()
        let listener = try fixture.staleSocket(listening: true)
        defer { close(listener) }
        let connection = try await fixture.client().connect()
        let operation = Task { try await connection.request(IPCRequest(command: .stop)) }
        let accepted = accept(listener, nil, nil)
        defer { close(accepted) }
        try IPCSocket.configure(accepted)
        _ = try receiveRaw(accepted)
        operation.cancel()
        operation.cancel()
        await #expect(throws: CancellationError.self) { try await operation.value }
        await connection.close()
        let sentinel = open("/dev/null", O_RDONLY | O_CLOEXEC)
        defer { close(sentinel) }
        await connection.close()
        await #expect(throws: IPCTransportError.stopped) { try await connection.request(IPCRequest(command: .stop)) }
        #expect(fcntl(sentinel, F_GETFD) >= 0)
    }
}
