import AppKit
import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinPlatform
import SwiftUI
import Testing

@MainActor
struct MenuRedesignTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("SPEC-MENU-002 両状態で今からの見出し・時間・時刻を並べ、抑止中だけ条件なしを追加し、チェックを付けない",
          arguments: [false, true])
    func timeSubmenu(active: Bool) throws {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
        fixture.model.hasVirtualKeyboard = true
        if active {
            fixture.model.requestStart(from: .menu)
        }
        let controller = menu(settings(fixture))
        #expect(!controller.menu.items.contains { $0.identifier?.rawValue.contains("virtualKeyboard") == true })
        let submenu = try #require(item(active ? "menu.changeTime" : "menu.startFor", in: controller.menu).submenu)
        #expect(submenu.items.map { $0.identifier?.rawValue } == ["menu.header.fromNow"] + [
            "preset.15", "preset.30", "preset.60", "preset.120", "preset.240", "preset.480",
            "menu.startFor.custom",
        ] + ["separator.time", "menu.startUntil"] + (active ? ["separator.noTimeLimit", "menu.noTimeLimit"] : []))
        #expect(submenu.items.map { $0.action != nil } == [false]
            + Array(repeating: true, count: 7) + [false, true] + (active ? [false, true] : []))
        #expect(submenu.items.allSatisfy { $0.state == .off && $0.view == nil })
        #expect(submenu.items.first?.isSectionHeader == true)
        #expect(submenu.items.first?.title
            == MenuContent.text("menu.header.fromNow", bundle: Bundle(for: MenuBarController.self)))
        if active {
            #expect(submenu.items.last?.title
                == MenuContent.text("menu.noTimeLimit", bundle: Bundle(for: MenuBarController.self)))
        }
        #expect(controller.menu.items.first?.isSectionHeader == true)
    }

    @Test("SPEC-MENU-002 メニューで抑止中の時間を置き換え、時間指定なしにもでき、既定値とバッテリー条件を保つ",
          arguments: ["preset.30", "menu.noTimeLimit"])
    func replaceTime(id: String) throws {
        let fixture = AppFixture()
        fixture.system.now = Date(timeIntervalSince1970: 0)
        fixture.model.finishLaunching()
        try fixture.model.requestStart(from: .menu, override: .timer(#require(TimerDuration(minutes: 60))))
        let before = fixture.model.settings
        let battery = fixture.model.status.batteryCondition
        fixture.system.advance(by: 600)
        fixture.system.clearHistory()
        let controller = menu(settings(fixture))
        let submenu = try #require(item("menu.changeTime", in: controller.menu).submenu)
        try submenu.performActionForItem(at: submenu.index(of: item(id, in: submenu)))
        #expect(fixture.model.status.isBlocking)
        #expect(fixture.model.status.session?.timeLimit?.date == (id == "preset.30"
                ? Date(timeIntervalSince1970: 2400) : nil))
        #expect(fixture.model.settings == before)
        #expect(fixture.model.status.batteryCondition == battery)
        #expect(fixture.system.operations.isEmpty)
    }

    @Test("SPEC-MENU-008 SPEC-SET-005 SPEC-SET-006 設定と同じ2項目と選択肢を、ハードウェアと保存値から表示する",
          arguments: [false, true], SettingsLidCloseChoice.allCases)
    func sleepEntries(hasLid: Bool, choice: SettingsLidCloseChoice) async throws {
        let system = FakeSystem()
        let app = AppModel(controller: BlockingController(
            settings: Settings(), capabilities: MachineCapabilities(hasLid: hasLid, hasInternalBattery: hasLid),
            ports: system.ports,
        ), saveSettings: { _ in })
        let model = SettingsModel(app: app, helper: .init(
            state: { .installed }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
        await model.changeLidClose(to: choice)
        model.change(\.blocksDisplaySleep, to: false)
        let controller = menu(model)
        let quick = try #require(item("menu.quickSettings", in: controller.menu).submenu)
        #expect(quick.items.first?.identifier?.rawValue == "menu.sleep.display")
        let entries = quick.items.filter { $0.identifier?.rawValue.hasPrefix("menu.sleep.") == true }
        #expect(entries.first?.title == SettingsSection.sleep.text("display.label"))
        #expect(entries.first?.state == .on)
        if hasLid {
            let choices = Array(entries.dropFirst())
            #expect(choices.map(\.title) == SettingsLidCloseChoice.allCases.map {
                SettingsSection.sleep.text("lidClose." + $0.rawValue)
            })
            #expect(choices.map(\.state) == SettingsLidCloseChoice.allCases.map { $0 == choice ? .on : .off })
        } else {
            #expect(entries[1].title == SettingsSection.sleep.text("manual.label"))
            #expect(entries[1].state == (choice == .sleep ? .off : .on))
        }
        #expect(entries.allSatisfy { $0.submenu == nil })
        app.finishLaunching()
        app.requestStart(from: .menu)
        controller.refresh()
        let activeQuick = try #require(item("menu.quickSettings", in: controller.menu).submenu)
        let activeEntries = activeQuick.items.filter { $0.identifier?.rawValue.hasPrefix("menu.sleep.") == true }
        #expect(activeEntries.map(\.title) == entries.map(\.title))
        #expect(activeEntries.map(\.state) == entries.map(\.state))
    }

    @Test("SPEC-MENU-008 SPEC-SET-005 選べない保存値にも注意を付け、標準へ戻せる。注意がなくなると外す")
    func sleepWarnings() async throws {
        let fixture = AppFixture()
        var installed = true
        let model = SettingsModel(app: fixture.model, helper: .init(
            state: { installed ? .installed : .requiresApproval }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
        await model.changeLidClose(to: .zeroBrightness)
        fixture.system.isKnownUnavailable = true
        installed = false
        model.refreshHelper()
        let controller = menu(model)
        let quick = try #require(item("menu.quickSettings", in: controller.menu).submenu)
        let lid = try item("menu.sleep.lidClose.zeroBrightness", in: quick)
        let title = SettingsSection.sleep.text("lidClose.zeroBrightness")
        #expect(!lid.isEnabled && lid.image == nil && lid.title == warningMark + title)
        #expect(try item("menu.sleep.lidClose.sleep", in: quick).isEnabled)
        #expect(lid.subtitle == model.sleepRows[1].warning)
        #expect(lid.subtitle?.contains(SettingsSection.sleep.text("lidClose.help")) == false)
        #expect(lid.subtitle?.hasPrefix(SettingsSection.sleep.text("helperInactive")) == true)
        #expect(lid.subtitle?.contains(SettingsSection.sleep.text("brightnessUnavailable")) == true)
        #expect(lid.state == .on && lid.submenu == nil)
        installed = true
        fixture.system.isKnownUnavailable = false
        model.refreshHelper()
        controller.refresh()
        #expect(lid.image == nil && lid.subtitle == nil && lid.title == title)
        #expect(lid.isEnabled)
    }

    @Test("SPEC-MENU-008 ヘルパー不要の切り替えも設定画面と同じ経路で保存し、失敗時は戻す",
          arguments: [false, true])
    func toggleDisplay(fails: Bool) async throws {
        let fixture = AppFixture(displayBlocked: false)
        fixture.model.finishLaunching()
        fixture.model.requestStart(from: .menu)
        if fails {
            fixture.system.failing = [.createAssertion(.preventUserIdleDisplaySleep)]
        }
        let model = settings(fixture)
        var errors = 0
        model.showError = { _, _ in errors += 1 }
        let controller = menu(model)
        let quick = try #require(item("menu.quickSettings", in: controller.menu).submenu)
        let display = try item("menu.sleep.display", in: quick)
        quick.performActionForItem(at: quick.index(of: display))
        await drainActions()
        #expect(fixture.model.settings.blocksDisplaySleep == !fails)
        #expect(display.state == (fails ? .on : .off))
        #expect(fixture.savedSettings.count == (fails ? 0 : 1))
        #expect(errors == (fails ? 1 : 0))
    }

    @Test("SPEC-MENU-008 開くたびにヘルパーの状態を読み、選べない項目に理由を出さない",
          arguments: [false, true], [HelperInstallationState.notInstalled, .requiresApproval, .unavailable])
    func helperAvailability(hasLid: Bool, unavailableState: HelperInstallationState) async throws {
        let system = FakeSystem()
        let before = Settings()
        let app = AppModel(controller: BlockingController(
            settings: before, capabilities: MachineCapabilities(hasLid: hasLid, hasInternalBattery: false),
            ports: system.ports,
        ), saveSettings: { _ in Issue.record("選べない値を保存した") })
        var state = HelperInstallationState.installed
        let model = SettingsModel(app: app, helper: .init(
            state: { state }, perform: { _ in Issue.record("メニューから登録した"); return .cancelled },
            completed: { _, _ in }, openSystemSettings: { Issue.record("システム設定を開いた") },
        ))
        model.confirm = { _ in Issue.record("メニューから確認を出した"); return false }
        model.showError = { _, _ in Issue.record("選べない値でエラーを出した") }
        let controller = menu(model)
        controller.openSettings = { Issue.record("設定を開いた") }
        let quick = try #require(item("menu.quickSettings", in: controller.menu).submenu)
        let entries = quick.items.filter { $0.identifier?.rawValue.hasPrefix("menu.sleep.") == true }
        #expect(entries.allSatisfy { $0.isEnabled && $0.action != nil })

        func reopen() {
            controller.menuWillOpen(controller.menu)
            controller.menuDidClose(controller.menu)
        }
        state = unavailableState
        reopen()
        #expect(model.helperState == unavailableState)
        let disabled = entries.filter { !$0.isEnabled }
        #expect(disabled.map { $0.identifier?.rawValue } == (hasLid
                ? ["menu.sleep.lidClose.turnOff", "menu.sleep.lidClose.zeroBrightness", "menu.sleep.lidClose.keepOn"]
                : ["menu.sleep.manual"]))
        #expect(entries.allSatisfy { $0.subtitle == nil })
        for entry in disabled {
            #expect(entry.action == nil)
            quick.performActionForItem(at: quick.index(of: entry))
        }
        await drainActions()
        #expect(app.settings == before)
        if hasLid {
            let sleep = try item("menu.sleep.lidClose.sleep", in: quick)
            #expect(sleep.isEnabled && sleep.state == .on)
        }

        state = .installed
        reopen()
        #expect(model.helperState == .installed)
        #expect(entries.allSatisfy { $0.isEnabled && $0.action != nil && $0.subtitle == nil })
    }
}

