import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinPlatform
import Testing

@MainActor
struct AppSettingsTests {
    @Test("SPEC-HLP-004 削除成功は所有を外して設定を保存し、削除済みのヘルパーを呼ばない",
          arguments: [false, true])
    func removalSucceeded(external: Bool) async {
        let fixture = AppFixture()
        fixture.model.launch()
        fixture.system.sleepDisabled = external
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        fixture.model.changeSettings(settings)
        fixture.model.requestStart(from: .menu)
        let session = fixture.model.status.session
        let model = settingsModel(fixture) { operation in
            #expect(operation == .remove)
            #expect(fixture.model.resetsSleepDisabledOnHelperRemoval() == !external)
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
        #expect(fixture.system.savedRecords.first?.ownsSleepDisabled == false)
        #expect(!fixture.system.operations.contains(.helperOff))
        #expect(!fixture.system.operations.contains(.helperOn))
        #expect(fixture.system.sleepDisabled == external)
        #expect(fixture.model.status.session == session)
        #expect(!fixture.model.status.hasWarnings)
    }

    @Test("SPEC-HLP-004 削除失敗は読み直して状態を更新し、設定とセッションは保つ",
          arguments: [false, true])
    func removalFailed(unreadable: Bool) async {
        let fixture = AppFixture()
        fixture.model.launch()
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        fixture.model.changeSettings(settings)
        fixture.model.requestStart(from: .menu)
        let session = fixture.model.status.session
        let model = settingsModel(fixture) { _ in
            #expect(fixture.model.resetsSleepDisabledOnHelperRemoval())
            fixture.system.sleepDisabled = false
            fixture.system.failing = unreadable ? [.readSleepDisabled] : []
            fixture.system.clearHistory()
            return .failure(operation: .remove, details: "test", needsSleepDisabledReadback: true)
        }
        var errors = 0
        model.showError = { _, _ in errors += 1 }
        await model.manage(.remove)
        #expect(fixture.system.operations.contains(.readSleepDisabled))
        #expect(fixture.system.storedRecord?.ownsSleepDisabled == unreadable)
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

    @Test("SPEC-HLP-001 SPEC-HLP-004 設置・修復後は未反映の制御を合わせ直す",
          arguments: [HelperManagementOperation.install, .repair])
    func installationReconciles(operation: HelperManagementOperation) async {
        let fixture = AppFixture()
        fixture.model.launch()
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
        fixture.model.launch()
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

    @Test("SPEC-HLP-001 SPEC-HLP-004 取り消しと設置・修復失敗は Core の状態を変えない",
          arguments: [HelperManagementOperation.install, .repair, .remove])
    func unsuccessfulManagement(operation: HelperManagementOperation) async {
        let fixture = AppFixture()
        fixture.model.launch()
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
