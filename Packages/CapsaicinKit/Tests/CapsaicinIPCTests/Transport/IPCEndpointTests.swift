@testable import CapsaicinIPC
import Darwin
import Foundation
import Testing

struct IPCEndpointTests {
    @Test("SPEC-CLI-004 接続できない古いソケットを取り除き、活動中のソケットは消さない", arguments: [false, true])
    func staleVersusActive(active: Bool) async throws {
        let fixture = try IPCTransportFixture()
        let descriptor = try fixture.staleSocket(listening: active)
        if !active {
            close(descriptor)
        }
        let server = IPCServer(endpoint: fixture.endpoint) { _ in
            IPCResponse(outcome: .status, status: transportStopped)
        }
        if active {
            await #expect(throws: IPCTransportError.alreadyRunning) { try await server.start() }
            #expect(FileManager.default.fileExists(atPath: fixture.endpoint.socketPath))
            close(descriptor)
        } else {
            try await server.start()
            let connection = try await fixture.client().connect()
            #expect(try await connection.request(IPCRequest(command: .status)).outcome == .status)
            await server.stop()
        }
    }

    @Test("SPEC-CLI-007 ソケット名の通常ファイルと symlink を変更も削除もしない", arguments: [false, true])
    func unexpectedTarget(symlink: Bool) async throws {
        let fixture = try IPCTransportFixture()
        try FileManager.default.createDirectory(
            atPath: fixture.endpoint.directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700],
        )
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

    @Test("SPEC-CLI-007 利用者専用でないディレクトリと symlink は拒む", arguments: [false, true])
    func unsafeDirectory(symlink: Bool) async throws {
        let fixture = try IPCTransportFixture()
        if symlink {
            try FileManager.default.createSymbolicLink(
                atPath: fixture.endpoint.directory,
                withDestinationPath: fixture.root.path,
            )
        } else {
            try FileManager.default.createDirectory(
                atPath: fixture.endpoint.directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o755],
            )
        }
        let server = IPCServer(endpoint: fixture.endpoint) { _ in
            IPCResponse(outcome: .status, status: transportStopped)
        }
        await #expect(throws: IPCTransportError.unsafeEndpoint) { try await server.start() }
    }

    @Test("SPEC-CLI-007 sun_path は UTF-8 の長さと NUL を検査する", arguments: [String(repeating: "あ", count: 40), "bad\0path"])
    func pathLength(path: String) {
        #expect(throws: IPCTransportError.unsafeEndpoint) { try IPCEndpoint(testDirectory: "/" + path).address() }
    }

    @Test("SPEC-CLI-004 Debug と Release の場所は環境変数によらず分かれる")
    func namespaces() {
        #expect(IPCEndpoint(namespace: .release)
            .socketPath == "/private/tmp/io.github.koutyuke.capsaicin-\(geteuid())/ipc.sock")
        #expect(IPCEndpoint(namespace: .debug).socketPath.hasSuffix("/ipc.debug.sock"))
    }
}
