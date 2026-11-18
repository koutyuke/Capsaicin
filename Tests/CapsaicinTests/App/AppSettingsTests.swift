import CapsaicinCore
import CapsaicinCoreTesting
@testable import CapsaicinPlatform
import Foundation
import ServiceManagement
import Testing

@MainActor
struct AppSettingsTests {
    @Test("SPEC-HLP-004 削除成功は所有を外して設定を保存し、削除済みのヘルパーを呼ばない",
          arguments: [false, true])
    func removalSucceeded(external: Bool) async {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
        fixture.system.sleepDisabled = external
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        fixture.model.changeSettings(settings)
        fixture.model.requestStart(from: .menu)
        let session = fixture.model.status.session
        let model = settingsModel(fixture) { operation in
            #expect(operation == .remove)
            #expect(fixture.model.prepareHelperRemoval())
            fixture.system.sleepDisabled = external
            fixture.system.isHelperInstalled = false
            fixture.system.failing = [.helperOff, .helperOn]
            return .success
        }
        fixture.system.clearHistory()
        await model.manage(.remove)
        #expect(model.helperState == .notInstalled)
        #expect(!fixture.model.settings.blocksManualSleep)
        #expect(fixture.savedSettings.count == 2)
        #expect(fixture.savedSettings.last == fixture.model.settings)
        #expect(fixture.system.operations.contains(.helperOff) == !external)
        #expect(!fixture.system.operations.contains(.helperOn))
        #expect(fixture.system.sleepDisabled == external)
        #expect(fixture.model.status.session == session)
        #expect(!fixture.model.status.hasWarnings)
    }

    @Test("SPEC-HLP-004 所有を解放した後の登録解除の失敗は、所有を再取得せず設定とセッションを保つ",
          arguments: [false, true])
    func removalFailed(unreadable: Bool) async {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        fixture.model.changeSettings(settings)
        fixture.model.requestStart(from: .menu)
        let session = fixture.model.status.session
        let model = settingsModel(fixture) { _ in
            #expect(fixture.model.prepareHelperRemoval())
            fixture.system.sleepDisabled = false
            fixture.system.failing = unreadable ? [.readSleepDisabled] : []
            fixture.system.clearHistory()
            return .failure(operation: .remove, details: "test", needsSleepDisabledReadback: true)
        }
        var errors = 0
        model.showError = { _, _ in errors += 1 }
        await model.manage(.remove)
        #expect(!fixture.system.operations.contains(.readSleepDisabled))
        #expect(fixture.model.status.misalignments == [.systemSleepDisabled: .notApplied])
        #expect(fixture.model.settings == settings)
        #expect(fixture.savedSettings == [settings])
        #expect(fixture.model.status.session == session)
        #expect(errors == 1)
        fixture.system.failing = []
        fixture.model.reconcile()
        #expect(fixture.system.sleepDisabled)
        #expect(!fixture.model.status.hasWarnings)
    }

    @Test("SPEC-HLP-004 SPEC-HLP-005 所有の解放に失敗したら登録を外さず、成功したら登録解除の後に設定を保存する",
          arguments: [0, 1, 2, 3, 4])
    func liveRemovalOrder(scenario: Int) async {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
        let external = scenario == 0
        fixture.system.sleepDisabled = external
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        fixture.model.changeSettings(settings)
        fixture.model.requestStart(from: .menu)
        fixture.system.failing = scenario == 1 ? [.helperOff] : scenario == 2 ? [.readSleepDisabled] : []
        var status = SMAppService.Status.enabled
        var events: [String] = []
        let registration = HelperRegistration(status: { status }, register: {
            Issue.record("削除で登録を実行した")
        }, unregister: {
            events.append("unregister")
            #expect(fixture.model.settings.blocksManualSleep)
            #expect(fixture.system.sleepDisabled == external)
            if scenario == 4 {
                status = .requiresApproval
                throw NSError(domain: NSPOSIXErrorDomain, code: 5)
            }
            status = .notRegistered
            fixture.system.isHelperInstalled = false
        }, teamIdentifier: { "TEAM" }, bundleURL: URL(filePath: "/Applications/Capsaicin.app"), version: "2",
        registeredVersion: { "2" }, saveVersion: { _ in })
        let model = SettingsModel(app: fixture.model, helper: .live(
            registration: registration, prepareRemoval: {
                events.append("restore")
                return fixture.model.prepareHelperRemoval()
            }, completed: fixture.model.helperManagementCompleted,
        ))
        model.confirm = { _, _ in true }
        var errors = 0
        model.showError = { _, _ in errors += 1 }
        await model.manage(.remove)
        let restoreFailed = scenario == 1 || scenario == 2
        #expect(events == (restoreFailed ? ["restore"] : ["restore", "unregister"]))
        #expect(fixture.model.settings.blocksManualSleep == (restoreFailed || scenario == 4))
        #expect(errors == (restoreFailed || scenario == 4 ? 1 : 0))
        #expect(model.helperState == (restoreFailed ? .installed : scenario == 4 ? .requiresApproval : .notInstalled))
    }

