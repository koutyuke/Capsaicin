import CapsaicinCore
@testable import CapsaicinPlatform
import Foundation
import IOKit.pwr_mgt
import Testing

@MainActor
struct PowerPlatformAssertionsTests {
    @Test("SPEC-BLK-001 / SPEC-BLK-007 種類ごとに所有し、作成・解放は冪等")
    func assertionOwnership() throws {
        let fake = AssertionServer()
        let assertions = fake.makeAssertions()
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        try assertions.createAssertion(.preventUserIdleDisplaySleep)
        #expect(fake.types == ["PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep"])
        #expect(fake.names == ["Capsaicin", "Capsaicin"])
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        try assertions.releaseAssertion(.preventUserIdleDisplaySleep)
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        #expect(fake.released == [1, 2, 3])
    }

    @Test("SPEC-BLK-007 解放失敗は ID を残して再試行し、重複作成しない")
    func releaseFailureAndRetry() throws {
        let fake = AssertionServer()
        let assertions = fake.makeAssertions()
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        fake.releaseResult = -2
        for _ in 0 ..< 2 {
            #expect(throws: PowerPlatformError.ioKit(operation: "IOPMAssertionRelease", code: -2)) {
                try assertions.releaseAssertion(.preventUserIdleSystemSleep)
            }
            try assertions.createAssertion(.preventUserIdleSystemSleep)
        }
        fake.releaseResult = 0
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        #expect(fake.types.count == 1)
        #expect(fake.released == [1, 1, 1])
    }

    @Test("SPEC-BLK-007 作成失敗は ID を保存せず、次の作成を試せる")
    func createFailureAndRetry() throws {
        let fake = AssertionServer()
        let assertions = fake.makeAssertions()
        fake.createResult = -1
        #expect(throws: PowerPlatformError.ioKit(operation: "IOPMAssertionCreateWithName", code: -1)) {
            try assertions.createAssertion(.preventUserIdleSystemSleep)
        }
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        #expect(fake.released.isEmpty)
        fake.createResult = 0
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        #expect(fake.types.count == 2)
        #expect(fake.released == [2])
    }

    @Test("SPEC-LCY-006 破棄時には残っている ID を解放する", arguments: [false, true])
    func destructionReleasesOwnedIDs(afterFailure: Bool) throws {
        let fake = AssertionServer()
        var assertions: PowerAssertions? = fake.makeAssertions()
        try assertions?.createAssertion(.preventUserIdleSystemSleep)
        if afterFailure {
            fake.releaseResult = -2
            #expect(throws: (any Error).self) { try assertions?.releaseAssertion(.preventUserIdleSystemSleep) }
        }
        weak let released = assertions
        assertions = nil
        #expect(released == nil)
        #expect(fake.released == (afterFailure ? [1, 1] : [1]))
    }

    @Test("SPEC-BLK-001 / SPEC-LCY-006 蓋制御は毎回真偽値を渡し、接続を閉じる")
    func clamshellControl() throws {
        var events: [String] = []
        let control = LidSleepControl(calls: LidSleepCalls(find: { events.append("find"); return 8 }, open: {
            #expect($0 == 8)
            $1.pointee = 9
            events.append("open")
            return 0
        }, call: { connection, selector, input in
            #expect(connection == 9)
            #expect(selector == 12)
            events.append("call:\(input)")
            return 0
        }, close: { #expect($0 == 9); events.append("close"); return 0 }, release: {
            #expect($0 == 8)
            events.append("release")
        }))
        try control.setLidSleepDisabled(true)
        try control.setLidSleepDisabled(true)
        try control.setLidSleepDisabled(false)
        #expect(events == [
            "find", "open", "call:1", "close", "release",
            "find", "open", "call:1", "close", "release",
            "find", "open", "call:0", "close", "release",
        ])
    }

    @Test("SPEC-BLK-007 蓋制御の失敗でも獲得した資源だけを片付け、再試行する")
    func clamshellFailureCleanup() throws {
        var events: [String] = []
        var findResult: UInt32 = 8
        var openResult: Int32 = -1
        var callResult: Int32 = -2
        var closeResult: Int32 = 0
        let control = LidSleepControl(calls: LidSleepCalls(find: { findResult }, open: { _, connection in
            events.append("open")
            connection.pointee = 9
            return openResult
        }, call: { _, _, _ in events.append("call"); return callResult }, close: { _ in
            events.append("close")
            return closeResult
        }, release: { _ in events.append("release") }))
        #expect(throws: PowerPlatformError.ioKit(operation: "IOServiceOpen", code: -1)) {
            try control.setLidSleepDisabled(true)
        }
        #expect(events == ["open", "release"])
        events = []
        openResult = 0
        #expect(throws: PowerPlatformError.ioKit(operation: "kPMSetClamshellSleepState", code: -2)) {
            try control.setLidSleepDisabled(true)
        }
        #expect(events == ["open", "call", "close", "release"])
        events = []
        callResult = 0
        closeResult = -3
        #expect(throws: PowerPlatformError.ioKit(operation: "IOServiceClose", code: -3)) {
            try control.setLidSleepDisabled(false)
        }
        #expect(events == ["open", "call", "close", "release"])
        events = []
        closeResult = 0
        try control.setLidSleepDisabled(false)
        #expect(events == ["open", "call", "close", "release"])
        events = []
        findResult = 0
        #expect(throws: PowerPlatformError.unavailable("IOPMrootDomain")) {
            try control.setLidSleepDisabled(false)
        }
        #expect(events.isEmpty)
    }
}

@MainActor
private final class AssertionServer {
    var types: [String] = []
    var names: [String] = []
    var released: [UInt32] = []
    var createResult: Int32 = 0
    var releaseResult: Int32 = 0

    func makeAssertions() -> PowerAssertions {
        PowerAssertions(create: { type, name, identifier in
            self.types.append(type as String)
            self.names.append(name as String)
            identifier.pointee = UInt32(self.types.count)
            return self.createResult
        }, release: { identifier in
            self.released.append(identifier)
            return self.releaseResult
        })
    }
}
