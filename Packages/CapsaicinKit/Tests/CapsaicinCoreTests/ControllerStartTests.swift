@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation
import Testing

@MainActor
struct ControllerStartTests {
    private let manual = Settings.premise { $0.blocksManualSleep = true }

    @Test("SPEC-BLK-010 開始では止めるスリープに必要な仕組みと LED を適用し、セッションを記録する")
    func startApplies() {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        let events = EventRecorder(controller)
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(controller.isBlocking)
        #expect(system.sleepDisabled)
        #expect(system.heldAssertions == [.preventUserIdleSystemSleep])
        #expect(system.isLEDLit)
        #expect(system.storedRecord?.session == BlockingSession(timeLimit: nil))
        #expect(system.storedRecord?.ownsSleepDisabled == true)
        #expect(controller.misalignments.isEmpty)
        #expect(system.redundantAssertionCalls == 0)
        #expect(events.stateEvents == [.started(.user(.menu))])
    }

    @Test("SPEC-BLK-010 一部を適用できなければ開始を拒否し、適用したものを戻す")
    func allOrNothing() {
        let system = FakeSystem()
        system.failing = [.helperOn]
        let controller = makeController(system, settings: manual)
        let events = EventRecorder(controller)
        #expect(controller.requestStart(from: .hotkey) == .rejected(.mechanismsFailed([.systemSleepDisabled])))
        #expect(!controller.isBlocking)
        #expect(system.heldAssertions.isEmpty)
        #expect(!system.isLEDLit)
        #expect(system.storedRecord?.session == nil)
        // on が失敗したので SleepDisabled は 0 のまま。下ろすときの規則で所有を外す。
        #expect(system.storedRecord?.ownsSleepDisabled == false)
        #expect(controller.misalignments.isEmpty)
        #expect(events.stateEvents == [.startRejected(.user(.hotkey), .mechanismsFailed([.systemSleepDisabled]))])
    }

    @Test("SPEC-BLK-010 SPEC-LED-001 LED を点灯できなくても開始し、LED を適用できていない制御にする")
    func ledFailureDoesNotBlockStart() {
        let system = FakeSystem()
        system.failing = [.setLEDLit(true)]
        let controller = makeController(system)
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(controller.misalignments == [.led: .notApplied])
        #expect(system.storedRecord?.misalignments == [.led: .notApplied])
    }

