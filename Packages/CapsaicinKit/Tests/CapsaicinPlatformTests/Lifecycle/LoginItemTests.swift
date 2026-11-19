@testable import CapsaicinPlatform
import ServiceManagement
import Testing

@MainActor
struct LoginItemTests {
    @Test("SPEC-LCY-001 ログイン時の起動は必要なときだけ登録・登録解除する",
          arguments: [SMAppService.Status.notRegistered, .notFound, .requiresApproval, .enabled], [false, true])
    func loginReconciliation(status: SMAppService.Status, enabled: Bool) throws {
        var calls: [Bool] = []
        try LoginItem.update(
            enabled,
            status: status,
            register: { calls.append(true) },
            unregister: { calls.append(false) },
        )
        let registered = status == .requiresApproval || status == .enabled
        #expect(calls == (registered == enabled ? [] : [enabled]))
    }

    @Test("SPEC-LCY-001 登録と登録解除の失敗は呼び出し元に返す", arguments: [false, true])
    func loginFailure(enabled: Bool) {
        struct Failure: Error {}
        #expect(throws: Failure.self) {
            try LoginItem.update(enabled, status: enabled ? .notRegistered : .enabled,
                                 register: { throw Failure() }, unregister: { throw Failure() })
        }
    }
}
