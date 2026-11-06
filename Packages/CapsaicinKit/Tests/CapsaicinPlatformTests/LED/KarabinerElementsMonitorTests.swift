@testable import CapsaicinPlatform
import Testing

@MainActor
struct KarabinerElementsMonitorTests {
    @Test("SPEC-LED-005 検出する実行ファイルは公式ソースで確認した3つの配置に限る")
    func verifiedAllowlist() {
        #expect(KarabinerProcessSource.daemonPaths == [
            "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_grabber",
            "/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Core-Service.app/Contents/MacOS/Karabiner-Core-Service",
            "/Applications/Karabiner-Elements.app/Contents/Helpers/Karabiner-Core-Service.app/Contents/MacOS/Karabiner-Core-Service",
        ])
    }

    @Test("SPEC-LED-005 既知の実行ファイルのパスを検出する", arguments: KarabinerProcessSource.daemonPaths.sorted())
    func knownPaths(path: String) throws {
        let source = KarabinerProcessSource(listPIDs: { [1, 2] }, path: { $0 == 2 ? path : nil })
        #expect(try source.isRunning())
    }

    @Test("SPEC-LED-005 別の配置・GUI・名前の前方一致では検出しない", arguments: [
        "/tmp/Karabiner-Core-Service",
        "/Applications/Karabiner-Elements.app/Contents/MacOS/Karabiner-Elements",
        "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_grabber-copy",
    ])
    func exactPathOnly(path: String) throws {
        let source = KarabinerProcessSource(listPIDs: { [1] }, path: { _ in path })
        #expect(try !source.isRunning())
    }

    @Test("SPEC-LED-005 パスを読めないプロセスや空の一覧では未起動とみなす")
    func missingPaths() throws {
        let missing = KarabinerProcessSource(listPIDs: { [1] }, path: { _ in nil })
        #expect(try !missing.isRunning())
        let empty = KarabinerProcessSource(listPIDs: { [] }, path: { _ in
            Issue.record("空の一覧でパスを読んではいけない")
            return nil
        })
        #expect(try !empty.isRunning())
    }

    @Test("SPEC-LED-005 明示的に開始し、起動・終了の変化だけを通知する")
    func transitions() {
        let fake = DetectionFixture()
        let monitor = fake.makeMonitor()
        #expect(fake.reads == 0)
        #expect(!monitor.state)
        monitor.start()
        monitor.start()
        fake.ticks[0]()
        fake.result = .success(true)
        fake.ticks[0]()
        fake.ticks[0]()
        fake.result = .success(false)
        fake.ticks[0]()
        #expect(fake.states == [true, false])
        #expect(fake.ticks.count == 1)
        #expect(fake.reads == 5)
    }

    @Test("SPEC-LED-005 検出失敗は未起動とみなし、失敗を報告して次の確認を続ける")
    func detectionFailure() {
        let fake = DetectionFixture()
        let monitor = fake.makeMonitor()
        fake.result = .success(true)
        monitor.start()
        fake.result = .failure(.processListUnavailable)
        fake.ticks[0]()
        fake.ticks[0]()
        #expect(!monitor.state)
        #expect(fake.states == [true, false])
        #expect(fake.failures == 2)
        fake.result = .success(true)
        fake.ticks[0]()
        #expect(fake.states == [true, false, true])
    }

    @Test("SPEC-LED-005 停止でタイマーを解除し、再開できる")
    func stopAndRestart() {
        let fake = DetectionFixture()
        let monitor = fake.makeMonitor()
        monitor.start()
        monitor.stop()
        monitor.stop()
        fake.ticks[0]()
        #expect(fake.reads == 1)
        #expect(fake.cancellations == 1)
        monitor.start()
        fake.ticks[1]()
        #expect(fake.reads == 3)
    }

    @Test("SPEC-LED-005 初回通知から停止しても監視を残さない")
    func reentrantStop() {
        let fake = DetectionFixture()
        fake.result = .success(true)
        let monitor = fake.makeMonitor()
        monitor.onStateChange = { [weak monitor] _ in monitor?.stop() }
        monitor.start()
        #expect(fake.cancellations == 1)
        fake.ticks[0]()
        #expect(fake.reads == 1)
    }

    @Test("SPEC-LED-005 解放時に監視を止める")
    func deinitCancels() {
        let fake = DetectionFixture()
        var monitor: KarabinerElementsMonitor? = fake.makeMonitor()
        monitor?.start()
        weak let released = monitor
        monitor = nil
        #expect(released == nil)
        #expect(fake.cancellations == 1)
        fake.ticks[0]()
        #expect(fake.reads == 1)
    }
}

@MainActor
private final class DetectionFixture {
    var result: Result<Bool, KarabinerDetectionError> = .success(false)
    var reads = 0
    var cancellations = 0
    var ticks: [KarabinerElementsMonitor.Tick] = []
    var states: [Bool] = []
    var failures = 0

    func makeMonitor() -> KarabinerElementsMonitor {
        let monitor = KarabinerElementsMonitor(detect: {
            self.reads += 1
            return try self.result.get()
        }, schedule: { tick in
            self.ticks.append(tick)
            return { self.cancellations += 1 }
        })
        monitor.onStateChange = { self.states.append($0) }
        monitor.onDetectionFailure = { _ in self.failures += 1 }
        return monitor
    }
}
