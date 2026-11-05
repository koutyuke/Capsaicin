import CapsaicinCore
@testable import CapsaicinPlatform
import Foundation
import IOKit.pwr_mgt
import Testing

@MainActor
struct PowerPlatformAssertionsTests {
    @Test("SPEC-BLK-007 解放の応答だけ失ったときは保持していると偽って成功しない")
    func lostReleaseResponse() throws {
        let fake = AssertionServer()
        fake.releaseResult = -2
        var assertions: PowerAssertions? = fake.makeAssertions()
        try assertions?.createAssertion(.preventUserIdleSystemSleep)
        #expect(throws: PowerPlatformError.ioKit(operation: "IOPMAssertionRelease", code: -2)) {
            try assertions?.releaseAssertion(.preventUserIdleSystemSleep)
        }
        #expect(fake.live.isEmpty)
        for _ in 0 ..< 2 {
            #expect(throws: (any Error).self) {
                try assertions?.createAssertion(.preventUserIdleSystemSleep)
            }
            #expect(throws: (any Error).self) {
                try assertions?.releaseAssertion(.preventUserIdleSystemSleep)
            }
        }
        assertions = nil
        #expect(fake.creates == 1)
        #expect(fake.released == [1])
        #expect(fake.queried == [1, 1, 1, 1, 1])
    }

    @Test("SPEC-BLK-001 / SPEC-BLK-007 種類ごとに所有し、作成・解放は冪等")
    func assertionOwnership() throws {
        let fake = AssertionServer()
        let assertions = fake.makeAssertions()
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        try assertions.createAssertion(.preventUserIdleDisplaySleep)
        #expect(fake.types == ["PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep"])
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        try assertions.releaseAssertion(.preventUserIdleDisplaySleep)
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        let other = fake.makeAssertions()
        try other.createAssertion(.preventUserIdleSystemSleep)
        #expect(fake.names.allSatisfy {
            $0.hasPrefix("Capsaicin — PreventUserIdle") && $0.utf16.count < 128 &&
                UUID(uuidString: String($0.suffix(36))) != nil
        })
        #expect(Set(fake.names).count == 4)
        #expect(zip(fake.names, fake.types).allSatisfy { $0.contains($1) })
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        try other.releaseAssertion(.preventUserIdleSystemSleep)
        #expect(fake.released == [1, 2, 3, 4])
        #expect(fake.live.isEmpty)
        #expect(fake.queried.isEmpty)
    }

    @Test("SPEC-BLK-007 解放失敗でも所有と On を確認できれば同じアサーションを引き継ぐ")
    func failureAndRetry() throws {
        let fake = AssertionServer()
        fake.releaseResult = -2
        fake.removesOnRelease = false
        let assertions = fake.makeAssertions()
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        #expect(throws: PowerPlatformError.ioKit(operation: "IOPMAssertionRelease", code: -2)) {
            try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        }
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        #expect(fake.creates == 1)
        #expect(fake.queried == [1])
        #expect(fake.live.count == 1)
        fake.releaseResult = 0
        fake.removesOnRelease = true
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        #expect(fake.released == [1, 1])
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        #expect(fake.creates == 2)
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
    }

    @Test("SPEC-BLK-007 解放再試行は所有確認して行い、失敗後も不明のままにする")
    func verifiedReleaseRetry() throws {
        let fake = AssertionServer()
        fake.releaseResult = -2
        fake.removesOnRelease = false
        let assertions = fake.makeAssertions()
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        for _ in 0 ..< 2 {
            #expect(throws: PowerPlatformError.ioKit(operation: "IOPMAssertionRelease", code: -2)) {
                try assertions.releaseAssertion(.preventUserIdleSystemSleep)
            }
        }
        fake.releaseResult = 0
        fake.removesOnRelease = true
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        #expect(fake.released == [1, 1, 1])
        #expect(fake.queried == [1, 1])
        #expect(fake.live.isEmpty)
    }

    @Test("SPEC-BLK-007 読めない・壊れた・再利用された ID は採用も解放もしない", arguments: [
        "nil", "error", "empty", "missingName", "missingType", "nameNumber", "typeNumber", "reusedName", "wrongType",
    ])
    func unreadableOwnership(problem: String) throws {
        let fake = AssertionServer()
        fake.releaseResult = -2
        fake.removesOnRelease = false
        var assertions: PowerAssertions? = fake.makeAssertions()
        try assertions?.createAssertion(.preventUserIdleSystemSleep)
        #expect(throws: (any Error).self) { try assertions?.releaseAssertion(.preventUserIdleSystemSleep) }
        switch problem {
        case "nil": fake.queryOverride = { _ in nil }
        case "error": fake.queryOverride = { _ in throw PowerPlatformError.unavailable("fake query") }
        case "empty": fake.live[1] = [:]
        case "missingName": fake.live[1]?.removeValue(forKey: kIOPMAssertionNameKey)
        case "missingType": fake.live[1]?.removeValue(forKey: kIOPMAssertionTypeKey)
        case "nameNumber": fake.live[1]?[kIOPMAssertionNameKey] = 1
        case "typeNumber": fake.live[1]?[kIOPMAssertionTypeKey] = 1
        case "reusedName":
            fake.live[1]?[kIOPMAssertionNameKey] = "Capsaicin — PreventUserIdleSystemSleep — \(UUID().uuidString)"
        default: fake.live[1]?[kIOPMAssertionTypeKey] = kIOPMAssertionTypePreventUserIdleDisplaySleep
        }
        #expect(throws: (any Error).self) { try assertions?.createAssertion(.preventUserIdleSystemSleep) }
        #expect(throws: (any Error).self) { try assertions?.releaseAssertion(.preventUserIdleSystemSleep) }
        assertions = nil
        #expect(fake.creates == 1)
        #expect(fake.released == [1])
        #expect(fake.queried == [1, 1, 1])
        #expect(fake.live.count == 1)
    }

    @Test("SPEC-BLK-007 一時的な照会失敗の後も所有の肯定的な証拠で復旧できる", arguments: [false, true])
    func temporaryQueryFailure(recoverByRelease: Bool) throws {
        let fake = AssertionServer()
        fake.releaseResult = -2
        fake.removesOnRelease = false
        let assertions = fake.makeAssertions()
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        #expect(throws: (any Error).self) { try assertions.releaseAssertion(.preventUserIdleSystemSleep) }
        fake.queryOverride = { _ in nil }
        #expect(throws: (any Error).self) { try assertions.createAssertion(.preventUserIdleSystemSleep) }
        fake.queryOverride = { _ in throw PowerPlatformError.unavailable("fake query") }
        #expect(throws: (any Error).self) { try assertions.releaseAssertion(.preventUserIdleSystemSleep) }
        fake.queryOverride = nil
        fake.releaseResult = 0
        fake.removesOnRelease = true
        if !recoverByRelease {
            try assertions.createAssertion(.preventUserIdleSystemSleep)
        }
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        #expect(fake.creates == 1)
        #expect(fake.released == [1, 1])
        #expect(fake.queried == [1, 1, 1])
        #expect(fake.live.isEmpty)
    }

    @Test("SPEC-BLK-007 On の数値だけが作成の成功で、同じ所有なら Off でも解放できる", arguments: [
        "off", "missing", "boolean", "string", "fraction", "otherNumber", "overflow", "maximum",
    ])
    func inactiveOrMalformedLevel(level: String) throws {
        let fake = AssertionServer()
        fake.releaseResult = -2
        fake.removesOnRelease = false
        let assertions = fake.makeAssertions()
        try assertions.createAssertion(.preventUserIdleSystemSleep)
        #expect(throws: (any Error).self) { try assertions.releaseAssertion(.preventUserIdleSystemSleep) }
        let value: Any? = switch level {
        case "off": 0
        case "boolean": true
        case "string": "1"
        case "fraction": 1.5
        case "otherNumber": 2
        case "overflow": UInt64(UInt32.max) + 1 + UInt64(kIOPMAssertionLevelOn)
        case "maximum": UInt64.max
        default: nil
        }
        fake.live[1]?[kIOPMAssertionLevelKey] = value
        #expect(throws: (any Error).self) { try assertions.createAssertion(.preventUserIdleSystemSleep) }
        #expect(fake.creates == 1)
        fake.releaseResult = 0
        fake.removesOnRelease = true
        try assertions.releaseAssertion(.preventUserIdleSystemSleep)
        #expect(fake.released == [1, 1])
        #expect(fake.queried == [1, 1])
        #expect(fake.live.isEmpty)
    }

    @Test("SPEC-BLK-007 作成失敗は副作用や出力 ID の有無にかかわらず不明を保つ",
          arguments: [false, true], [false, true])
    func uncertainCreateFailure(physicallyCreated: Bool, writesIdentifier: Bool) throws {
        let fake = AssertionServer()
        fake.createResult = -1
        fake.createsPhysically = physicallyCreated
        fake.writesIdentifier = writesIdentifier
        var assertions: PowerAssertions? = fake.makeAssertions()
        #expect(throws: PowerPlatformError.ioKit(operation: "IOPMAssertionCreateWithName", code: -1)) {
            try assertions?.createAssertion(.preventUserIdleSystemSleep)
        }
        fake.createResult = 0
        for _ in 0 ..< 2 {
            #expect(throws: (any Error).self) { try assertions?.createAssertion(.preventUserIdleSystemSleep) }
            #expect(throws: (any Error).self) { try assertions?.releaseAssertion(.preventUserIdleSystemSleep) }
        }
        assertions = nil
        #expect(fake.creates == 1)
        #expect(fake.released.isEmpty)
        #expect(fake.queried.isEmpty)
        #expect(fake.live.count == (physicallyCreated ? 1 : 0))
    }

    @Test("SPEC-BLK-001 / SPEC-BLK-007 片方の不明状態は別の種類を妨げない")
    func independentKindsAfterFailure() throws {
        let fake = AssertionServer()
        fake.createResult = -1
        let assertions = fake.makeAssertions()
        #expect(throws: (any Error).self) { try assertions.createAssertion(.preventUserIdleSystemSleep) }
        fake.createResult = 0
        try assertions.createAssertion(.preventUserIdleDisplaySleep)
        try assertions.createAssertion(.preventUserIdleDisplaySleep)
        try assertions.releaseAssertion(.preventUserIdleDisplaySleep)
        #expect(throws: (any Error).self) { try assertions.createAssertion(.preventUserIdleSystemSleep) }
        #expect(fake.creates == 2)
        #expect(fake.released == [2])
        #expect(fake.live.keys.sorted() == [1])
    }
}

