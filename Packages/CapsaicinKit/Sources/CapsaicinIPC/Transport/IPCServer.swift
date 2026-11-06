import Darwin
import Dispatch
import Foundation

typealias IPCHandlerScheduler = @Sendable (@escaping @MainActor @Sendable () -> Void) -> Void

/// アプリの組み立て側が所有し、終了時に stop() を待つ。
public final class IPCServer: Sendable {
    public typealias Handler = @MainActor @Sendable (IPCRequest) -> IPCResponse
    private let state: IPCServerState

    public init(endpoint: IPCEndpoint, handler: @escaping Handler) {
        state = IPCServerState(endpoint: endpoint, timing: IPCTiming(), peerUID: IPCSocket.peerUID, handler: handler)
    }

    init(
        endpoint: IPCEndpoint,
        timing: IPCTiming,
        peerUID: @escaping @Sendable (Int32) throws -> uid_t = IPCSocket.peerUID,
        scheduleHandler: @escaping IPCHandlerScheduler = { body in DispatchQueue.main.async(execute: body) },
        handler: @escaping Handler,
    ) {
        state = IPCServerState(
            endpoint: endpoint,
            timing: timing,
            peerUID: peerUID,
            scheduleHandler: scheduleHandler,
            handler: handler,
        )
    }

    deinit {
        let state = state
        state.queue.async { state.stop(nil) }
    }

    public func start() async throws {
        let state = state
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            state.queue.async {
                do { try state.start(); continuation.resume() }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    /// 全 source の cancel handler、FD の close、ソケットの後片付け、ロック解放まで待つ。
    /// handler の開始後に行われた Core の操作は巻き戻せない。CLI は応答を失っても再送しない。
    public func stop() async {
        let state = state
        await withCheckedContinuation { continuation in
            state.queue.async { state.stop(continuation) }
        }
    }
}

private final class IPCServerState: @unchecked Sendable {
    let queue = DispatchQueue(label: "CapsaicinIPC.server")
    let endpoint: IPCEndpoint
    let timing: IPCTiming
    let peerUID: @Sendable (Int32) throws -> uid_t
    let handler: IPCServer.Handler
    let scheduleHandler: IPCHandlerScheduler
    var lease: IPCListenerLease?
    var listener: DispatchSourceRead?
    var running = false
    var generation: UInt64 = 0
    var channels: [ObjectIdentifier: IPCChannel] = [:]
    var stopWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        endpoint: IPCEndpoint,
        timing: IPCTiming,
        peerUID: @escaping @Sendable (Int32) throws -> uid_t,
        scheduleHandler: @escaping IPCHandlerScheduler = { body in DispatchQueue.main.async(execute: body) },
        handler: @escaping IPCServer.Handler,
    ) {
        self.endpoint = endpoint
        self.timing = timing
        self.peerUID = peerUID
        self.handler = handler
        self.scheduleHandler = scheduleHandler
    }

    func start() throws {
        guard lease == nil else { throw IPCTransportError.alreadyRunning }
        let lease = try IPCListenerLease(endpoint: endpoint)
        self.lease = lease
        generation &+= 1
        running = true
        let currentGeneration = generation
        let source = DispatchSource.makeReadSource(fileDescriptor: lease.descriptor, queue: queue)
        listener = source
        source.setEventHandler {
            guard self.running, self.generation == currentGeneration else { return }
            self.acceptReady(lease.descriptor)
        }
        source.setCancelHandler {
            close(lease.descriptor)
            self.listener = nil
            self.finishStopIfReady()
        }
        source.resume()
    }

    func stop(_ waiter: CheckedContinuation<Void, Never>?) {
        if let waiter {
            stopWaiters.append(waiter)
        }
        if running {
            running = false
            generation &+= 1
            listener?.setEventHandler {}
            listener?.cancel()
            for channel in channels.values {
                channel.finish(IPCTransportError.stopped)
            }
        }
        finishStopIfReady()
    }

    func finishStopIfReady() {
        guard !running, listener == nil, channels.isEmpty else { return }
        lease?.cleanup()
        lease = nil
        for waiter in stopWaiters {
            waiter.resume()
        }
        stopWaiters.removeAll()
    }

    func acceptReady(_ descriptor: Int32) {
        // 接続洪水でも1イベントで main queue の処理を占有しない。
        for _ in 0 ..< 8 {
            let accepted = accept(descriptor, nil, nil)
            if accepted < 0 {
                if errno == EINTR {
                    continue
                }
                return
            }
            let acceptedAt = DispatchTime.now()
            do {
                try IPCSocket.configure(accepted)
                guard channels.count < 8 else { close(accepted); continue }
                guard try peerUID(accepted) == geteuid() else { throw IPCTransportError.peerRejected }
            } catch { close(accepted); continue }
            receiveConnection(accepted, acceptedAt: acceptedAt)
        }
    }

    private func receiveConnection(_ descriptor: Int32, acceptedAt: DispatchTime) {
        let channel = IPCChannel(
            descriptor: descriptor, queue: queue, deadline: IPCDeadline(after: timing.requestRead, now: acceptedAt),
        )
        let identifier = ObjectIdentifier(channel)
        let currentGeneration = generation
        let totalDeadline = IPCDeadline(after: timing.requestRead + timing.responseWrite, now: acceptedAt)
        channels[identifier] = channel
        channel.closed = { _ in
            self.channels.removeValue(forKey: identifier)
            self.finishStopIfReady()
        }
        channel.received = { data in
            let request = try IPCCoding.decodeRequest(data)
            self.dispatch(request, on: channel, generation: currentGeneration, totalDeadline: totalDeadline)
        }
        channel.beginRead()
    }

    private func dispatch(
        _ request: IPCRequest,
        on channel: IPCChannel,
        generation: UInt64,
        totalDeadline: IPCDeadline,
    ) {
        // 受信期限を保ったまま main queue を待つ。stop と開始判定は同じ IO queue で直列化する。
        scheduleHandler {
            let mayBegin = self.queue.sync {
                guard self.running, self.generation == generation,
                      self.channels[ObjectIdentifier(channel)] === channel, channel.phase == .waiting,
                      !channel.deadline.expired
                else { return false }
                // この判定点を handler の開始とする。以降の stop は実行済み操作を戻せない。
                channel.setDeadline(totalDeadline)
                return true
            }
            guard mayBegin else { return }
            let response = self.handler(request)
            self.queue.async {
                self.respond(response, on: channel, generation: generation, totalDeadline: totalDeadline)
            }
        }
    }

    private func respond(
        _ response: IPCResponse,
        on channel: IPCChannel,
        generation: UInt64,
        totalDeadline: IPCDeadline,
    ) {
        guard running, self.generation == generation,
              channels[ObjectIdentifier(channel)] === channel, channel.phase == .waiting, !totalDeadline.expired
        else { channel.finish(IPCTransportError.stopped); return }
        do {
            let wire = try IPCFrame.encode(IPCCoding.encode(response))
            let writeDeadline = IPCDeadline(after: timing.responseWrite)
            channel.setDeadline(IPCDeadline(instant: min(writeDeadline.instant, totalDeadline.instant)))
            channel.write(wire) { channel.finish() }
        } catch { channel.finish(error) }
    }
}

/// ロック名は unlink しない。削除すると同じ名前に別 inode のロックを作れてしまう。
private final class IPCListenerLease {
    let directory: IPCDirectory
    private var lock: Int32?
    let descriptor: Int32
    private let boundIdentity: IPCFileIdentity

