@testable import CapsaicinPlatform
import Darwin
import Foundation
import ServiceManagement
import Testing

@MainActor
struct HelperRegistrationTests {
    @Test("SPEC-HLP-004 SMAppService と Team ID から4状態を決める", arguments: [
        SMAppService.Status.notRegistered, .notFound, .enabled, .requiresApproval,
    ], [false, true])
    func states(status: SMAppService.Status, signed: Bool) {
        let fixture = RegistrationFixture()
        fixture.status = status
        fixture.team = signed ? "TEAM" : nil
        let expected: HelperInstallationState = !signed ? .unavailable :
            status == .enabled ? .installed : status == .requiresApproval ? .requiresApproval : .notInstalled
        #expect(fixture.registration().state == expected)
        #expect(fixture.calls.isEmpty)
    }

    @Test("SPEC-HLP-001 ad-hoc と App Translocation からは登録しない", arguments: [false, true])
    func registrationGuards(translocated: Bool) {
        let fixture = RegistrationFixture()
        if translocated {
            fixture.url = URL(filePath: "/private/var/AppTranslocation/token/d/Capsaicin.app")
        } else {
            fixture.team = nil
        }
        let registration = fixture.registration()
        #expect(registration.isTranslocated == translocated)
        #expect(throws: (any Error).self) { try registration.register() }
        #expect(fixture.calls.isEmpty)
        #expect(fixture.savedVersion == nil)
    }

    @Test("SPEC-HLP-007 承認待ちでも版を更新し、登録し直しでは設定を開かない")
    func approvalUpdate() async {
        let fixture = RegistrationFixture()
        fixture.status = .requiresApproval
        fixture.statusAfterRegister = .requiresApproval
        #expect(await fixture.registration().reregisterIfNeeded() == .requiresApproval)
        #expect(fixture.calls == ["unregister-start", "unregister-end", "register", "save:2"])
    }