extension PowerPlatformAssertionsTests {
    @Test("SPEC-LCY-006 破棄時の解放失敗は再試行しない", arguments: [false, true], [false, true])
    func destructionFailureDoesNotRetry(unknown: Bool, physicallyRemoved: Bool) throws {
        let fake = AssertionServer()
        fake.releaseResult = -2
        fake.removesOnRelease = false
        var assertions: PowerAssertions? = fake.makeAssertions()
        try assertions?.createAssertion(.preventUserIdleSystemSleep)
        if unknown {
            #expect(throws: (any Error).self) { try assertions?.releaseAssertion(.preventUserIdleSystemSleep) }
        }
        fake.removesOnRelease = physicallyRemoved
        weak var released = assertions
        assertions = nil
        #expect(released == nil)
        #expect(fake.released == (unknown ? [1, 1] : [1]))
        #expect(fake.queried == (unknown ? [1] : []))
        #expect(fake.live.isEmpty == physicallyRemoved)
    }

    @Test("SPEC-LCY-006 所有インスタンスの破棄で未解放のアサーションを解放")
    func destructionReleasesOwnedIDs() throws {
        let fake = AssertionServer()
        var assertions: PowerAssertions? = fake.makeAssertions()
        try assertions?.createAssertion(.preventUserIdleSystemSleep)
        assertions = nil
        #expect(fake.released == [1])
        #expect(fake.queried.isEmpty)
        #expect(fake.live.isEmpty)
    }

