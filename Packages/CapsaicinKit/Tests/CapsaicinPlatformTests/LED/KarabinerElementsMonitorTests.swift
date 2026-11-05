@testable import CapsaicinPlatform
import Foundation
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

    @Test("SPEC-LED-005 既知の配置のデーモンだけを検出する（旧 grabber を含む）", arguments: KarabinerProcessSource.daemonPaths.sorted())
    func knownPaths(path: String) throws {
        let fake = ProcessFixture()
        fake.processes[1] = .init(
            name: URL(fileURLWithPath: path).lastPathComponent,
            effectiveUID: 0,
            startSeconds: 1,
            startMicroseconds: 0,
        )
        fake.paths[1] = path
        #expect(try fake.source.isRunning())
    }

    @Test("SPEC-LED-005 同じバイナリーのユーザーエージェントは root デーモンではない")
    func userAgentIsNotDaemon() throws {
        let fake = ProcessFixture()
        fake.processes[1] = .init(
            name: "Karabiner-Core-Service",
            effectiveUID: 501,
            startSeconds: 1,
            startMicroseconds: 0,
        )
        fake.paths[1] = currentPath
        #expect(try !fake.source.isRunning())
        #expect(fake.pathReads.isEmpty)
    }

    @Test("SPEC-LED-005 パス取得中に同じ PID のユーザーエージェントへ交代したら確定しない")
    func pidReusedDuringPathRead() {
        let fake = ProcessFixture()
        fake.processes[1] = .init(
            name: "Karabiner-Core-Service",
            effectiveUID: 0,
            startSeconds: 1,
            startMicroseconds: 0,
        )
        fake.paths[1] = currentPath
        fake.onPathRead = { [weak fake] pid in fake?.processes[pid]?.effectiveUID = 501 }
        #expect(throws: KarabinerDetectionError.processInspectionFailed) { try fake.source.isRunning() }
    }

    @Test("SPEC-LED-005 UID と名前が同じでも起動時刻が変わった候補を採用しない", arguments: [false, true])
    func pidReusedWithSameUID(changesMicroseconds: Bool) {
        let fake = ProcessFixture()
        fake.processes[1] = .init(
            name: "Karabiner-Core-Service",
            effectiveUID: 0,
            startSeconds: 1,
            startMicroseconds: 0,
        )
        fake.paths[1] = currentPath
        fake.onPathRead = { [weak fake] pid in
            if changesMicroseconds {
                fake?.processes[pid]?.startMicroseconds += 1
            } else {
                fake?.processes[pid]?.startSeconds += 1
            }
        }
        #expect(throws: KarabinerDetectionError.processInspectionFailed) { try fake.source.isRunning() }
    }

    @Test("SPEC-LED-005 候補が再確認前に消えた場合も起動を確定しない")
    func candidateDisappearsBeforeConfirmation() {
        let fake = ProcessFixture()
        fake.processes[1] = .init(
            name: "Karabiner-Core-Service",
            effectiveUID: 0,
            startSeconds: 1,
            startMicroseconds: 0,
        )
        fake.paths[1] = currentPath
        fake.onPathRead = { [weak fake] pid in fake?.processes[pid] = nil }
        #expect(throws: KarabinerDetectionError.processInspectionFailed) { try fake.source.isRunning() }
    }

    @Test("SPEC-LED-005 同名の別パスや前方一致では検出しない", arguments: [
        "/tmp/Karabiner-Core-Service",
        "/Applications/Karabiner-Elements.app/Contents/Helpers/Karabiner-Core-Service.app/Contents/MacOS/Karabiner-Core-Service-copy",
        "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_grabber-copy",
    ])
    func exactPathOnly(path: String) throws {
        let fake = ProcessFixture()
        fake.processes[1] = .init(
            name: "Karabiner-Core-Service",
            effectiveUID: 0,
            startSeconds: 1,
            startMicroseconds: 0,
        )
        fake.paths[1] = path
        #expect(try !fake.source.isRunning())
    }

    @Test("SPEC-LED-005 GUI だけでは起動扱いせず、既知の候補以外のパスも読まない")
    func guiAndUnrelatedProcesses() throws {
        let fake = ProcessFixture()
        fake.processes[1] = .init(name: "Karabiner-Elements", effectiveUID: 0, startSeconds: 1, startMicroseconds: 0)
        fake.paths[1] = "/Applications/Karabiner-Elements.app/Contents/MacOS/Karabiner-Elements"
        #expect(try !fake.source.isRunning())
        #expect(fake.pathReads.isEmpty)
    }

    @Test("SPEC-LED-005 名前が空ならパスを確認し、PID の消滅は通常の終了競合として扱う")
    func emptyNameAndExitRace() throws {
        let fake = ProcessFixture()
        fake.pids = [1, 2]
        fake.processes[2] = .init(name: "", effectiveUID: 0, startSeconds: 1, startMicroseconds: 0)
        fake.paths[2] = currentPath
        #expect(try fake.source.isRunning())
        fake.paths = [:]
        #expect(try !fake.source.isRunning())
    }

    @Test("SPEC-LED-005 列挙や候補の取得失敗は停止ではなくエラーにする")
    func inspectionErrors() {
        let fake = ProcessFixture()
        fake.listFails = true
        #expect(throws: KarabinerDetectionError.processListUnavailable) { try fake.source.isRunning() }
        fake.listFails = false
        fake.identityFailures = [1]
        #expect(throws: KarabinerDetectionError.processInspectionFailed) { try fake.source.isRunning() }
        fake.identityFailures = []
        fake.processes[1] = .init(
            name: "Karabiner-Core-Service",
            effectiveUID: 0,
            startSeconds: 1,
            startMicroseconds: 0,
        )
        fake.pathFailures = [1]
        #expect(throws: KarabinerDetectionError.processInspectionFailed) { try fake.source.isRunning() }
    }

    @Test("SPEC-LED-005 別プロセスの取得に失敗しても、確実な root デーモンがあれば起動を検出する")
    func positiveEvidenceWins() throws {
        let fake = ProcessFixture()
        fake.pids = [1, 2]
        fake.identityFailures = [1]
        fake.processes[2] = .init(
            name: "Karabiner-Core-Service",
            effectiveUID: 0,
            startSeconds: 1,
            startMicroseconds: 0,
        )
        fake.paths[2] = currentPath
        #expect(try fake.source.isRunning())
    }

    @Test("SPEC-LED-005 明示的に開始し、初回の確定と起動・終了の遷移だけを通知する")
    func transitions() {
        let fake = DetectionFixture()
        let monitor = fake.makeMonitor()
        #expect(fake.reads == 0)
        #expect(fake.schedules == 0)
        #expect(monitor.state == .unknown)
        monitor.start()
        monitor.start()
        fake.ticks[0]()
        fake.result = .success(true)
        fake.ticks[0]()
        fake.ticks[0]()
        fake.result = .success(false)
        fake.ticks[0]()
        #expect(fake.states == [.notRunning, .running, .notRunning])
        #expect(fake.schedules == 1)
        #expect(fake.reads == 5)
    }

    @Test("SPEC-LED-005 検出失敗は unknown として通知し、停止と取り違えない")
    func unknownIsNotStopped() {
        let fake = DetectionFixture()
        fake.result = .success(true)
        let monitor = fake.makeMonitor()
        monitor.start()
        fake.result = .failure(.processInspectionFailed)
        fake.ticks[0]()
        fake.ticks[0]()
        #expect(monitor.state == .unknown)
        #expect(fake.states == [.running, .unknown])
        #expect(fake.errors == [.processInspectionFailed, .processInspectionFailed])
        fake.result = .success(true)
        fake.ticks[0]()
        fake.result = .success(false)
        fake.ticks[0]()
        #expect(fake.states == [.running, .unknown, .running, .notRunning])
    }

    @Test("SPEC-LED-005 初回の失敗も報告するが unknown の重複通知はしない")
    func initialFailure() {
        let fake = DetectionFixture()
        fake.result = .failure(.processListUnavailable)
        let monitor = fake.makeMonitor()
        monitor.start()
        #expect(monitor.state == .unknown)
        #expect(fake.states.isEmpty)
        #expect(fake.errors == [.processListUnavailable])
    }

    @Test("SPEC-LED-005 停止後と前世代のキュー済みポーリングは無効になる")
    func stoppedAndQueuedTicks() {
        let fake = DetectionFixture()
        let monitor = fake.makeMonitor()
        monitor.start()
        monitor.stop()
        monitor.stop()
        fake.ticks[0]()
        #expect(fake.reads == 1)
        #expect(fake.cancellations == 1)
        monitor.start()
        fake.ticks[0]()
        #expect(fake.reads == 2)
        fake.ticks[1]()
        #expect(fake.reads == 3)
    }

    @Test("SPEC-LED-005 通知先が初回通知の中で停止してもタイマーを開始しない")
    func reentrantStop() {
        let fake = DetectionFixture()
        let monitor = fake.makeMonitor()
        monitor.onStateChange = { [weak monitor] _ in monitor?.stop() }
        monitor.start()
        #expect(fake.schedules == 0)
    }

    @Test("SPEC-LED-005 解放時に監視を止め、残った通知は無効になる")
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

    private var currentPath: String {
        "/Applications/Karabiner-Elements.app/Contents/Helpers/Karabiner-Core-Service.app/Contents/MacOS/Karabiner-Core-Service"
    }
}

