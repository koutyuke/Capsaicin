@testable import CapsaicinIPC
import Foundation
import Testing

struct IPCFrameTests {
    @Test("SPEC-CLI-007 フレームは分割入力と EOF を要求する")
    func fragmentedFrame() throws {
        let payload = Data("hello".utf8)
        let wire = try IPCFrame.encode(payload)
        var decoder = IPCFrame()
        for byte in wire {
            try decoder.append(Data([byte]))
        }
        #expect(try decoder.finish() == payload)
        #expect(throws: IPCTransportError.invalidFrame) { try decoder.append(Data([0])) }
    }

    @Test("SPEC-CLI-007 巨大なヘッダー・空フレーム・欠けた入力を拒む")
    func rejectsInvalidFrames() throws {
        for bytes: [UInt8] in [[0, 0, 0, 0], [0, 0, 64, 1], [255, 255, 255, 255]] {
            var decoder = IPCFrame()
            #expect(throws: IPCTransportError.invalidFrame) { try decoder.append(Data(bytes)) }
        }
        var decoder = IPCFrame()
        try decoder.append(Data([0, 0, 0, 2, 1]))
        #expect(throws: IPCTransportError.invalidFrame) { try decoder.finish() }
    }

    @Test("SPEC-CLI-004 Debug と Release の場所は環境変数によらず分かれる")
    func namespaces() {
        #expect(IPCEndpoint(namespace: .release)
            .socketPath == "/private/tmp/io.github.koutyuke.capsaicin-\(geteuid())/ipc.sock")
        #expect(IPCEndpoint(namespace: .debug).socketPath.hasSuffix("/ipc.debug.sock"))
    }
}