    @Test("SPEC-LCY-006 不明なアサーションは所有を照合できたときだけ破棄時に解放", arguments: [0, 1])
    func destructionVerifiesUnknownIdentity(level: Int) throws {
        let fake = AssertionServer()
        fake.releaseResult = -2
        fake.removesOnRelease = false
        var assertions: PowerAssertions? = fake.makeAssertions()
        try assertions?.createAssertion(.preventUserIdleSystemSleep)
        #expect(throws: (any Error).self) { try assertions?.releaseAssertion(.preventUserIdleSystemSleep) }
        fake.live[1]?[kIOPMAssertionLevelKey] = level
        fake.releaseResult = 0
        fake.removesOnRelease = true
        assertions = nil
        #expect(fake.released == [1, 1])
        #expect(fake.queried == [1])
        #expect(fake.live.isEmpty)
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

/// サーバー側の効果と、呼び出し元に届く応答を独立に変えられる偽物。
@MainActor
private final class AssertionServer {
    var live: [UInt32: [String: Any]] = [:]
    var creates = 0
    var types: [String] = []
    var names: [String] = []
    var released: [UInt32] = []
    var queried: [UInt32] = []
    var createResult: Int32 = 0
    var releaseResult: Int32 = 0
    var createsPhysically = true
    var writesIdentifier = true
    var removesOnRelease = true
    var queryOverride: ((UInt32) throws -> CFDictionary?)?

    func makeAssertions() -> PowerAssertions {
        PowerAssertions(create: { type, name, identifier in
            self.creates += 1
            let newIdentifier = UInt32(self.creates)
            self.types.append(type as String)
            self.names.append(name as String)
            if self.writesIdentifier {
                identifier.pointee = newIdentifier
            }
            if self.createsPhysically {
                self.live[newIdentifier] = [
                    kIOPMAssertionNameKey: name as String,
                    kIOPMAssertionTypeKey: type as String,
                    kIOPMAssertionLevelKey: kIOPMAssertionLevelOn,
                ]
            }
            return self.createResult
        }, release: { identifier in
            self.released.append(identifier)
            if self.removesOnRelease {
                self.live.removeValue(forKey: identifier)
            }
            return self.releaseResult
        }, copyProperties: { identifier in
            self.queried.append(identifier)
            if let queryOverride = self.queryOverride {
                return try queryOverride(identifier)
            }
            return self.live[identifier].map { $0 as CFDictionary }
        })
    }
}
