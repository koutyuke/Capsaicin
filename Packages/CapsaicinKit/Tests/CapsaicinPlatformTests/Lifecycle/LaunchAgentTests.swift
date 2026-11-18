@testable import CapsaicinPlatform
import Darwin
import Foundation
import ServiceManagement
import Testing

@MainActor
struct LaunchAgentTests {
    @Test("SPEC-LCY-005 登録と版の保存の後、kickstart だけで引き渡す")
    func registration() async {
        let fixture = LaunchAgentFixture()
        fixture.status = .notRegistered
        #expect(await fixture.agent().registerAndStart() == .ready)
        #expect(fixture.calls == ["register", "save:2", "kickstart"])
        #expect(fixture.commands == [["kickstart", "gui/501/\(fixture.label)"]])
        #expect(fixture.savedVersion == "2")
    }

    @Test("SPEC-LCY-005 同じ版なら登録を外さず、登録済みのエラーでも引き渡す")
    func alreadyRegistered() async {
        let fixture = LaunchAgentFixture()
        fixture.savedVersion = "2"
        fixture.errors = [NSError(domain: SMAppServiceErrorDomain, code: Int(kSMErrorAlreadyRegistered))]
        #expect(await fixture.agent().registerAndStart() == .ready)
        #expect(fixture.calls == ["register", "save:2", "kickstart"])
    }

    @Test("SPEC-LCY-005 登録と起動の失敗を区別し、登録失敗では引き渡さない", arguments: [false, true])
    func failure(launch: Bool) async {
        let fixture = LaunchAgentFixture()
        fixture.status = .notRegistered
        if launch {
            fixture.launchError = true
        } else {
            fixture.errors = [NSError(domain: NSPOSIXErrorDomain, code: Int(EIO))]
        }
        #expect(await fixture.agent().registerAndStart() == (launch ? .launchFailed : .registrationFailed))
        #expect(fixture.commands.count == (launch ? 1 : 0))
        #expect(fixture.savedVersion == (launch ? "2" : nil))
    }

    @Test("SPEC-LCY-005 agent の status で再起動の有効・無効を決める", arguments: [
        (SMAppService.Status.enabled, LaunchAgentStatus.ready),
        (.requiresApproval, .disabled),
        (.notRegistered, .registrationFailed),
        (.notFound, .registrationFailed),
    ])
    func authorization(status: SMAppService.Status, expected: LaunchAgentStatus) {
        let fixture = LaunchAgentFixture()
        fixture.status = status
        #expect(fixture.agent().restartStatus() == expected)
        #expect(fixture.calls.isEmpty)
    }

    @Test("SPEC-LCY-005 初めての登録で承認待ちになったら直接起動を続ける", arguments: [false, true])
    func firstApproval(throwsPermission: Bool) async {
        let fixture = LaunchAgentFixture()
        fixture.status = .notRegistered
        fixture.statusAfterRegister = .requiresApproval
        if throwsPermission {
            fixture.errorAfterRegister = NSError(domain: SMAppServiceErrorDomain, code: Int(EPERM))
        }
        #expect(await fixture.agent().registerAndStart() == .disabled)
        #expect(fixture.calls == ["register", "save:2"])
        #expect(fixture.commands.isEmpty)
    }

    @Test("SPEC-LCY-005 同じ版で承認待ちなら登録を触らず、起動も要求しない")
    func disabled() async {
        let fixture = LaunchAgentFixture()
        fixture.status = .requiresApproval
        fixture.savedVersion = "2"
        #expect(await fixture.agent().registerAndStart() == .disabled)
        #expect(fixture.calls.isEmpty)
    }

    @Test("SPEC-HLP-007 SPEC-LCY-005 前の版か未記録なら unregister の完了を待ってから登録する",
          arguments: [nil, "1"] as [String?])
    func versionUpdate(previous: String?) async {
        let fixture = LaunchAgentFixture()
        fixture.savedVersion = previous
        #expect(await fixture.agent().registerAndStart() == .ready)
        #expect(fixture.calls == ["unregister-start", "unregister-end", "register", "save:2", "kickstart"])
    }

