@testable import CapsaicinIPC
import Darwin
import Foundation
import Testing

struct IPCEndpointTests {
    @Test("SPEC-CLI-004 古いソケットだけをロック中に取り除き、活動中のソケットを消さない", arguments: [false, true])
    func staleVersusActive(active: Bool) async throws {
        let fixture = try IPCTransportFixture()
        let descriptor = try fixture.staleSocket(listening: active)
        if !active {
            close(descriptor)
        }
        let original = try IPCDirectory(fixture.endpoint, create: false).socketIdentity()
        let server = IPCServer(endpoint: fixture.endpoint) { _ in
            IPCResponse(outcome: .status, status: transportStopped)
        }
        if active {
            await #expect(throws: IPCTransportError.alreadyRunning) { try await server.start() }
            #expect(try IPCDirectory(fixture.endpoint, create: false).socketIdentity() == original)
            close(descriptor)
        } else {
            try await server.start()
            let directory = try IPCDirectory(fixture.endpoint, create: false)
            #expect(try directory.socketIdentity() != nil)
            await server.stop()
        }
    }

    @Test("SPEC-CLI-007 ソケット名の通常ファイルと symlink を変更も削除もしない", arguments: [false, true])
    func unexpectedTarget(symlink: Bool) async throws {
        let fixture = try IPCTransportFixture()
        _ = try IPCDirectory(fixture.endpoint, create: true)
        let target = fixture.root.appending(path: "untouched")
        try Data("keep".utf8).write(to: target)
        if symlink {
            try FileManager.default.createSymbolicLink(
                atPath: fixture.endpoint.socketPath,
                withDestinationPath: target.path,
            )
        } else {
            try Data("keep".utf8).write(to: URL(filePath: fixture.endpoint.socketPath))
        }
        let server = IPCServer(endpoint: fixture.endpoint) { _ in
            IPCResponse(outcome: .status, status: transportStopped)
        }
        await #expect(throws: IPCTransportError.unsafeEndpoint) { try await server.start() }
        #expect(try Data(contentsOf: target) == Data("keep".utf8))
        #expect(try Data(contentsOf: URL(filePath: fixture.endpoint.socketPath)) == Data("keep".utf8))
    }

    @Test(
        "SPEC-CLI-007 ディレクトリとロックの権限・種類・hardlink を拒む",
        arguments: ["directoryMode", "directorySymlink", "lockMode", "lockSymlink", "lockHardlink"],
    )
    func unsafeFiles(kind: String) async throws {
        let fixture = try IPCTransportFixture()
        let manager = FileManager.default
        if kind == "directorySymlink" {
            let target = fixture.root.appending(path: "real")
            try manager.createDirectory(
                at: target,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700],
            )
            try manager.createSymbolicLink(atPath: fixture.endpoint.directory, withDestinationPath: target.path)
        } else {
            _ = try IPCDirectory(fixture.endpoint, create: true)
            if kind == "directoryMode" {
                #expect(chmod(fixture.endpoint.directory, 0o755) == 0)
            } else {
                let lock = fixture.endpoint.directory + "/ipc.lock"
                if kind == "lockSymlink" {
                    let target = fixture.root.appending(path: "realLock")
                    try Data().write(to: target)
                    try manager.createSymbolicLink(atPath: lock, withDestinationPath: target.path)
                } else {
                    try Data().write(to: URL(filePath: lock))
                    #expect(chmod(lock, kind == "lockMode" ? 0o644 : 0o600) == 0)
                    if kind ==
                        "lockHardlink"
                    {
                        #expect(link(lock, fixture.root.appending(path: "otherLock").path) == 0)
                    }
                }
            }
        }
        let server = IPCServer(endpoint: fixture.endpoint) { _ in
            IPCResponse(outcome: .status, status: transportStopped)
        }
        await #expect(throws: (any Error).self) { try await server.start() }
        #expect(manager.fileExists(atPath: fixture.endpoint.directory))
    }

    @Test("SPEC-CLI-007 停止は bind 時と inode が違うファイルを消さない")
    func changedInode() async throws {
        let fixture = try IPCTransportFixture()
        let server = IPCServer(endpoint: fixture.endpoint) { _ in
            IPCResponse(outcome: .status, status: transportStopped)
        }
        try await server.start()
        let backup = fixture.endpoint.directory + "/old.sock"
        #expect(rename(fixture.endpoint.socketPath, backup) == 0)
        try Data("keep".utf8).write(to: URL(filePath: fixture.endpoint.socketPath))
        await server.stop()
        #expect(try Data(contentsOf: URL(filePath: fixture.endpoint.socketPath)) == Data("keep".utf8))
        #expect(FileManager.default.fileExists(atPath: backup))
    }

    @Test("SPEC-CLI-007 sun_path は文字数でなく UTF-8 と NUL 分で検査する")
    func pathLength() {
        let endpoint = IPCEndpoint(testDirectory: "/" + String(repeating: "あ", count: 40))
        #expect(throws: IPCTransportError.unsafeEndpoint) { try endpoint.address() }
    }

    @Test("SPEC-CLI-007 権限の不適切な既存ソケットを chmod も削除もしない")
    func socketMode() async throws {
        let fixture = try IPCTransportFixture()
        let descriptor = try fixture.staleSocket()
        close(descriptor)
        #expect(chmod(fixture.endpoint.socketPath, 0o644) == 0)
        var before = stat()
        #expect(lstat(fixture.endpoint.socketPath, &before) == 0)
        let server = IPCServer(endpoint: fixture.endpoint) { _ in
            IPCResponse(outcome: .status, status: transportStopped)
        }
        await #expect(throws: IPCTransportError.unsafeEndpoint) { try await server.start() }
        var after = stat()
        #expect(lstat(fixture.endpoint.socketPath, &after) == 0)
        #expect(after.st_mode & 0o7777 == 0o644)
        #expect(IPCFileIdentity(after) == IPCFileIdentity(before))
    }
}
