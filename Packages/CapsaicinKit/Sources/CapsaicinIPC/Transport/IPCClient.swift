import Darwin
import Dispatch
import Foundation

public struct IPCClient: Sendable {
    let endpoint: IPCEndpoint
    let timing: IPCTiming
    let peerUID: @Sendable (Int32) throws -> uid_t

    public init(endpoint: IPCEndpoint) {
        self.init(endpoint: endpoint, timing: IPCTiming(), peerUID: IPCSocket.peerUID)
    }

    init(endpoint: IPCEndpoint, timing: IPCTiming, peerUID: @escaping @Sendable (Int32) throws -> uid_t) {
        self.endpoint = endpoint
        self.timing = timing
        self.peerUID = peerUID
    }

    public func connect(timeout: TimeInterval = 0.25) async throws -> IPCConnection {
        guard timeout.isFinite, timeout > 0 else { throw IPCTransportError.timedOut }
        return try await ipcBackground {
            let socket = try IPCSocket()
            try IPCSocket.timeout(socket.descriptor, until: .now() + min(timeout, timing.connect))
            try IPCSocket.connect(socket.descriptor, endpoint: endpoint)
            guard try peerUID(socket.descriptor) == geteuid() else { throw IPCTransportError.peerRejected }
            return IPCConnection(socket: socket, timeout: timing.clientRequest)
        }
    }
}

/// ソケットの所有権は1回目の要求に移す。送信途中の失敗も再送しない。
public actor IPCConnection {
    private var socket: IPCSocket?
    private let timeout: Double

    init(socket: IPCSocket, timeout: Double) {
        self.socket = socket
        self.timeout = timeout
    }

    public func close() {
        socket = nil
    }

    public func request(_ request: IPCRequest) async throws -> IPCResponse {
        try Task.checkCancellation()
        guard let socket else { throw IPCTransportError.stopped }
        self.socket = nil
        let timeout = timeout
        return try await ipcBackground {
            defer { withExtendedLifetime(socket) {} }
            let descriptor = socket.descriptor
            let deadline = DispatchTime.now() + timeout
            try IPCSocket.write(descriptor, IPCCoding.encode(request), until: deadline)
            let response = try IPCCoding.decodeResponse(IPCSocket.read(descriptor, until: deadline))
            switch (request.command, response.outcome) {
            case (.start, .started), (.start, .alreadyBlocking), (.start, .startRejected),
                 (.stop, .released), (.stop, .alreadyStopped), (.status, .status),
                 (_, .cliRequestsDisabled), (_, .unsupportedVersion): return response
            default: throw IPCCoding.DecodingFailure.malformed
            }
        }
    }
}
