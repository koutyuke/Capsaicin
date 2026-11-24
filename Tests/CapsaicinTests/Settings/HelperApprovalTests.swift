import AppKit
import CapsaicinPlatform
import Testing

@MainActor
struct HelperApprovalTests {
    @Test("SPEC-HLP-001 登録ではシステム設定を開かず、明示操作でのみ開く")
    func openSettingsOnlyOnRequest() async {
        let fixture = AppFixture()
        var state = HelperInstallationState.notInstalled
        var events: [String] = []
        let model = SettingsModel(app: fixture.model, helper: .init(state: { state }, perform: { operation in
                #expect(operation == .install)
                events.append("register")
                state = .requiresApproval
                return .success
            }, completed: { _, _ in Issue.record("承認待ちで設置を完了した") },
            openSystemSettings: { events.append("open") }))
        model.confirm = { _ in events.append("confirm"); return true }
        await model.manage(.install)
        #expect(model.helperState == .requiresApproval)
        #expect(events == ["confirm", "register"])
        await model.manage(.install)
        #expect(events == ["confirm", "register"])
        model.openHelperSystemSettings()
        #expect(events == ["confirm", "register", "open"])
        #expect(fixture.savedSettings.isEmpty)
    }

    @Test("SPEC-HLP-004 SPEC-HLP-006 戻せないので削除しない場合も登録解除の失敗も、削除の失敗としてやり直し方を伝える",
          arguments: [false, true])
    func removalErrors(needsReadback: Bool) async {
        let fixture = AppFixture()
        let model = SettingsModel(app: fixture.model, helper: .init(state: { .installed }, perform: { operation in
            .failure(operation: operation, details: "private test details", needsSleepDisabledReadback: needsReadback)
        }, completed: { _, _ in }))
        model.confirm = { _ in true }
        var errors: [[String]] = []
        model.showError = { title, message in errors.append([title, message]) }
        await model.manage(.remove)
        #expect(errors == [[SettingsSection.helper.text("error.helperRemove.title"),
                            SettingsSection.helper.text("error.helperRetry.message")]])
        #expect(fixture.savedSettings.isEmpty)
    }

    @Test("SPEC-HLP-001 SPEC-HLP-006 未設置で App Translocation ならエラーを出し、使用不可なら設置を始めない",
          arguments: [HelperInstallationState.unavailable, .notInstalled])
    func installationPreflight(state: HelperInstallationState) async {
        let fixture = AppFixture()
        let model = SettingsModel(app: fixture.model, helper: .init(state: { state }, perform: { _ in
            Issue.record("使えない場所やビルドで登録した")
            return .success
        }, completed: { _, _ in }, isTranslocated: { state == .notInstalled }))
        model.confirm = { _ in Issue.record("登録できないのに確認した"); return true }
        var errors: [String] = []
        model.showError = { title, _ in errors.append(title) }
        await model.manage(.install)
        #expect(errors ==
            (state == .notInstalled ? [SettingsSection.helper.text("error.helperTranslocated.title")] : []))
        #expect(!model.isBusy && fixture.savedSettings.isEmpty)
    }
}

extension SettingsTests {
    @Test("SPEC-HLP-006 設置の確認は既定ボタンとキャンセルを持つシートで、閉じてから登録する",
          arguments: [false, true])
    func installationSheet(accepts: Bool) async throws {
        _ = NSApplication.shared
        let fixture = AppFixture()
        var window: NSWindow?
        var registrations = 0
        let model = SettingsModel(app: fixture.model, helper: .init(state: { .notInstalled }, perform: { operation in
            #expect(operation == .install && window?.attachedSheet == nil)
            registrations += 1
            return .success
        }, completed: { _, _ in }, openSystemSettings: { Issue.record("システム設定を開いた") }))
        let controller = SettingsWindowController(model: model, hotkey: HotkeyController(save: { _ in true }), quit: {})
        let settingsWindow = try #require(controller.window)
        window = settingsWindow
        defer { settingsWindow.close() }
        settingsWindow.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        settingsWindow.orderBack(nil)
        let install = Task { await model.manage(.install) }
        defer {
            if let sheet = settingsWindow.attachedSheet {
                settingsWindow.endSheet(sheet)
            }
        }
        await layout(settingsWindow)
        let sheet = try #require(settingsWindow.attachedSheet)
        #expect(sheet.sheetParent === settingsWindow)
        #expect(registrations == 0 && model.isBusy && fixture.savedSettings.isEmpty)
        func descendants(_ view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap { descendants($0) }
        }
        let views = try descendants(#require(sheet.contentView))
        let text = views.compactMap { ($0 as? NSTextField)?.stringValue }
        #expect(text.contains(SettingsSection.helper.text("helperInstall.title")))
        #expect(text.contains(SettingsSection.helper.text("helperInstall.message")))
        let confirm = try #require(sheet.defaultButtonCell?.controlView as? NSButton)
        #expect(confirm.title == SettingsSection.helper.text("helperInstall.confirm"))
        let cancel = try #require(views.compactMap { $0 as? NSButton }.first {
            $0.title == SettingsSection.helper.text("cancel")
        })
        (accepts ? confirm : cancel).performClick(nil)
        await install.value
        #expect(settingsWindow.attachedSheet == nil)
        #expect(registrations == (accepts ? 1 : 0))
        #expect(fixture.savedSettings.isEmpty)
    }

    @Test("SPEC-HLP-001 SPEC-HLP-004 設定が開いている間だけ承認を読み直し、完了時も保存値を変えない",
          arguments: [false, true])
    func approvalWindowLifecycle(approveWhileOpen: Bool) throws {
        _ = NSApplication.shared
        let fixture = AppFixture()
        var state = HelperInstallationState.requiresApproval
        var reads = 0
        var completions = 0
        let model = SettingsModel(app: fixture.model, helper: .init(state: { reads += 1; return state },
                                                                    perform: { _ in .cancelled },
                                                                    completed: { operation, result in
                                                                        #expect(operation == .install)
                                                                        if case .success = result {
                                                                            completions += 1
                                                                        }
                                                                    }))
        let controller = SettingsWindowController(model: model, hotkey: HotkeyController(save: { _ in true }), quit: {})
        let window = try #require(controller.window)
        #expect(model.approvalTimer == nil)
        let becameKey = Notification(name: NSWindow.didBecomeKeyNotification, object: window)
        controller.windowDidBecomeKey(becameKey)
        let timer = try #require(model.approvalTimer)
        #expect(timer.timeInterval == 2 && timer.isValid)
        let before = reads
        timer.fire()
        #expect(reads > before && completions == 0)
        if approveWhileOpen {
            state = .installed
            timer.fire()
            #expect(model.helperState == .installed && completions == 1)
            #expect(!timer.isValid && model.approvalTimer == nil)
        }
        window.close()
        #expect(!timer.isValid && model.approvalTimer == nil)
        state = .installed
        controller.windowDidBecomeKey(becameKey)
        #expect(model.helperState == .installed && completions == 1)
        #expect(model.lidCloseChoice == .sleep && fixture.savedSettings.isEmpty)
    }
}
