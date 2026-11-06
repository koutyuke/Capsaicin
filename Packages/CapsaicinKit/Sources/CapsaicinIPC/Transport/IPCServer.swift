import Darwin
import Dispatch
import Foundation
import Synchronization

typealias IPCHandlerScheduler = @Sendable (@escaping @MainActor @Sendable () -> Void) -> Void

public actor IPCServer {
    public typealias Handler = @MainActor @Sendable (IPCRequest) -> IPCResponse
    private let endpoint: IPCEndpoint
    private let timing: IPCTiming
    private let peerUID: @Sendable (Int32) throws -> uid_t
    private let scheduleHandler: IPCHandlerScheduler
    private let handler: Handler
    private var listener: IPCListener?

    public init(endpoint: IPCEndpoint, handler: @escaping Handler) {
        self.init(endpoint: endpoint, timing: IPCTiming(), handler: handler)
    }

    init(
        endpoint: IPCEndpoint, timing: IPCTiming,
        peerUID: @escaping @Sendable (Int32) throws -> uid_t = IPCSocket.peerUID,
        scheduleHandler: @escaping IPCHandlerScheduler = { DispatchQueue.main.async(execute: $0) },
        handler: @escaping Handler,
    ) {
        self.endpoint = endpoint
        self.timing = timing
        self.peerUID = peerUID
        self.scheduleHandler = scheduleHandler
        self.handler = handler
    }

    deinit { listener?.running.withLock { $0 = false } }

    public func start() async throws {
        guard listener == nil else { throw IPCTransportError.alreadyRunning }
        let run = try IPCListener(endpoint: endpoint)
        listener = run
        let (endpoint, timing, peerUID, scheduleHandler, handler) = (
            endpoint,
            timing,
            peerUID,
            scheduleHandler,
            handler,
        )
        run.group.enter()
        Thread.detachNewThread {
            defer { unlink(endpoint.socketPath); run.group.leave() }
            while run.running.withLock({ $0 }) {
                // accept の待機だけを短く区切り、停止時も FD はこのスレッドで閉じる。
                var ready = pollfd(fd: run.descriptor, events: Int16(POLLIN), revents: 0)
                guard poll(&ready, 1, 100) > 0 else { continue }
                let accepted = accept(run.descriptor, nil, nil)
                guard accepted >= 0 else { continue }
                run.group.enter()
                Thread.detachNewThread {
                    defer { run.group.leave() }
                    do {
                        let socket = try IPCSocket(descriptor: accepted)
                        defer { withExtendedLifetime(socket) {} }
                        guard try peerUID(accepted) == geteuid() else { return }
                        let deadline = DispatchTime.now() + timing.requestRead
                        let request = try IPCCoding.decodeRequest(IPCSocket.read(accepted, until: deadline))
                        let response = Mutex<IPCResponse?>(nil)
                        let finished = DispatchSemaphore(value: 0)
                        scheduleHandler {
                            guard run.running.withLock({ $0 }), DispatchTime.now() < deadline else { return }
                            response.withLock { $0 = handler(request) }
                            finished.signal()
                        }
                        guard finished.wait(timeout: deadline) == .success,
                              let value = response.withLock({ $0 }) else { return }
                        try IPCSocket.write(accepted, IPCCoding.encode(value), until: .now() + timing.responseWrite)
                    } catch { /* 不正な要求や期限切れには応答せず閉じる。 */ }
                }
            }
        }
    }

    public func stop() async {
        guard let run = listener else { return }
        run.running.withLock { $0 = false }
        await withCheckedContinuation { continuation in
            run.group.notify(queue: .global()) { continuation.resume() }
        }
        if listener === run {
            listener = nil
        }
    }
}

private final class IPCListener: Sendable {
    let socket: IPCSocket
    var descriptor: Int32 {
        socket.descriptor
    }

    let group = DispatchGroup()
    let running = Mutex(true)

    init(endpoint: IPCEndpoint) throws {
        try endpoint.prepare()
        socket = try IPCSocket()
        var address = try endpoint.address()
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else { throw IPCTransportError.system(errno) }
        guard chmod(endpoint.socketPath, 0o600) == 0, listen(descriptor, 8) == 0 else {
            let code = errno
            unlink(endpoint.socketPath)
            throw IPCTransportError.system(code)
        }
    }
}