    init(endpoint: IPCEndpoint) throws {
        let directory = try IPCDirectory(endpoint, create: true)
        let lock = try directory.acquireLock()
        var owned: IPCFileIdentity?
        var socket: Int32 = -1
        do {
            if let stale = try directory.socketIdentity() {
                let probe = try IPCSocket.make()
                defer { close(probe) }
                do {
                    _ = try IPCSocket.connect(probe, endpoint: endpoint)
                    throw IPCTransportError.alreadyRunning
                } catch IPCTransportError.unavailable(ECONNREFUSED) {
                    try directory.removeSocket(ifMatching: stale)
                }
            }
            try directory.validatePath()
            socket = try IPCSocket.make()
            try IPCSocket.bind(socket, endpoint: endpoint)
            var info = stat()
            guard fstatat(directory.descriptor, endpoint.socketName, &info, AT_SYMLINK_NOFOLLOW) == 0,
                  info.st_mode & S_IFMT == S_IFSOCK, info.st_uid == geteuid()
            else { throw IPCTransportError.unsafeEndpoint }
            owned = IPCFileIdentity(info)
            guard fchmodat(directory.descriptor, endpoint.socketName, 0o600, AT_SYMLINK_NOFOLLOW) == 0 else {
                throw IPCTransportError.system(errno)
            }
            try directory.validatePath()
            guard let identity = try directory.socketIdentity(), identity == owned else {
                throw IPCTransportError.unsafeEndpoint
            }
            guard listen(socket, 8) == 0 else { throw IPCTransportError.system(errno) }
            self.directory = directory
            self.lock = lock
            descriptor = socket
            boundIdentity = identity
        } catch {
            if socket >= 0 {
                close(socket)
            }
            if let owned {
                try? directory.removeSocket(ifMatching: owned)
            }
            close(lock)
            throw error
        }
    }

    func cleanup() {
        try? directory.removeSocket(ifMatching: boundIdentity)
        if let lock {
            close(lock); self.lock = nil
        }
    }

    deinit {
        if let lock {
            close(lock)
        }
    }
}