    @Test("SPEC-LED-006 LED を制御できない環境では LED に触れず、合わせられていない制御にもしない")
    func ledUnavailable() {
        let system = FakeSystem()
        system.isLEDAvailable = false
        let controller = makeController(system)
        controller.requestStart(from: .menu)
        controller.requestStop(from: .menu)
        #expect(!system.operations.contains {
            if case .setLEDLit = $0 {
                true
            } else {
                false
            }
        })
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-BLK-008 開始時にバッテリー残量の条件が成り立っていれば、何も適用せずに拒否する")
    func batteryRejects() {
        let system = FakeSystem()
        system.powerState = PowerState(batteryLevel: 10, isOnACPower: false)
        let controller = makeController(system, settings: Settings())
        system.clearHistory()
        #expect(controller.requestStart(from: .hotkey) == .rejected(.batteryBelowThreshold))
        #expect(system.heldAssertions.isEmpty)
        #expect(!system.operations.contains(.createAssertion(.preventUserIdleSystemSleep)))
    }

    @Test("SPEC-BLK-012 手動スリープを止める設定でヘルパーがなければ、開始を拒否する")
    func helperMissingRejects() {
        let system = FakeSystem()
        system.isHelperInstalled = false
        let controller = makeController(system, settings: manual)
        #expect(controller.requestStart(from: .menu) == .rejected(.helperNotInstalled))
    }

    @Test("SPEC-BLK-012 内蔵バッテリーのない Mac では、バッテリー残量の保存値がオンでも開始する")
    func desktopStarts() {
        let system = FakeSystem()
        system.powerState = PowerState(batteryLevel: nil, isOnACPower: true)
        let controller = makeController(system, settings: Settings(), capabilities: .desktop)
        #expect(controller.requestStart(from: .menu) == .started)
    }

    @Test("SPEC-LCY-007 SPEC-HLP-005 所有の「立てた」を保存してから on を実行し、セッションは仕組みを適用した後に書く")
    func recordOrder() throws {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        system.clearHistory()
        controller.requestStart(from: .menu)
        let ops = system.operations
        let saveBeforeOn = try #require(ops.firstIndex(of: .saveRecord))
        let turnOn = try #require(ops.firstIndex(of: .helperOn))
        let createAssertion = try #require(ops.firstIndex(of: .createAssertion(.preventUserIdleSystemSleep)))
        #expect(saveBeforeOn < turnOn)
        #expect(system.savedRecords.first?.ownsSleepDisabled == true)
        #expect(system.savedRecords.first?.session == nil)
        let sessionSave = try #require(system.savedRecords.firstIndex { $0.session != nil })
        let sessionSaveOp = ops.indices.filter { ops[$0] == .saveRecord }[sessionSave]
        #expect(sessionSaveOp > createAssertion)
    }

    @Test("SPEC-LCY-007 SPEC-HLP-005 所有を保存できなければ on を実行せず、状態を保存できないことを理由に拒否する")
    func ownershipNotSaved() {
        let system = FakeSystem()
        let controller = makeController(system, settings: manual)
        system.failing = [.saveRecord]
        #expect(controller.requestStart(from: .cli) == .rejected(.recordNotSaved))
        #expect(!system.operations.contains(.helperOn))
        #expect(!system.sleepDisabled)
        #expect(controller.isRecordUnsaved)
    }

    @Test("SPEC-LCY-007 仕組みを適用した後にセッションを保存できなければ、拒否して戻す")
    func sessionNotSaved() {
        let system = FakeSystem()
        let controller = makeController(system)
        system.failing = [.saveRecord]
        #expect(controller.requestStart(from: .menu) == .rejected(.recordNotSaved))
        #expect(system.heldAssertions.isEmpty)
        #expect(!system.isLEDLit)
        #expect(!controller.isBlocking)
    }

    @Test("SPEC-HLP-005 SleepDisabled が外部の 1 なら on を実行せずに開始し、解除でも下ろさない")
    func externalSleepDisabled() {
        let system = FakeSystem()
        system.sleepDisabled = true
        let controller = makeController(system, settings: manual)
        #expect(controller.requestStart(from: .menu) == .started)
        controller.requestStop(from: .menu)
        #expect(!system.operations.contains(.helperOn))
        #expect(!system.operations.contains(.helperOff))
        #expect(system.sleepDisabled)
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-HLP-005 SleepDisabled を読めなければ、開始では on の失敗と同じに扱う")
    func unreadableRejects() {
        let system = FakeSystem()
        system.failing = [.readSleepDisabled]
        let controller = makeController(system, settings: manual)
        #expect(controller.requestStart(from: .menu) == .rejected(.mechanismsFailed([.systemSleepDisabled])))
        #expect(!system.operations.contains(.helperOn))
    }

    @Test("SPEC-BLK-011 抑止中の開始は何も変えず、解除の時刻もそのまま")
    func startWhileBlocking() {
        let system = FakeSystem()
        let controller = makeController(system, settings: .premise { $0.timerEnabled = true })
        controller.requestStart(from: .menu)
        let session = controller.session
        system.clearHistory()
        #expect(controller.requestStart(from: .cli, override: .timer(minutes(120))) == .alreadyBlocking)
        #expect(controller.session == session)
        #expect(system.operations.isEmpty)
    }

    @Test("SPEC-BLK-011 ホットキーは停止中なら指定なしで開始し、抑止中なら解除する")
    func hotkeyToggles() {
        let system = FakeSystem()
        let controller = makeController(system)
        let events = EventRecorder(controller)
        controller.toggleByHotkey()
        #expect(controller.isBlocking)
        controller.toggleByHotkey()
        #expect(!controller.isBlocking)
        #expect(events.stateEvents == [.started(.user(.hotkey)), .released(.user(.hotkey))])
    }

    @Test("SPEC-BLK-003 SPEC-BLK-005 開始の時点の暦とタイムゾーンで指定時刻の解除の時刻を決める")
    func startUsesCalendar() {
        let tokyo = calendar("Asia/Tokyo")
        let system = FakeSystem(now: tokyo.date(2026, 11, 6, 23, 0), calendar: tokyo)
        let controller = makeController(system)
        controller.requestStart(from: .cli, override: .specifiedTime(time(4, 0)))
        #expect(controller.session?.timeLimit == TimeLimit(
            date: tokyo.date(2026, 11, 7, 4, 0),
            source: .specifiedTime,
        ))
    }

    @Test("SPEC-BLK-010 必要な仕組みを先に適用し、最初の失敗でやめて、LED は一度も点けない")
    func stopsAtFirstRequiredFailure() {
        let system = FakeSystem()
        system.failing = [.helperOn]
        let controller = makeController(system, settings: .premise {
            $0.blocksManualSleep = true
            $0.blocksDisplaySleep = true
        })
        system.clearHistory()
        #expect(controller.requestStart(from: .menu) == .rejected(.mechanismsFailed([.systemSleepDisabled])))
        #expect(!system.operations.contains(.setLEDLit(true)))
        #expect(!system.operations.contains {
            if case .createAssertion = $0 {
                true
            } else {
                false
            }
        })
    }

    @Test("SPEC-BLK-010 アサーションを作れなくても、LED は点けずに拒否する")
    func ledNotLitWhenAssertionFails() {
        let system = FakeSystem()
        system.failing = [.createAssertion(.preventUserIdleSystemSleep)]
        let controller = makeController(system)
        system.clearHistory()
        #expect(controller.requestStart(from: .menu) == .rejected(.mechanismsFailed([.idleSleepAssertion])))
        #expect(!system.operations.contains(.setLEDLit(true)))
        #expect(controller.misalignments.isEmpty)
    }

    @Test(
        "SPEC-BLK-007 SPEC-BLK-012 変種 B と蓋のない Mac では、蓋閉じスリープの制御をどの契機でも操作せず、合わせられていない制御にもしない",
        arguments: [MachineCapabilities.laptopVariantB, .desktop],
    )
    func lidControlUnusedOutsideVariantA(capabilities: MachineCapabilities) {
        let system = FakeSystem()
        system.failing = [.setLidSleepDisabled(true), .setLidSleepDisabled(false)]
        let settings = Settings.premise {
            $0.blocksLidSleep = true
            $0.blocksManualSleep = true
        }
        let controller = makeController(system, settings: settings, capabilities: capabilities)
        #expect(controller.requestStart(from: .menu) == .started)
        controller.requestStop(from: .menu)
        controller.requestStart(from: .menu)
        _ = controller.quitByUser()
        #expect(!system.operations.contains {
            if case .setLidSleepDisabled = $0 {
                true
            } else {
                false
            }
        })
        #expect(controller.misalignments.isEmpty)
    }

    @Test("SPEC-BLK-007 アサーションの解放に失敗した後の開始は、冪等の作成で二重に作らずに始まる")
    func startAfterFailedRelease() {
        let system = FakeSystem()
        let controller = makeController(system)
        controller.requestStart(from: .menu)
        system.failing = [.releaseAssertion(.preventUserIdleSystemSleep)]
        controller.requestStop(from: .menu)
        #expect(controller.misalignments == [.idleSleepAssertion: .leftApplied])
        system.failing = []
        #expect(controller.requestStart(from: .menu) == .started)
        #expect(system.heldAssertions == [.preventUserIdleSystemSleep])
        #expect(system.redundantAssertionCalls == 1)
        #expect(controller.misalignments.isEmpty)
    }
}