    @Test("SPEC-HLP-007 SPEC-LCY-005 EPERM は3秒待って最大3回再試行する", arguments: [0, 1, 2])
    func retries(form: Int) async {
        let fixture = LaunchAgentFixture()
        let posix = NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))
        let error = switch form {
        case 0: posix
        case 1: NSError(domain: SMAppServiceErrorDomain, code: Int(EPERM))
        default: NSError(domain: "wrapper", code: 99, userInfo: [NSUnderlyingErrorKey: posix])
        }
        fixture.errors = [error, error, error]
        #expect(await fixture.agent().registerAndStart() == .ready)
        #expect(fixture.calls == [
            "unregister-start", "unregister-end", "register", "wait", "register", "wait", "register", "wait",
            "register", "save:2", "kickstart",
        ])
    }

    @Test("SPEC-HLP-007 SPEC-LCY-005 再試行の上限と EPERM 以外の失敗では版を更新しない", arguments: [false, true])
    func retryLimit(permission: Bool) async {
        let fixture = LaunchAgentFixture()
        fixture.savedVersion = "1"
        fixture.errors = Array(repeating: NSError(domain: NSPOSIXErrorDomain,
                                                  code: Int(permission ? EPERM : EIO)), count: 4)
        #expect(await fixture.agent().registerAndStart() == .registrationFailed)
        #expect(fixture.calls.filter { $0 == "register" }.count == (permission ? 4 : 1))
        #expect(fixture.calls.filter { $0 == "wait" }.count == (permission ? 3 : 0))
        #expect(fixture.savedVersion == "1")
        #expect(fixture.commands.isEmpty)
    }

    @Test("SPEC-HLP-007 SPEC-LCY-005 承認待ちでも版を更新し、EPERM を繰り返さない", arguments: [false, true])
    func approvalUpdate(throwsPermission: Bool) async {
        let fixture = LaunchAgentFixture()
        fixture.status = .requiresApproval
        fixture.statusAfterRegister = .requiresApproval
        if throwsPermission {
            fixture.errorAfterRegister = NSError(domain: SMAppServiceErrorDomain, code: Int(EPERM))
        }
        #expect(await fixture.agent().registerAndStart() == .disabled)
        #expect(fixture.calls == ["unregister-start", "unregister-end", "register", "save:2"])
    }

    @Test("SPEC-HLP-007 SPEC-LCY-005 承認待ちになっても EPERM 以外の登録失敗では版を保存しない",
          arguments: [SMAppService.Status.notRegistered, .requiresApproval])
    func approvalFailure(initial: SMAppService.Status) async {
        let fixture = LaunchAgentFixture()
        fixture.status = initial
        fixture.statusAfterRegister = .requiresApproval
        fixture.errorAfterRegister = NSError(domain: NSPOSIXErrorDomain, code: Int(EIO))
        #expect(await fixture.agent().registerAndStart() == .disabled)
        #expect(fixture.savedVersion == nil)
        #expect(fixture.commands.isEmpty)
        #expect(!fixture.calls.contains("wait"))
    }

    @Test("SPEC-HLP-007 SPEC-LCY-005 unregister 失敗後は登録しない")
    func unregisterFailure() async {
        let fixture = LaunchAgentFixture()
        fixture.savedVersion = "1"
        fixture.unregisterError = true
        #expect(await fixture.agent().registerAndStart() == .registrationFailed)
        #expect(fixture.calls == ["unregister-start"])
        #expect(fixture.savedVersion == "1")
    }

    @Test("SPEC-HLP-007 SPEC-LCY-005 待機の取り消し後は登録を繰り返さない")
    func cancelledWait() async {
        let fixture = LaunchAgentFixture()
        fixture.errors = [NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))]
        fixture.cancelWait = true
        #expect(await fixture.agent().registerAndStart() == .registrationFailed)
        #expect(fixture.calls == ["unregister-start", "unregister-end", "register", "wait"])
        #expect(fixture.savedVersion == nil)
    }

    @Test("SPEC-LCY-001 mainApp だけを保存値に合わせ、整合済みなら操作しない", arguments: [
        SMAppService.Status.notRegistered, .notFound, .enabled, .requiresApproval,
    ], [false, true])
    func loginReconciliation(status: SMAppService.Status, enabled: Bool) throws {
        let fixture = LaunchAgentFixture()
        fixture.loginStatus = status
        let registered = status == .enabled || status == .requiresApproval
        try fixture.agent().updateLaunchAtLogin(enabled)
        #expect(fixture.calls == (registered == enabled ? [] : [enabled ? "login-register" : "login-unregister"]))
        #expect(fixture.commands.isEmpty)
        #expect(fixture.savedVersion == nil)
    }

    @Test("SPEC-LCY-001 mainApp の登録・解除のエラーを呼び出し元に返す", arguments: [false, true])
    func loginFailure(enabled: Bool) {
        let fixture = LaunchAgentFixture()
        fixture.loginStatus = enabled ? .notRegistered : .enabled
        fixture.loginError = true
        #expect(throws: (any Error).self) { try fixture.agent().updateLaunchAtLogin(enabled) }
        #expect(fixture.commands.isEmpty)
    }

    @Test("SPEC-LCY-005 XPC_SERVICE_NAME が自分のラベルと一致するときだけ launchd 由来とする")
    func launchOrigin() {
        let agent = LaunchAgentFixture().agent()
        #expect(agent.wasLaunchedByLaunchd(environment: ["XPC_SERVICE_NAME": agent.label]))
        #expect(!agent.wasLaunchedByLaunchd(environment: [:]))
        #expect(!agent.wasLaunchedByLaunchd(environment: ["XPC_SERVICE_NAME": ""]))
        #expect(!agent.wasLaunchedByLaunchd(environment: ["XPC_SERVICE_NAME": "io.github.koutyuke.capsaicin"]))
        #expect(!agent.wasLaunchedByLaunchd(environment: ["XPC_SERVICE_NAME": agent.label + ".other"]))
    }
}

