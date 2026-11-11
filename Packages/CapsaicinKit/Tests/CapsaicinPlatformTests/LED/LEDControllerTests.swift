import CapsaicinCore
@testable import CapsaicinPlatform
import Testing

@MainActor
struct LEDControllerTests {
    @Test("SPEC-LED-001 SPEC-LED-002 Transport のある内蔵・外付けキーボードだけに On と Auto を書き、仮想キーボードには書かない")
    func allKeyboards() throws {
        let fake = LEDTestFixture()
        fake.devices += [.init(name: "virtual", hasTransport: false), .init(name: "mouse", keyboard: false)]
        let controller: any CapsLockLEDControlling = fake.makeController()
        try controller.setLit(true)
        try controller.setLit(false)
        #expect(fake.writes == ["On", "Auto"].flatMap { mode in
            ["internal", "external"].map { .init(device: $0, mode: mode) }
        })
        #expect(fake.creations == 2)
    }

    @Test("SPEC-LED-001 SPEC-LED-002 仮想キーボードだけなら初回の復旧・点灯・再適用・解除でも書かない")
    func virtualKeyboardsOnly() throws {
        let fake = LEDTestFixture()
        fake.devices = [.init(name: "virtual", hasTransport: false)]
        fake.failedDevices = ["virtual"]
        let controller = fake.makeController()
        try controller.setLit(false)
        try controller.setLit(true)
        try controller.reapply()
        try controller.setLit(false)
        #expect(fake.writes.isEmpty)
        #expect(fake.creations == 4)
        #expect(fake.enumerations == 4)
    }

    @Test("SPEC-LED-006 関数がないときは生成・列挙・監視も書き込みも行わない")
    func absentAPI() throws {
        let fake = LEDTestFixture()
        fake.available = false
        let controller = fake.makeController()
        #expect(!controller.isAvailable)
        try controller.setLit(true)
        try controller.reapply()
        try controller.setLit(false)
        #expect(fake.creations == 0)
        #expect(fake.enumerations == 0)
        #expect(fake.registrations == 0)
        #expect(fake.writes.isEmpty)
    }

    @Test("SPEC-LED-006 生成時は接続せず、クライアント生成失敗と関数の欠如を区別する")
    func creationFailure() throws {
        let fake = LEDTestFixture()
        fake.creationFails = true
        let controller = fake.makeController()
        #expect(controller.isAvailable)
        #expect(fake.creations == 0)
        #expect(fake.registrations == 0)
        #expect(throws: CapsLockLEDError.clientCreationFailed) { try controller.setLit(true) }
        #expect(controller.isAvailable)
        fake.creationFails = false
        try controller.setLit(false)
        #expect(fake.creations == 2)
        #expect(fake.writes.map(\.mode) == ["Auto", "Auto"])
    }

    @Test("SPEC-LED-002 SPEC-LED-006 対象ゼロは成功、列挙失敗は API 不在ではない")
    func emptyAndFailedEnumeration() throws {
        let fake = LEDTestFixture()
        fake.devices = []
        let controller = fake.makeController()
        try controller.setLit(true)
        #expect(fake.writes.isEmpty)
        #expect(controller.isAvailable)
        fake.enumerationFails = true
        #expect(throws: CapsLockLEDError.servicesUnavailable) { try controller.reapply() }
        #expect(controller.isAvailable)
        fake.enumerationFails = false
        try controller.setLit(false)
        #expect(fake.enumerations == 3)
    }

    @Test("SPEC-LED-001 Core の初回 false は前プロセスを復旧し、成功後の false は冪等")
    func initialOffRestoresPredecessor() throws {
        let fake = LEDTestFixture()
        let controller: any CapsLockLEDControlling = fake.makeController()
        try controller.setLit(false)
        try controller.setLit(false)
        #expect(fake.writes.map(\.mode) == ["Auto", "Auto"])
        #expect(fake.enumerations == 1)
        #expect(fake.registrations == 0)
    }

    @Test("SPEC-LED-001 初回 Auto が失敗したら成功するまで不明として残す")
    func initialOffFailureCanRetry() throws {
        let fake = LEDTestFixture()
        fake.failedDevices = ["internal"]
        let controller = fake.makeController()
        #expect(throws: CapsLockLEDError.writeFailed(failedTargets: 1)) { try controller.setLit(false) }
        #expect(fake.writes.map(\.device) == ["internal", "external"])
        fake.failedDevices = []
        try controller.setLit(false)
        try controller.setLit(false)
        #expect(fake.enumerations == 2)
    }

    @Test("SPEC-LED-001 途中で失敗しても全対象を試し、Auto の失敗後にも解除を再試行する")
    func partialWriteAndRestoreRetry() throws {
        let fake = LEDTestFixture()
        fake.failedDevices = ["internal"]
        let controller = fake.makeController()
        #expect(throws: CapsLockLEDError.writeFailed(failedTargets: 1)) { try controller.setLit(true) }
        #expect(fake.writes.map(\.device) == ["internal", "external"])
        #expect(throws: CapsLockLEDError.writeFailed(failedTargets: 1)) { try controller.setLit(false) }
        let attempts = fake.enumerations
        fake.changes[0]()
        try controller.reapply()
        #expect(fake.enumerations == attempts)
        fake.failedDevices = []
        try controller.setLit(false)
        try controller.setLit(false)
        #expect(fake.writes.map(\.mode) == ["On", "On", "Auto", "Auto", "Auto", "Auto"])
        #expect(fake.enumerations == 3)
    }

    @Test("SPEC-LED-002 接続・切断・復帰・解除時にクライアントを作り直し、その時点のサービスを再列挙する")
    func connectionRemovalAndWake() throws {
        let fake = LEDTestFixture()
        let controller = fake.makeController()
        try controller.setLit(true)
        fake.devices.append(.init(name: "new"))
        fake.changes[0]()
        fake.devices.removeFirst()
        fake.failedDevices = ["internal"]
        fake.changes[0]()
        fake.devices = [.init(name: "resumed"), .init(name: "new")]
        fake.failedDevices.insert("external")
        try controller.reapply()
        try controller.setLit(false)
        #expect(fake.writes == [
            .init(device: "internal", mode: "On"),
            .init(device: "external", mode: "On"),
            .init(device: "internal", mode: "On"),
            .init(device: "external", mode: "On"),
            .init(device: "new", mode: "On"),
            .init(device: "external", mode: "On"),
            .init(device: "new", mode: "On"),
            .init(device: "resumed", mode: "On"),
            .init(device: "new", mode: "On"),
            .init(device: "resumed", mode: "Auto"),
            .init(device: "new", mode: "Auto"),
        ])
        #expect(fake.errors.isEmpty)
        #expect(fake.creations == 5)
        #expect(fake.enumerations == 5)
        #expect(fake.registrations == 1)
    }

    @Test("SPEC-LED-002 非同期の再適用失敗を通知し、復帰時の失敗を throw する")
    func asynchronousFailureIsVisible() throws {
        let fake = LEDTestFixture()
        let controller = fake.makeController()
        try controller.setLit(true)
        fake.failedDevices = ["internal", "external"]
        fake.changes[0]()
        #expect(fake.errors == [.writeFailed(failedTargets: 2)])
        #expect(throws: CapsLockLEDError.writeFailed(failedTargets: 2)) { try controller.reapply() }
        #expect(fake.errors.count == 1)
    }

    @Test("SPEC-LED-002 停止後や再開前のキュー済み通知では書き込まない")
    func stoppedAndQueuedCallbacks() throws {
        let fake = LEDTestFixture()
        let controller = fake.makeController()
        try controller.setLit(true)
        controller.stopMonitoring()
        controller.stopMonitoring()
        fake.changes[0]()
        #expect(fake.enumerations == 1)
        #expect(fake.cancellations == 1)
        try controller.setLit(true)
        fake.changes[0]()
        #expect(fake.enumerations == 2)
        fake.changes[1]()
        #expect(fake.enumerations == 3)
        try controller.setLit(false)
        fake.changes[1]()
        #expect(fake.enumerations == 4)
    }

    @Test("SPEC-LED-002 監視開始の失敗を隠さず、解除時の復旧意図は残す")
    func monitorStartFailure() throws {
        let fake = LEDTestFixture()
        fake.monitorFails = true
        let controller = fake.makeController()
        #expect(throws: CapsLockLEDError.keyboardMonitorCreationFailed) { try controller.setLit(true) }
        #expect(fake.creations == 0)
        try controller.setLit(false)
        #expect(fake.writes.map(\.mode) == ["Auto", "Auto"])
    }

    @Test("SPEC-LED-001 SPEC-LED-002 解放時は監視だけを止め、暗黙の LED 書き込みをしない")
    func deinitStopsWithoutWriting() throws {
        let fake = LEDTestFixture()
        var controller: CapsLockLEDController? = fake.makeController()
        try controller?.setLit(true)
        weak let released = controller
        controller = nil
        #expect(released == nil)
        #expect(fake.cancellations == 1)
        fake.changes[0]()
        #expect(fake.writes.map(\.mode) == ["On", "On"])
    }
}
