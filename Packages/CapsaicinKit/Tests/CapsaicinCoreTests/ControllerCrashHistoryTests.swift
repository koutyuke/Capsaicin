@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation
import Testing

@MainActor
struct ControllerCrashHistoryTests {
    /// 抑止中にクラッシュした後に起動する。起動後のクラッシュ後の起動の一覧は1件になる。
    private func launchAfterCrash(_ system: FakeSystem, settings: Settings) -> BlockingController {
        makeController(system, settings: settings).requestStart(from: .menu)
        system.advance(by: 60)
        return makeController(system, settings: settings)
    }

    @Test("SPEC-LCY-007 解除ではクラッシュ後の起動の一覧を空にする")
    func releaseClearsCrashLaunches() {
        let system = FakeSystem()
        let controller = launchAfterCrash(system, settings: .premise { $0.resumePolicy = .afterAppRestart })
        #expect(controller.isBlocking)
        #expect(system.storedRecord?.crashLaunches.count == 1)
        controller.requestStop(from: .menu)
        #expect(system.storedRecord?.crashLaunches == [])
    }

    @Test("SPEC-LCY-007 利用者の操作による開始では、クラッシュ後の起動の一覧を空にする")
    func userStartClearsCrashLaunches() {
        let system = FakeSystem()
        let controller = launchAfterCrash(system, settings: .premise())
        #expect(!controller.isBlocking)
        #expect(system.storedRecord?.crashLaunches.count == 1)
        controller.requestStart(from: .menu)
        #expect(system.storedRecord?.crashLaunches == [])
    }

    @Test("SPEC-LCY-007 記録を保存できずに開始を拒否したら、クラッシュ後の起動の一覧を空にしない")
    func rejectedStartKeepsCrashLaunches() {
        let system = FakeSystem()
        let controller = launchAfterCrash(system, settings: .premise())
        system.failing = [.saveRecord]
        #expect(controller.requestStart(from: .menu) == .rejected(.recordNotSaved))
        #expect(controller.record.crashLaunches.count == 1)
        system.failing = []
        system.advance(by: 60)
        controller.timePassed()
        #expect(system.storedRecord?.crashLaunches.count == 1)
    }

    @Test("SPEC-LCY-004 SPEC-LCY-007 日をおいた再起動の後は、古いクラッシュの記録を上限の判定に使わずに再開する")
    func oldCrashesDoNotBlockResume() {
        let system = FakeSystem()
        let day: TimeInterval = 86400
        var record = ResumeRecord(lastUpdated: system.now.addingTimeInterval(-day))
        record.session = BlockingSession(timeLimit: nil)
        record.exitReason = .sessionEnd
        record.crashLaunches = (1 ... 3).map { system.now.addingTimeInterval(-2 * day + TimeInterval($0 * 60)) }
        system.storedRecord = record
        system.bootTime = system.now.addingTimeInterval(-60)
        let controller = makeController(
            system,
            settings: .premise { $0.resumePolicy = .afterAppOrMacRestart },
            launch: false,
        )
        #expect(controller.launch() == .afterMacRestart)
        #expect(controller.isBlocking)
        #expect(system.storedRecord?.crashLaunches == [])
    }
}