extension MenuRedesignTests {
    @Test("SPEC-MENU-003 パネルのタイトルと確定・キャンセルボタンを状態に合わせる",
          arguments: [false, true], [StartPanelInput.Mode.duration, .time])
    func panelButtons(active: Bool, mode: StartPanelInput.Mode) async throws {
        _ = NSApplication.shared
        let input = StartPanelInput(mode: mode, settings: Settings(),
                                    session: active ? BlockingSession(timeLimit: nil) : nil,
                                    now: Date(timeIntervalSince1970: 0), calendar: calendar)
        let panel = StartPanel.makePanel(input: input, start: { _ in })
        defer { panel.close() }
        try await prepareAccessibility(panel)
        #expect(panel.title == MenuContent.text(input.titleKey))
        let buttons = try accessibilityButtons(#require(panel.contentView))
        let confirm = try #require(buttons.first { $0.accessibilityLabel?() == MenuContent.text(input.confirmKey) })
        #expect(confirm.isAccessibilityEnabled?() == true)
        #expect(buttons.contains { $0.accessibilityLabel?() == MenuContent.text("panel.cancel") })
    }

    private func accessibilityButtons(_ element: AnyObject) -> [AnyObject] {
        (element.accessibilityRole?() == .button ? [element] : [])
            + (element.accessibilityChildren?() as? [AnyObject] ?? []).flatMap(accessibilityButtons)
    }

    private func prepareAccessibility(_ panel: NSPanel) async throws {
        let host = try #require(panel.contentView as? NSHostingView<StartPanelView>)
        panel.contentView = NSHostingView(rootView: host.rootView.environment(\.accessibilityEnabled, true))
        for _ in 0 ..< 3 {
            panel.contentView?.layoutSubtreeIfNeeded()
            await drainActions()
        }
        panel.display()
    }

    @Test("SPEC-MENU-003 時間の入力が不正ならパネルの確定ボタンを無効にする", arguments: [0, 1441])
    func invalidPanel(minutes: Int) async throws {
        _ = NSApplication.shared
        var input = StartPanelInput(mode: .duration, settings: Settings(), now: .now, calendar: calendar)
        input.duration.hours = String(minutes / 60)
        input.duration.minutes = String(minutes % 60)
        let panel = StartPanel.makePanel(input: input, start: { _ in Issue.record("不正な入力で確定した") })
        defer { panel.close() }
        try await prepareAccessibility(panel)
        let buttons = try accessibilityButtons(#require(panel.contentView))
        let confirm = try #require(buttons.first { $0.accessibilityLabel?() == MenuContent.text(input.confirmKey) })
        #expect(confirm.isAccessibilityEnabled?() == false)
    }

    @Test("SPEC-MENU-003 抑止中は残り分を切り上げ、現在の時刻と変更用のタイトル・ボタンを使う")
    func activePanelInput() {
        let now = Date(timeIntervalSince1970: 13 * 3600 + 10 * 60 + 30)
        let release = Date(timeIntervalSince1970: 14 * 3600)
        let session = BlockingSession(timeLimit: TimeLimit(date: release, source: .timer))
        for mode in [StartPanelInput.Mode.duration, .time] {
            let input = StartPanelInput(
                mode: mode,
                settings: Settings(),
                session: session,
                now: now,
                calendar: calendar,
            )
            #expect(input.duration.value?.minutes == 50)
            #expect(input.date == release)
            #expect(input.isReplacing && input.titleKey == "panel.changeTime.title" && input
                .confirmKey == "panel.change")
            #expect(input.releaseDate(now: now, calendar: calendar) == (mode == .duration
                    ? now.addingTimeInterval(50 * 60) : release))
        }
    }

    @Test("SPEC-MENU-003 時間条件なしの抑止中も、停止中と同じ初期値を使う", arguments: [false, true])
    func unlimitedPanelInput(enabled: Bool) throws {
        var settings = Settings()
        settings.timerEnabled = enabled
        settings.specifiedTimeEnabled = enabled
        settings.timerDuration = try #require(TimerDuration(minutes: 125))
        settings.specifiedTime = try #require(TimeOfDay(hour: 9, minute: 25))
        let now = Date(timeIntervalSince1970: 0)
        let idle = StartPanelInput(mode: .duration, settings: settings, now: now, calendar: calendar)
        let active = StartPanelInput(mode: .duration, settings: settings, session: BlockingSession(timeLimit: nil),
                                     now: now, calendar: calendar)
        #expect(active.duration == idle.duration && active.date == idle.date)
        #expect(active.duration.value?.minutes == (enabled ? 125 : 60))
        #expect(calendar.component(.hour, from: active.date) == (enabled ? 9 : 4))
        #expect(calendar.component(.minute, from: active.date) == (enabled ? 25 : 0))
        #expect(idle.confirmKey == "panel.start" && idle.titleKey == "panel.duration.title")
    }

    @Test("SPEC-MENU-003 パネルは停止と抑止の間の変化だけで閉じ、時間変更や再描画では閉じない",
          arguments: [false, true])
    func panelLifetime(active: Bool) throws {
        _ = NSApplication.shared
        let fixture = AppFixture()
        fixture.model.finishLaunching()
        if active {
            fixture.model.requestStart(from: .menu)
        }
        let controller = menu(settings(fixture))
        controller.makeInputPanel = { mode, app in
            StartPanel.makePanel(input: StartPanelInput(mode: mode, settings: app.settings,
                                                        session: app.status.session, now: .now, calendar: .current),
                                 start: { _ in })
        }
        let submenu = try #require(item(active ? "menu.changeTime" : "menu.startFor", in: controller.menu).submenu)
        try submenu.performActionForItem(at: submenu.index(of: item("menu.startFor.custom", in: submenu)))
        let panel = try #require(controller.inputPanel)
        defer { controller.stop() }
        #expect(panel.contentView?.frame.width == 300)
        #expect(panel.styleMask == [.titled, .closable])
        controller.refresh()
        #expect(controller.inputPanel === panel)
        if active {
            try fixture.model.requestStart(from: .menu, override: .timer(#require(TimerDuration(minutes: 60))))
            controller.refresh()
            #expect(controller.inputPanel === panel)
            fixture.model.requestStop(from: .menu)
        } else {
            fixture.model.requestStart(from: .menu)
        }
        controller.refresh()
        #expect(controller.inputPanel == nil)
    }

    private func menu(_ settings: SettingsModel) -> MenuBarController {
        let controller = MenuBarController(settings: settings, isOnACPower: { false })
        controller.configureShortcut = { _ in }
        controller.refresh()
        return controller
    }

    private func settings(_ fixture: AppFixture) -> SettingsModel {
        SettingsModel(app: fixture.model, helper: .init(
            state: { .installed }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
    }

    private func item(_ id: String, in menu: NSMenu) throws -> NSMenuItem {
        try #require(menu.items.first { $0.identifier?.rawValue == id })
    }

    private func drainActions() async {
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }
}