@MainActor
private final class LaunchAgentFixture {
    let label = "io.github.koutyuke.capsaicin.debug"
    var status = SMAppService.Status.enabled
    var statusAfterRegister = SMAppService.Status.enabled
    var loginStatus = SMAppService.Status.notRegistered
    var savedVersion: String?
    var calls: [String] = []
    var commands: [[String]] = []
    var errors: [NSError] = []
    var errorAfterRegister: NSError?
    var unregisterError = false
    var launchError = false
    var loginError = false
    var cancelWait = false

    func agent() -> LaunchAgent {
        LaunchAgent(label: label, uid: 501, status: { self.status }, register: {
            self.calls.append("register")
            if !self.errors.isEmpty {
                throw self.errors.removeFirst()
            }
            self.status = self.statusAfterRegister
            if let error = self.errorAfterRegister {
                throw error
            }
        }, unregister: {
            self.calls.append("unregister-start")
            await Task.yield()
            if self.unregisterError {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(EIO))
            }
            self.status = .notRegistered
            self.calls.append("unregister-end")
        }, loginStatus: { self.loginStatus }, registerLogin: {
            self.calls.append("login-register")
            if self.loginError {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(EIO))
            }
        }, unregisterLogin: {
            self.calls.append("login-unregister")
            if self.loginError {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(EIO))
            }
        }, version: "2", registeredVersion: { self.savedVersion }, saveVersion: {
            self.calls.append("save:\($0)")
            self.savedVersion = $0
        }, runLaunchctl: {
            self.commands.append($0)
            self.calls.append("kickstart")
            if self.launchError {
                throw CommandRunnerError.unsuccessfulExit(1)
            }
        }, wait: {
            #expect($0 == .seconds(3))
            self.calls.append("wait")
            if self.cancelWait {
                throw CancellationError()
            }
        })
    }
}