    @Test("SPEC-HLP-007 再試行の待機が取り消されたら次の登録は行わない")
    func cancelledWait() async {
        var calls: [String] = []
        let registration = HelperRegistration(status: { .enabled }, register: {
            calls.append("register")
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))
        }, unregister: { calls.append("unregister") }, teamIdentifier: { "TEAM" },
        bundleURL: URL(filePath: "/Applications/Capsaicin.app"), version: "2",
        registeredVersion: { "1" },
        saveVersion: { _ in Issue.record("失敗した版を保存した") },
        wait: { _ in throw CancellationError() })
        #expect(await registration.reregisterIfNeeded() == .installed)
        #expect(calls == ["unregister", "register"])
    }

    @Test("SPEC-HLP-001 SPEC-HLP-007 登録の成功時だけ版を保存し、使える場合も承認待ちの場合もシステム設定を開かない",
          arguments: [SMAppService.Status.enabled, .requiresApproval])
    func registration(statusAfterRegister: SMAppService.Status) throws {
        let fixture = RegistrationFixture()
        fixture.status = .notRegistered
        fixture.statusAfterRegister = statusAfterRegister
        let registration = fixture.registration()
        try registration.register()
        #expect(fixture.calls == ["register", "save:2"])
        #expect(fixture.savedVersion == "2")
        fixture.calls = []
        registration.openSystemSettings()
        #expect(fixture.calls == ["settings"])
        fixture.status = .notRegistered
        fixture.errors = [NSError(domain: NSPOSIXErrorDomain, code: Int(EIO))]
        fixture.savedVersion = "1"
        #expect(throws: (any Error).self) { try registration.register() }
        #expect(fixture.savedVersion == "1")
    }

    @Test("SPEC-HLP-001 初めての登録の EPERM は承認待ちとして扱い、システム設定を開かない")
    func firstRegistrationRequiresApproval() throws {
        let fixture = RegistrationFixture()
        fixture.status = .notRegistered
        fixture.statusAfterRegister = .requiresApproval
        fixture.errorsAfterRegistering = [NSError(domain: SMAppServiceErrorDomain, code: Int(EPERM))]
        try fixture.registration().register()
        #expect(fixture.calls == ["register", "save:2"])
        fixture.status = .notRegistered
        fixture.statusAfterRegister = .notRegistered
        fixture.errorsAfterRegistering = [NSError(domain: SMAppServiceErrorDomain, code: Int(EPERM))]
        fixture.savedVersion = "1"
        #expect(throws: (any Error).self) { try fixture.registration().register() }
        #expect(fixture.savedVersion == "1")
    }

    @Test("SPEC-HLP-007 承認待ちのまま EPERM なら試し直さずに版を更新する")
    func approvalUpdateWithPermissionError() async {
        let fixture = RegistrationFixture()
        fixture.status = .requiresApproval
        fixture.statusAfterRegister = .requiresApproval
        fixture.errorsAfterRegistering = [NSError(domain: SMAppServiceErrorDomain, code: Int(EPERM))]
        #expect(await fixture.registration().reregisterIfNeeded() == .requiresApproval)
        #expect(fixture.calls == ["unregister-start", "unregister-end", "register", "save:2"])
    }

    @Test("SPEC-HLP-007 unregister の完了後に登録し、EPERM だけ3秒待って試し直す", arguments: [0, 1, 2])
    func retries(errorForm: Int) async {
        let fixture = RegistrationFixture()
        let posix = NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))
        let error = switch errorForm {
        case 0: posix
        case 1: NSError(domain: SMAppServiceErrorDomain, code: Int(EPERM))
        default: NSError(domain: "wrapper", code: 99, userInfo: [NSUnderlyingErrorKey: posix])
        }
        fixture.savedVersion = "1"
        fixture.errors = [error, error, error]
        #expect(await fixture.registration().reregisterIfNeeded() == .installed)
        #expect(fixture.calls == [
            "unregister-start", "unregister-end", "register", "wait", "register", "wait", "register", "wait",
            "register", "save:2",
        ])
        #expect(fixture.savedVersion == "2")
    }

    @Test("SPEC-HLP-007 3回の再試行で止め、失敗した版を保存しない", arguments: [false, true])
    func retryLimit(permissionError: Bool) async {
        let fixture = RegistrationFixture()
        fixture.savedVersion = "1"
        fixture.errors = Array(repeating: NSError(domain: NSPOSIXErrorDomain,
                                                  code: Int(permissionError ? EPERM : EIO)), count: 4)
        #expect(await fixture.registration().reregisterIfNeeded() == .notInstalled)
        #expect(fixture.calls.filter { $0 == "register" }.count == (permissionError ? 4 : 1))
        #expect(fixture.calls.filter { $0 == "wait" }.count == (permissionError ? 3 : 0))
        #expect(fixture.savedVersion == "1")
    }

    @Test("SPEC-HLP-007 同じ版、未登録、ad-hoc では登録し直さない", arguments: [0, 1, 2])
    func noUpdate(reason: Int) async {
        let fixture = RegistrationFixture()
        if reason == 0 {
            fixture.savedVersion = "2"
        }
        if reason == 1 {
            fixture.status = .notRegistered
        }
        if reason == 2 {
            fixture.team = nil
        }
        let registration = fixture.registration()
        #expect(await registration.reregisterIfNeeded() == registration.state)
        #expect(fixture.calls.isEmpty)
    }

    @Test("SPEC-HLP-007 unregister の失敗後は register せず、状態を読み直す")
    func unregisterFailure() async {
        let fixture = RegistrationFixture()
        fixture.unregisterError = NSError(domain: NSPOSIXErrorDomain, code: Int(EIO))
        fixture.status = .requiresApproval
        #expect(await fixture.registration().reregisterIfNeeded() == .requiresApproval)
        #expect(fixture.calls == ["unregister-start"])
        #expect(fixture.savedVersion == nil)
    }

    @Test("SPEC-HLP-004 登録を外した後にだけ版の記録も外す")
    func removal() async throws {
        let fixture = RegistrationFixture()
        fixture.savedVersion = "2"
        try await fixture.registration().unregister()
        #expect(fixture.calls == ["unregister-start", "unregister-end", "save:nil"])
        #expect(fixture.savedVersion == nil)
        fixture.savedVersion = "2"
        fixture.unregisterError = NSError(domain: NSPOSIXErrorDomain, code: Int(EIO))
        await #expect(throws: (any Error).self) { try await fixture.registration().unregister() }
        #expect(fixture.savedVersion == "2")
    }
}

@MainActor
private final class RegistrationFixture {
    var status = SMAppService.Status.enabled
    var statusAfterRegister = SMAppService.Status.enabled
    var team: String? = "TEAM"
    var url = URL(filePath: "/Applications/Capsaicin.app")
    var savedVersion: String?
    var calls: [String] = []
    var errors: [NSError] = []
    /// 状態を statusAfterRegister に変えてから投げる。初めての登録の EPERM をまねる。
    var errorsAfterRegistering: [NSError] = []
    var unregisterError: NSError?

    func registration() -> HelperRegistration {
        HelperRegistration(status: { self.status }, register: {
            self.calls.append("register")
            if !self.errors.isEmpty {
                throw self.errors.removeFirst()
            }
            self.status = self.statusAfterRegister
            if !self.errorsAfterRegistering.isEmpty {
                throw self.errorsAfterRegistering.removeFirst()
            }
        }, unregister: {
            self.calls.append("unregister-start")
            await Task.yield()
            if let error = self.unregisterError {
                throw error
            }
            self.status = .notRegistered
            self.calls.append("unregister-end")
        }, openSettings: { self.calls.append("settings") }, teamIdentifier: { self.team },
        bundleURL: url, version: "2", registeredVersion: { self.savedVersion }, saveVersion: {
            self.calls.append("save:" + ($0 ?? "nil"))
            self.savedVersion = $0
        }, wait: {
            #expect($0 == .seconds(3))
            self.calls.append("wait")
        })
    }
}
