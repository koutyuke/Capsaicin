import AppKit
import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinPlatform
import Testing

@MainActor
struct HelperApprovalTests {
    @Test("SPEC-HLP-001 SPEC-SET-005 承認待ちでは選択だけを保ち、使えるになったら保存する",
          arguments: [SettingsLidCloseChoice.turnOff, .zeroBrightness, .keepOn])
    func holdsSelectionUntilApproval(choice: SettingsLidCloseChoice) async {
        let fixture = AppFixture()
        fixture.model.launch()
        fixture.model.requestStart(from: .menu)
        let session = fixture.model.status.session
        var state = HelperInstallationState.notInstalled
        var completions = 0
        let model = SettingsModel(app: fixture.model, helper: .init(state: { state }, perform: { _ in
            state = .requiresApproval
            return .success
        }, completed: { operation, result in
            completions += 1
            fixture.model.helperManagementCompleted(operation, result)
        }))
        model.confirm = { _, _ in true }
        await model.changeLidClose(to: choice)
        #expect(model.pendingManual)
        #expect(model.lidCloseChoice == choice)
        #expect(!model.isBusy)
        #expect(fixture.savedSettings.isEmpty)
        #expect(!fixture.model.settings.blocksManualSleep)
        #expect(!model.displayedSleepRows[1].warning.isEmpty)
        #expect(model.displayedSleepRows[1].help.hasPrefix(SettingsSection.sleep.text("helperApprovalPending")))
        #expect(model.sleepRows[1].warning.isEmpty)
        #expect(completions == 0)
        fixture.system.clearHistory()
        state = .installed
        model.refreshHelper()
        #expect(!model.pendingManual)
        #expect(model.lidCloseChoice == choice)
        #expect(fixture.model.settings.blocksManualSleep)
        #expect(fixture.model.settings.lidCloseDisplay.rawValue == choice.rawValue)
        #expect(fixture.savedSettings == [fixture.model.settings])
        #expect(fixture.system.operations.contains(.helperOn))
        #expect(fixture.model.status.session == session)
        #expect(completions == 1)
        model.refreshHelper()
        #expect(fixture.savedSettings.count == 1)
    }

    @Test("SPEC-HLP-001 承認待ちでは登録と確認を繰り返さず、システム設定を開いて選択を保つ")
    func alreadyAwaitingApproval() async {
        let fixture = AppFixture()
        var state = HelperInstallationState.requiresApproval
        var opened = 0
        var completed = 0
        let model = SettingsModel(app: fixture.model, helper: .init(state: { state }, perform: { _ in
            Issue.record("承認待ちで登録を繰り返した")
            return .cancelled
        }, completed: { _, _ in completed += 1 }, openSystemSettings: { opened += 1 }))
        model.confirm = { _, _ in Issue.record("承認待ちで確認を出した"); return false }
        await model.changeLidClose(to: .keepOn)
        #expect(model.pendingManual && model.lidCloseChoice == .keepOn)
        #expect(opened == 1 && completed == 0)
        #expect(fixture.savedSettings.isEmpty)
        await model.manage(.install)
        #expect(model.pendingManual && model.lidCloseChoice == .keepOn)
        #expect(opened == 2)
        state = .installed
        model.refreshHelper()
        #expect(fixture.savedSettings.count == 1 && completed == 1)
    }

    @Test("SPEC-HLP-001 SPEC-SET-005 MacBook以外でも承認前はスイッチだけをオンにして保存しない")
    func desktopPendingSelection() async {
        let system = FakeSystem()
        var saved: [CapsaicinCore.Settings] = []
        let app = AppModel(controller: BlockingController(
            settings: CapsaicinCore.Settings(),
            capabilities: MachineCapabilities(hasLid: false, hasInternalBattery: false), ports: system.ports,
        ), saveSettings: { saved.append($0) })
        var state = HelperInstallationState.requiresApproval
        let model = SettingsModel(app: app, helper: .init(state: { state }, perform: { _ in .cancelled },
                                                          completed: { _, _ in }))
        await model.changeSleep(model.sleepRows[1], to: true)
        #expect(model.displayedSleepRows[1].isOn)
        #expect(!model.sleepRows[1].isOn)
        #expect(!app.settings.blocksManualSleep && saved.isEmpty)
        state = .installed
        model.refreshHelper()
        #expect(app.settings.blocksManualSleep && saved == [app.settings])
    }

    @Test("SPEC-HLP-001 選び直しは古い保留を捨て、承認後は最後の選択だけを保存する",
          arguments: [SettingsLidCloseChoice.sleep, .turnOff])
    func replacesPendingSelection(choice: SettingsLidCloseChoice) async {
        let fixture = AppFixture()
        var state = HelperInstallationState.requiresApproval
        let model = SettingsModel(app: fixture.model, helper: .init(state: { state }, perform: { _ in .cancelled },
                                                                    completed: { _, _ in }))
        await model.changeLidClose(to: .keepOn)
        // 許可された直後の選び直しでも、読み直す前に古い選択を捨てる。
        state = .installed
        await model.changeLidClose(to: choice)
        #expect(!model.pendingManual)
        #expect(model.lidCloseChoice == choice)
        #expect(fixture.savedSettings.count == 1)
        #expect(fixture.savedSettings[0].blocksManualSleep == (choice != .sleep))
        #expect(fixture.savedSettings[0].lidCloseDisplay == .turnOff)
    }

