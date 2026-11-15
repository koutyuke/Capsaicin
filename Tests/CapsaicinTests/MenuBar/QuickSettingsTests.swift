import AppKit
import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinPlatform
import Testing

@MainActor
struct QuickSettingsTests {
    @Test("SPEC-MENU-001 トップレベルは時間指定なしを常に出し、チェックの付く設定を置かない",
          arguments: [false, true], [false, true])
    func topLevel(active: Bool, timeEnabled: Bool) throws {
        let fixture = AppFixture()
        fixture.model.launch()
        let model = settings(fixture.model)
        model.change(\.timerEnabled, to: timeEnabled)
        model.change(\.specifiedTimeEnabled, to: timeEnabled)
        if active {
            fixture.model.requestStart(from: .menu)
        }
        let controller = menu(model)
        let expected = active ? [
            "menu.header.active", timeEnabled ? "menu.status.until" : "menu.status.noCondition",
            "menu.status.battery", "menu.stop", "menu.changeTime",
        ] : ["menu.header.idle", "menu.start", "separator.start", "menu.startNoTimeLimit", "menu.startFor"]
        #expect(controller.menu.items.map { $0.identifier?.rawValue } == expected + [
            "separator.sleep", "menu.quickSettings", "separator.footer", "menu.settings", "menu.quit",
        ])
        #expect(controller.menu.items.allSatisfy { $0.state == .off && $0.view == nil })
        if !active {
            #expect(try item("menu.startNoTimeLimit", in: controller.menu).title == MenuContent
                .text("menu.startNoTimeLimit", bundle: Bundle(for: MenuBarController.self)))
            #expect(try item("menu.startFor", in: controller.menu).title
                == MenuContent.text("menu.startFor", bundle: Bundle(for: MenuBarController.self)))
        }
    }

    @Test("SPEC-MENU-008 SPEC-SET-006 クイック設定はハードウェア別の見出しと項目を1段に並べる",
          arguments: [false, true], [false, true])
    func contents(hasLid: Bool, hasBattery: Bool) throws {
        let system = FakeSystem()
        let app = AppModel(controller: BlockingController(
            settings: Settings(), capabilities: MachineCapabilities(hasLid: hasLid, hasInternalBattery: hasBattery),
            ports: system.ports,
        ), saveSettings: { _ in })
        let controller = menu(settings(app))
        let rows = MenuContent.make(status: app.status, settings: app.settings, isOnACPower: false,
                                    hasInternalBattery: hasBattery, sleepRows: settings(app).sleepRows)
        let choices = try #require(rows.first { $0.id == "menu.quickSettings" }?.children)
        #expect(choices.first { $0.id == "menu.sleep.display" }?.command == .toggleSleep("display"))
        let quick = try #require(item("menu.quickSettings", in: controller.menu).submenu)
        let expected = ["menu.sleep.display"] + (hasLid ? [
            "separator.lidClose", "menu.header.lidClose", "menu.sleep.lidClose.sleep", "menu.sleep.lidClose.turnOff",
            "menu.sleep.lidClose.zeroBrightness", "menu.sleep.lidClose.keepOn",
        ] : ["menu.sleep.manual"]) + (hasBattery ? ["separator.battery", "menu.battery"] : [])
        #expect(quick.items.map { $0.identifier?.rawValue } == expected)
        #expect(quick.items.allSatisfy { $0.submenu == nil && $0.view == nil })
        #expect(quick.items.filter(\.isSectionHeader).map { $0.identifier?.rawValue }
            == (hasLid ? ["menu.header.lidClose"] : []))
        #expect(quick.items.allSatisfy { $0.indentationLevel == 0 })
        if hasLid {
            let header = try item("menu.header.lidClose", in: quick)
            #expect(header.isSectionHeader && header.title == SettingsSection.sleep.text("lidClose.label"))
            for choice in SettingsLidCloseChoice.allCases {
                let entry = try item("menu.sleep.lidClose." + choice.rawValue, in: quick)
                #expect(entry.state == (choice == .sleep ? .on : .off))
                #expect(entry.accessibilityLabel() == String(
                    format: MenuContent.text("menu.sleep.lidClose.a11y", bundle: Bundle(for: MenuBarController.self)),
                    header.title, entry.title,
                ))
                #expect(choices.first { $0.id == entry.identifier?.rawValue }?.command == .lidClose(choice))
            }
        } else {
            #expect(choices.first { $0.id == "menu.sleep.manual" }?.command == .toggleSleep("manual"))
        }
    }

    @Test("SPEC-MENU-008 クイック設定の行は副題を持たず、バッテリー残量の条件によらず同じ形にする",
          arguments: [false, true], [false, true])
    func rowWithoutSubtitle(hasBattery: Bool, enabled: Bool) throws {
        let system = FakeSystem()
        var value = Settings()
        value.batteryConditionEnabled = enabled
        let app = AppModel(controller: BlockingController(
            settings: value, capabilities: MachineCapabilities(hasLid: true, hasInternalBattery: hasBattery),
            ports: system.ports,
        ), saveSettings: { _ in })
        let controller = menu(settings(app))
        let quick = try item("menu.quickSettings", in: controller.menu)
        #expect(quick.title == MenuContent.text("menu.quickSettings", bundle: Bundle(for: MenuBarController.self)))
        #expect(quick.subtitle == nil)
        #expect(quick.image == nil)
    }

    @Test("SPEC-MENU-008 SPEC-SET-005 注意は保存した選択肢とクイック設定に付き、ほかの選択肢と見出しには付かない",
          arguments: SettingsLidCloseChoice.allCases)
    func lidWarnings(choice: SettingsLidCloseChoice) throws {
        let fixture = AppFixture()
        var value = fixture.model.settings
        value.blocksManualSleep = choice != .sleep
        value.lidCloseDisplay = LidCloseDisplay(rawValue: choice.rawValue) ?? .keepOn
        value.batteryConditionEnabled = false
        fixture.model.changeSettings(value)
        fixture.system.isKnownUnavailable = true
        var installed = false
        let model = SettingsModel(app: fixture.model, helper: .init(
            state: { installed ? .installed : .partial }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
        let controller = menu(model)
        let parent = try item("menu.quickSettings", in: controller.menu)
        let quick = try #require(parent.submenu)
        #expect((parent.image != nil) == (choice != .sleep))
        #expect(parent.subtitle == nil)
        #expect(try item("menu.header.lidClose", in: quick).image == nil)
        for candidate in SettingsLidCloseChoice.allCases {
            let entry = try item("menu.sleep.lidClose." + candidate.rawValue, in: quick)
            let warns = candidate == choice && choice != .sleep
            #expect((entry.image != nil) == warns)
            #expect(entry.subtitle == (warns ? model.sleepRows[1].warning : nil))
            let label = String(
                format: MenuContent.text("menu.sleep.lidClose.a11y", bundle: Bundle(for: MenuBarController.self)),
                SettingsSection.sleep.text("lidClose.label"), entry.title,
            )
            #expect(entry.accessibilityLabel() == (warns
                    ? String(
                        format: MenuContent.text("menu.warning.a11y", bundle: Bundle(for: MenuBarController.self)),
                        label,
                    )
                    : label))
        }
        installed = true
        fixture.system.isKnownUnavailable = false
        model.refreshHelper()
        controller.refresh()
        #expect(parent.image == nil)
        #expect(quick.items
            .allSatisfy { $0.image == nil && ($0.identifier?.rawValue == "menu.battery" || $0.subtitle == nil) })
    }

    @Test("SPEC-MENU-008 SPEC-SET-005 MacBook以外の注意はオンの項目とクイック設定に付く")
    func manualWarning() throws {
        let system = FakeSystem()
        var value = Settings()
        value.blocksManualSleep = true
        let app = AppModel(controller: BlockingController(
            settings: value, capabilities: MachineCapabilities(hasLid: false, hasInternalBattery: false),
            ports: system.ports,
        ), saveSettings: { _ in })
        let model = SettingsModel(app: app, helper: .init(
            state: { .partial }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
        let controller = menu(model)
        let parent = try item("menu.quickSettings", in: controller.menu)
        let quick = try #require(parent.submenu)
        let manual = try item("menu.sleep.manual", in: quick)
        #expect(manual.state == .on && manual.isEnabled && manual.image != nil)
        #expect(manual.subtitle == model.sleepRows[1].warning)
        #expect(parent.image != nil && parent.subtitle == nil)
        #expect(try item("menu.sleep.display", in: quick).image == nil)
    }

    private func settings(_ app: AppModel) -> SettingsModel {
        SettingsModel(app: app, helper: .init(
            state: { .installed }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
    }

    private func menu(_ model: SettingsModel) -> MenuBarController {
        let controller = MenuBarController(settings: model, isOnACPower: { false })
        controller.configureShortcut = { _ in }
        controller.refresh()
        return controller
    }

    private func item(_ id: String, in menu: NSMenu) throws -> NSMenuItem {
        try #require(menu.items.first { $0.identifier?.rawValue == id })
    }
}
