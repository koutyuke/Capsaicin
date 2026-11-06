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

    /// 接続と uid 照合だけを行う。ここでは要求を送らない。
    public func connect(timeout: TimeInterval = 0.25) async throws -> IPCConnection {
        guard timeout.isFinite, timeout > 0 else { throw IPCTransportError.timedOut }
        var timing = timing
        timing.connect = min(timeout, timing.connect)
        let client = IPCClient(endpoint: endpoint, timing: timing, peerUID: peerUID)
        let attempt = IPCConnectAttempt(client: client)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                attempt.queue.async { attempt.start(continuation) }
            }
        } onCancel: {
            attempt.queue.async { attempt.cancel() }
        }
    }
}

private final class IPCConnectAttempt: @unchecked Sendable {
    let queue = DispatchQueue(label: "CapsaicinIPC.client")
    let client: IPCClient
    var channel: IPCChannel?
    var continuation: CheckedContinuation<IPCConnection, Error>?
    var cancelled = false

    init(client: IPCClient) {
        self.client = client
    }

    func start(_ continuation: CheckedContinuation<IPCConnection, Error>) {
        guard !cancelled else { continuation.resume(throwing: CancellationError()); return }
        self.continuation = continuation
        do {
            let directory = try IPCDirectory(client.endpoint, create: false)
            try directory.validatePath()
            guard try directory.socketIdentity() != nil else { throw IPCTransportError.unavailable(ENOENT) }
            let descriptor = try IPCSocket.make()
            let channel = IPCChannel(
                descriptor: descriptor,
                queue: queue,
                deadline: IPCDeadline(after: client.timing.connect),
            )
            self.channel = channel
            channel.closed = { error in self.complete(.failure(error ?? IPCTransportError.stopped)) }
            channel.connected = {
                guard try self.client.peerUID(descriptor) == geteuid() else { throw IPCTransportError.peerRejected }
                try directory.validatePath()
                channel.setDeadline(IPCDeadline(after: self.client.timing.clientRequest))
                self.complete(.success(IPCConnection(channel: channel, timing: self.client.timing)))
            }
            do {
                if try IPCSocket.connect(descriptor, endpoint: client.endpoint) {
                    try channel.didConnect()
                } else {
                    channel.beginConnect()
                }
            } catch { channel.finish(error) }
        } catch { complete(.failure(error)) }
    }

    func complete(_ result: Result<IPCConnection, Error>) {
        let saved = continuation
        continuation = nil
        // 成功後は IPCConnection が所有する。Attempt への循環参照を残さない。
        channel?.connected = nil
        channel = nil
        saved?.resume(with: result)
    }

    func cancel() {
        cancelled = true
        if let channel {
            channel.finish(CancellationError())
        }
    }
}

/// 接続1つにつき要求は1回だけ。送信途中の失敗も再送可能とは扱わない。
public final class IPCConnection: Sendable {
    private let state: IPCRequestState

    init(channel: IPCChannel, timing: IPCTiming) {
        state = IPCRequestState(channel: channel, timing: timing)
    }

    deinit {
        let state = state
        state.channel.queue.async { state.channel.finish(IPCTransportError.stopped) }
    }

    public func request(_ request: IPCRequest) async throws -> IPCResponse {
        let state = state
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                state.channel.queue.async { state.start(request, continuation: continuation) }
            }
        } onCancel: {
            state.channel.queue.async { state.cancel() }
        }
    }

    public func close() async {
        let state = state
        await withCheckedContinuation { continuation in
            state.channel.queue.async { state.close(continuation) }
        }
    }
}

private final class IPCRequestState: @unchecked Sendable {
    let channel: IPCChannel
    let timing: IPCTiming
    var used = false
    var cancelled = false
    var didClose = false
    var continuation: CheckedContinuation<IPCResponse, Error>?
    var closeWaiters: [CheckedContinuation<Void, Never>] = []
    var result: Result<IPCResponse, Error>?

    init(channel: IPCChannel, timing: IPCTiming) {
        self.channel = channel
        self.timing = timing
        channel.closed = { [self] error in
            didClose = true
            continuation?.resume(with: result ?? .failure(error ?? IPCTransportError.stopped))
            continuation = nil
            for waiter in closeWaiters {
                waiter.resume()
            }
            closeWaiters.removeAll()
        }
    }

    func start(_ request: IPCRequest, continuation: CheckedContinuation<IPCResponse, Error>) {
        guard !used, !didClose, !cancelled, channel.phase != .closing else {
            continuation.resume(throwing: IPCTransportError.stopped)
            return
        }
        used = true
        self.continuation = continuation
        do {
            let wire = try IPCFrame.encode(IPCCoding.encode(request))
            channel.setDeadline(IPCDeadline(after: timing.clientRequest))
            channel.received = { [self] data in
                let response = try IPCCoding.decodeResponse(data)
                switch (request.command, response.outcome) {
                case (.start, .started), (.start, .alreadyBlocking), (.start, .startRejected),
                     (.stop, .released), (.stop, .alreadyStopped), (.status, .status),
                     (_, .cliRequestsDisabled), (_, .unsupportedVersion):
                    break
                default:
                    throw IPCCoding.DecodingFailure.malformed
                }
                result = .success(response)
                channel.finish()
            }
            channel.write(wire) { self.channel.beginRead() }
        } catch { channel.finish(error) }
    }

    func cancel() {
        cancelled = true
        channel.finish(CancellationError())
    }

    func close(_ waiter: CheckedContinuation<Void, Never>) {
        if didClose {
            waiter.resume(); return
        }
        closeWaiters.append(waiter)
        channel.finish(IPCTransportError.stopped)
    }
}