private final class ProcessFixture {
    var pids: [Int32] = [1]
    var processes: [Int32: KarabinerProcessIdentity] = [:]
    var paths: [Int32: String] = [:]
    var listFails = false
    var identityFailures: Set<Int32> = []
    var pathFailures: Set<Int32> = []
    var pathReads: [Int32] = []
    var onPathRead: ((Int32) -> Void)?

    var source: KarabinerProcessSource {
        KarabinerProcessSource(listPIDs: {
            if self.listFails {
                throw KarabinerDetectionError.processListUnavailable
            }
            return self.pids
        }, identity: { pid in
            if self.identityFailures.contains(pid) {
                throw KarabinerDetectionError.processInspectionFailed
            }
            return self.processes[pid]
        }, path: { pid in
            self.pathReads.append(pid)
            self.onPathRead?(pid)
            if self.pathFailures.contains(pid) {
                throw KarabinerDetectionError.processInspectionFailed
            }
            return self.paths[pid]
        })
    }
}

@MainActor
private final class DetectionFixture {
    var result: Result<Bool, KarabinerDetectionError> = .success(false)
    var reads = 0
    var schedules = 0
    var cancellations = 0
    var ticks: [KarabinerElementsMonitor.Tick] = []
    var states: [KarabinerElementsState] = []
    var errors: [KarabinerDetectionError] = []

    func makeMonitor() -> KarabinerElementsMonitor {
        let monitor = KarabinerElementsMonitor(detect: {
            self.reads += 1
            return try self.result.get()
        }, schedule: { tick in
            self.schedules += 1
            self.ticks.append(tick)
            return { self.cancellations += 1 }
        })
        monitor.onStateChange = { self.states.append($0) }
        monitor.onDetectionFailure = { error in
            if let error = error as? KarabinerDetectionError {
                self.errors.append(error)
            }
        }
        return monitor
    }
}