    @Test("SPEC-HLP-001 SPEC-HLP-004 設置後は未反映の制御を合わせ直す",
          arguments: [HelperManagementOperation.install])
    func installationReconciles(operation: HelperManagementOperation) async {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        fixture.model.changeSettings(settings)
        fixture.model.requestStart(from: .menu)
        fixture.system.sleepDisabled = false
        fixture.system.isHelperInstalled = false
        fixture.model.helperRemovalFailed()
        #expect(fixture.model.status.hasWarnings)
        let model = settingsModel(fixture) { requested in
            #expect(requested == operation)
            fixture.system.isHelperInstalled = true
            return .success
        }
        fixture.system.clearHistory()
        await model.manage(operation)
        #expect(model.helperState == .installed)
        #expect(fixture.system.operations.contains(.helperOn))
        #expect(fixture.system.sleepDisabled)
        #expect(!fixture.model.status.hasWarnings)
        #expect(fixture.model.settings == settings)
        #expect(fixture.savedSettings == [settings])
    }

    @Test("SPEC-HLP-001 設定からの設置は成功後に保存して抑止に反映する")
    func installationFromSetting() async {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
        fixture.model.requestStart(from: .menu)
        fixture.system.isHelperInstalled = false
        let model = settingsModel(fixture) { operation in
            #expect(operation == .install)
            #expect(fixture.savedSettings.isEmpty)
            fixture.system.isHelperInstalled = true
            return .success
        }
        await model.changeLidClose(to: .keepOn)
        #expect(fixture.model.settings.blocksManualSleep)
        #expect(fixture.model.settings.lidCloseDisplay == .keepOn)
        #expect(fixture.savedSettings == [fixture.model.settings])
        #expect(fixture.system.sleepDisabled)
    }

    @Test("SPEC-HLP-001 SPEC-HLP-004 取り消しと設置失敗は Core の状態を変えない",
          arguments: [HelperManagementOperation.install, .remove])
    func unsuccessfulManagement(operation: HelperManagementOperation) async {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
        fixture.model.requestStart(from: .menu)
        let before = fixture.model.status
        let model = settingsModel(fixture) { _ in .cancelled }
        fixture.system.clearHistory()
        await model.manage(operation)
        fixture.model.helperManagementCompleted(operation, .failure(
            operation: operation, details: "test", needsSleepDisabledReadback: false,
        ))
        #expect(fixture.system.operations.isEmpty)
        #expect(fixture.model.status == before)
        #expect(fixture.savedSettings.isEmpty)
    }

    private func settingsModel(
        _ fixture: AppFixture,
        perform: @escaping (HelperManagementOperation) async -> HelperManagementResult,
    ) -> SettingsModel {
        let model = SettingsModel(app: fixture.model, helper: SettingsHelperActions(
            state: { fixture.system.isHelperInstalled ? .installed : .notInstalled },
            perform: perform, completed: fixture.model.helperManagementCompleted,
        ))
        model.confirm = { _, _ in true }
        return model
    }
}