    @Test("SPEC-HLP-001 承認待ちのまま選び直すと新しい値だけを保留し、別の設定の変更は保つ")
    func replacesSelectionWhileWaiting() async {
        let fixture = AppFixture()
        var state = HelperInstallationState.requiresApproval
        let model = SettingsModel(app: fixture.model, helper: .init(state: { state }, perform: { _ in .cancelled },
                                                                    completed: { _, _ in }))
        await model.changeLidClose(to: .keepOn)
        model.change(\.timerEnabled, to: true)
        await model.changeLidClose(to: .zeroBrightness)
        #expect(model.pendingManual && model.lidCloseChoice == .zeroBrightness)
        #expect(!fixture.model.settings.blocksManualSleep)
        #expect(fixture.savedSettings.count == 1)
        state = .installed
        model.refreshHelper()
        #expect(fixture.model.settings.timerEnabled)
        #expect(fixture.model.settings.lidCloseDisplay == .zeroBrightness)
        #expect(fixture.savedSettings.count == 2)
    }

    @Test("SPEC-HLP-004 SPEC-HLP-006 戻せないので削除しない場合と、登録解除の失敗を区別して伝える",
          arguments: [false, true])
    func removalErrors(needsReadback: Bool) async {
        let fixture = AppFixture()
        let model = SettingsModel(app: fixture.model, helper: .init(state: { .installed }, perform: { operation in
            .failure(operation: operation, details: "private test details", needsSleepDisabledReadback: needsReadback)
        }, completed: { _, _ in }))
        model.confirm = { _, _ in true }
        var errors: [String] = []
        model.showError = { _, message in errors.append(message) }
        await model.manage(.remove)
        let key = needsReadback ? "helperRemove" : "helperRestore"
        #expect(errors == [SettingsSection.helper.text("error." + key + ".message")])
        #expect(fixture.savedSettings.isEmpty)
    }

    @Test("SPEC-HLP-001 SPEC-HLP-006 署名とApp Translocationのエラーでは確認も登録もせず選択を戻す",
          arguments: [HelperInstallationState.unavailable, .notInstalled, .requiresApproval], [false, true])
    func installationPreflight(state: HelperInstallationState, fromSetting: Bool) async {
        let fixture = AppFixture()
        let model = SettingsModel(app: fixture.model, helper: .init(state: { state }, perform: { _ in
            Issue.record("使えない場所やビルドで登録した")
            return .success
        }, completed: { _, _ in }, isTranslocated: { state != .unavailable }))
        model.confirm = { _, _ in Issue.record("登録できないのに確認した"); return true }
        var errors: [String] = []
        model.showError = { title, _ in errors.append(title) }
        if fromSetting {
            await model.changeLidClose(to: .keepOn)
        } else {
            await model.manage(.install)
        }
        let key = state == .unavailable ? "helperUnavailable" : "helperTranslocated"
        #expect(errors == [SettingsSection.helper.text("error." + key + ".title")])
        #expect(model.lidCloseChoice == .sleep && !model.pendingManual && !model.isBusy)
        #expect(fixture.savedSettings.isEmpty)
    }

    @Test("SPEC-HLP-001 ヘルパーだけの承認後は合わせ直しだけを行い、ほかの設定は保存しない")
    func approvalWithoutSelection() throws {
        let fixture = AppFixture()
        var state = HelperInstallationState.requiresApproval
        var completed = 0
        let model = SettingsModel(app: fixture.model, helper: .init(state: { state }, perform: { _ in .cancelled },
                                                                    completed: { _, _ in completed += 1 }))
        model.settingsWindowDidBecomeKey()
        let timer = try #require(model.approvalTimer)
        #expect(timer.timeInterval == 2 && timer.isValid)
        state = .installed
        timer.fire()
        #expect(model.helperState == .installed && completed == 1)
        #expect(fixture.savedSettings.isEmpty && !model.pendingManual)
        #expect(!timer.isValid && model.approvalTimer == nil)
        model.settingsWindowClosed()
    }
}

extension SettingsTests {
    @Test("SPEC-HLP-001 SPEC-HLP-004 キーウインドウへの復帰と2秒のタイマーで読み直し、閉じたら保留を捨てる",
          arguments: [false, true])
    func approvalWindowLifecycle(approve: Bool) async throws {
        _ = NSApplication.shared
        let fixture = AppFixture()
        var state = HelperInstallationState.requiresApproval
        var reads = 0
        let model = SettingsModel(app: fixture.model, helper: .init(state: { reads += 1; return state },
                                                                    perform: { _ in .cancelled },
                                                                    completed: { _, _ in }))
        let controller = SettingsWindowController(model: model, hotkey: HotkeyController(save: { _ in true }), quit: {})
        let window = try #require(controller.window)
        controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: window))
        await model.changeLidClose(to: .zeroBrightness)
        let timer = try #require(model.approvalTimer)
        #expect(timer.timeInterval == 2 && timer.isValid)
        let before = reads
        timer.fire()
        #expect(reads > before && model.pendingManual && fixture.savedSettings.isEmpty)
        if approve {
            state = .installed
            controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: window))
            #expect(fixture.savedSettings.count == 1 && model.lidCloseChoice == .zeroBrightness)
        }
        window.close()
        #expect(!model.pendingManual && !timer.isValid && model.approvalTimer == nil)
        #expect(model.lidCloseChoice == (approve ? .zeroBrightness : .sleep))
        state = .installed
        model.refreshHelper()
        #expect(fixture.savedSettings.count == (approve ? 1 : 0))
    }
}
