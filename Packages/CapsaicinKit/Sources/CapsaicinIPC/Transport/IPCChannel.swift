import Darwin
import Dispatch
import Foundation

/// FD と全 DispatchSource の唯一の所有者。すべての状態は queue 上だけで触る。
final class IPCChannel: @unchecked Sendable {
    enum Phase { case idle, connecting, writing, reading, waiting, closing }
    let descriptor: Int32
    let queue: DispatchQueue
    private(set) var phase = Phase.idle
    private(set) var deadline: IPCDeadline
    private var reader: DispatchSourceRead?
    private var writer: DispatchSourceWrite?
    private var timer: DispatchSourceTimer?
    private var readSuspended = true
    private var writeSuspended = true
    private var cancellationCount = 3
    private var output = Data()
    private var offset = 0
    private var frame = IPCFrame()
    private var afterWrite: (() -> Void)?
    private var terminalError: Error?
    var connected: (() throws -> Void)?
    var received: ((Data) throws -> Void)?
    var closed: ((Error?) -> Void)?

    init(descriptor: Int32, queue: DispatchQueue, deadline: IPCDeadline) {
        self.descriptor = descriptor
        self.queue = queue
        self.deadline = deadline
        let reader = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        let writer = DispatchSource.makeWriteSource(fileDescriptor: descriptor, queue: queue)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        self.reader = reader
        self.writer = writer
        self.timer = timer
        reader.setEventHandler { self.readReady() }
        writer.setEventHandler { self.writeReady() }
        timer.setEventHandler {
            // 再スケジュール前に配送済みだった、前の段階の通知では切らない。
            if self.deadline.expired {
                self.finish(IPCTransportError.timedOut)
            }
        }
        reader.setCancelHandler { self.sourceCancelled() }
        writer.setCancelHandler { self.sourceCancelled() }
        timer.setCancelHandler { self.sourceCancelled() }
        timer.schedule(deadline: deadline.instant)
        timer.resume()
    }

    func setDeadline(_ value: IPCDeadline) {
        deadline = value
        timer?.schedule(deadline: value.instant)
    }

    func beginConnect() {
        phase = .connecting
        setWriting(true)
    }

    func didConnect() throws {
        phase = .idle
        setWriting(false)
        try connected?()
    }

    func beginRead() {
        phase = .reading
        setReading(true)
    }

    func write(_ data: Data, after: @escaping () -> Void) {
        guard phase != .closing else { return }
        output = data
        offset = 0
        afterWrite = after
        phase = .writing
        setWriting(true)
    }

    func finish(_ error: Error? = nil) {
        guard phase != .closing else { return }
        phase = .closing
        terminalError = error
        connected = nil
        received = nil
        afterWrite = nil
        reader?.setEventHandler {}
        writer?.setEventHandler {}
        timer?.setEventHandler {}
        reader?.cancel()
        writer?.cancel()
        timer?.cancel()
        // 中断状態のまま破棄すると cancel handler が走らない。
        setReading(true)
        setWriting(true)
    }

    private func sourceCancelled() {
        cancellationCount -= 1
        guard cancellationCount == 0 else { return }
        close(descriptor)
        reader = nil
        writer = nil
        timer = nil
        let callback = closed
        closed = nil
        callback?(terminalError)
    }

    private func setReading(_ enabled: Bool) {
        if enabled, readSuspended {
            reader?.resume(); readSuspended = false
        }
        if !enabled, !readSuspended {
            reader?.suspend(); readSuspended = true
        }
    }

    private func setWriting(_ enabled: Bool) {
        if enabled, writeSuspended {
            writer?.resume(); writeSuspended = false
        }
        if !enabled, !writeSuspended {
            writer?.suspend(); writeSuspended = true
        }
    }

    private func writeReady() {
        guard !deadline.expired else { finish(IPCTransportError.timedOut); return }
        do {
            if phase == .connecting {
                try finishConnect()
                return
            }
            guard phase == .writing else { return }
            for _ in 0 ..< 4 {
                let count = output.withUnsafeBytes { bytes in
                    Darwin.send(descriptor, bytes.baseAddress!.advanced(by: offset), output.count - offset, 0)
                }
                if count < 0 {
                    if errno == EINTR {
                        continue
                    }
                    if errno == EAGAIN {
                        return
                    }
                    throw IPCTransportError.system(errno)
                }
                guard count > 0 else { throw IPCTransportError.invalidFrame }
                offset += count
                if offset == output.count {
                    try finishWrite()
                    return
                }
            }
        } catch { finish(error) }
    }

    private func finishConnect() throws {
        var code: Int32 = 0
        var size = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &code, &size) == 0 else {
            throw IPCTransportError.system(errno)
        }
        if code == ENOENT || code == ECONNREFUSED {
            throw IPCTransportError.unavailable(code)
        }
        guard code == 0 else { throw IPCTransportError.system(code) }
        try didConnect()
    }

    private func finishWrite() throws {
        guard shutdown(descriptor, SHUT_WR) == 0 else { throw IPCTransportError.system(errno) }
        output = Data()
        phase = .waiting
        setWriting(false)
        let callback = afterWrite
        afterWrite = nil
        callback?()
    }

    private func readReady() {
        guard phase == .reading else { return }
        guard !deadline.expired else { finish(IPCTransportError.timedOut); return }
        do {
            for _ in 0 ..< 4 {
                // ヘッダーだけ先に読む。巨大な入力の本文を drain しない。
                var buffer = [UInt8](repeating: 0, count: min(frame.nextReadSize, IPCFrame.maximumPayload))
                let count = recv(descriptor, &buffer, buffer.count, 0)
                if count < 0 {
                    if errno == EINTR {
                        continue
                    }
                    if errno == EAGAIN {
                        return
                    }
                    throw IPCTransportError.system(errno)
                }
                if count == 0 {
                    let payload = try frame.finish()
                    phase = .waiting
                    setReading(false)
                    try received?(payload)
                    return
                }
                try frame.append(Data(buffer.prefix(count)))
            }
        } catch { finish(error) }
    }
}
