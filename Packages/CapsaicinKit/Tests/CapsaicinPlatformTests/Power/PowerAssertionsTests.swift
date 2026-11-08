import CapsaicinCore
@testable import CapsaicinPlatform
import Foundation
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
