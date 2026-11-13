import AppKit
import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinPlatform
import Testing

@MainActor
struct SplitStartMenuTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "ja_JP")
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    @Test("SPEC-MENU-001 開始の副題はタイマー・今日・明日・時間条件なしを示し、バッテリー条件を含めない",
          arguments: [false, true])
    func startSubtitle(batteryEnabled: Bool) throws {
        var settings = Settings()
        settings.batteryConditionEnabled = batteryEnabled
        let now = Date(timeIntervalSince1970: 12 * 3600)
        func subtitle() throws -> String {
            let status = BlockingStatus(session: nil, batteryCondition: batteryEnabled ? BatteryCondition(
                threshold: settings.batteryThreshold, ignoresOnACPower: settings.ignoresBatteryOnACPower,
            ) : nil, misalignments: [:], isRecordUnsaved: false)
            let rows = MenuContent.make(
                status: status,
                settings: settings,
                isOnACPower: false,
                hasInternalBattery: true,
                sleepRows: [],
                now: now,
                calendar: calendar,
                bundle: Bundle(for: MenuBarController.self),
            )
            return try #require(rows.first { $0.id == "menu.start" }?.subtitle)
        }
        #expect(try subtitle() == "オフにするまで")
        settings.timerEnabled = true
        settings.timerDuration = try #require(TimerDuration(minutes: 90))
        #expect(try subtitle() == "1時間30分後にオフ")
        settings.timerDuration = try #require(TimerDuration(minutes: 60))
        #expect(try subtitle() == "1時間後にオフ")
        settings.timerEnabled = false
        settings.specifiedTimeEnabled = true
        settings.specifiedTime = try #require(TimeOfDay(hour: 14, minute: 0))
        #expect(try subtitle() == "14:00にオフ")
        settings.specifiedTime = try #require(TimeOfDay(hour: 4, minute: 0))
        #expect(try subtitle() == "明日4:00にオフ")
        settings.timerEnabled = true
        #expect(try subtitle() == "1時間後にオフ")
        settings.specifiedTime = try #require(TimeOfDay(hour: 12, minute: 30))
        #expect(try subtitle() == "12:30にオフ")
    }

    @Test("SPEC-MENU-004 時間条件がなければ手動の解除まで継続する行をバッテリーの上に置く",
          arguments: [false, true])
    func noTimeStatus(batteryEnabled: Bool) {
        let settings = Settings()
        let battery = BatteryCondition(threshold: settings.batteryThreshold, ignoresOnACPower: true)
        let status = BlockingStatus(session: BlockingSession(timeLimit: nil),
                                    batteryCondition: batteryEnabled ? battery : nil,
                                    misalignments: [:], isRecordUnsaved: false)
        let rows = MenuContent.make(status: status, settings: settings, isOnACPower: false, hasInternalBattery: true,
                                    sleepRows: [],
                                    bundle: Bundle(for: MenuBarController.self))
        #expect(rows[1].id == "menu.status.noCondition")
        #expect(rows[1].title == "手動でオフにするまで継続")
        #expect(rows[2].id == (batteryEnabled ? "menu.status.battery" : "menu.stop"))
    }

    @Test("SPEC-MENU-008 SPEC-SET-006 内蔵バッテリーの有無だけで見出しと項目を出し分ける",
          arguments: [false, true], [false, true])
    func batteryHardware(hasLid: Bool, hasBattery: Bool) throws {
        let system = FakeSystem()
        let app = AppModel(controller: BlockingController(
            settings: Settings(), capabilities: MachineCapabilities(hasLid: hasLid, hasInternalBattery: hasBattery),
            ports: system.ports,
        ), saveSettings: { _ in })
        let controller = menu(settings(app))
        let quick = try #require(item("menu.quickSettings", in: controller.menu).submenu)
        #expect(quick.items.contains { $0.identifier?.rawValue == "menu.header.battery" } == hasBattery)
        #expect(quick.items.contains { $0.identifier?.rawValue == "menu.battery" } == hasBattery)
        if hasBattery {
            let header = try item("menu.header.battery", in: quick)
            #expect(header.isSectionHeader && header.submenu == nil)
            #expect(header.title == SettingsSection.sleep.text("battery.group.title"))
        }
    }

    @Test("SPEC-MENU-008 バッテリー項目は保存値のしきい値・チェック・電源を除く副題を示す",
          arguments: [false, true], [false, true])
    func batteryPresentation(enabled: Bool, ignoresAdapter: Bool) throws {
        let fixture = AppFixture()
        let model = settings(fixture.model)
        model.change(\.batteryConditionEnabled, to: enabled)
        try model.change(\.batteryThreshold, to: #require(BatteryThreshold(percent: 35)))
        model.change(\.ignoresBatteryOnACPower, to: ignoresAdapter)
        func batteryRow() throws -> MenuEntry {
            try #require(MenuContent.make(
                status: fixture.model.status, settings: fixture.model.settings,
                isOnACPower: fixture.system.powerState.isOnACPower,
                hasInternalBattery: fixture.model.capabilities.hasInternalBattery, sleepRows: model.sleepRows,
                bundle: Bundle(for: MenuBarController.self),
            ).first { $0.id == "menu.quickSettings" }?.children.first { $0.id == "menu.battery" })
        }
        let battery = try batteryRow()
        #expect(battery.title == "残量35%未満でオフにする")
        #expect(battery.isChecked == enabled)
        #expect(battery.subtitle == (ignoresAdapter ? "電源アダプタ接続中は除く" : nil))
        #expect(battery.command == .toggleBattery && battery.children.isEmpty)
        fixture.system.powerState = PowerState(batteryLevel: 80, isOnACPower: true)
        #expect(try batteryRow().subtitle == (ignoresAdapter ? "電源アダプタ接続中は除く" : nil))
    }

    @Test("SPEC-MENU-008 SPEC-BLK-009 バッテリー項目は設定画面と同じ経路で保存し、抑止中なら反映する",
          arguments: [false, true])
    func toggleBattery(active: Bool) throws {
        let fixture = AppFixture()
        fixture.model.launch()
        if active {
            fixture.model.requestStart(from: .menu)
        }
        let model = settings(fixture.model)
        let controller = menu(model)
        var expected = fixture.model.settings
        for enabled in [false, true] {
            let quick = try #require(item("menu.quickSettings", in: controller.menu).submenu)
            let battery = try item("menu.battery", in: quick)
            quick.performActionForItem(at: quick.index(of: battery))
            expected.batteryConditionEnabled = enabled
            #expect(fixture.model.settings == expected)
            #expect(fixture.savedSettings.last == expected)
            let updated = try #require(item("menu.quickSettings", in: controller.menu).submenu)
            #expect(try item("menu.battery", in: updated).state == (enabled ? .on : .off))
            #expect(try item("menu.quickSettings", in: controller.menu).subtitle
                == (enabled ? nil : "バッテリー残量ではオフにしない"))
            #expect((fixture.model.status.batteryCondition != nil) == enabled)
            #expect(fixture.model.status.isBlocking == active)
        }
        #expect(fixture.savedSettings.count == 2)
    }

    @Test("SPEC-MENU-002 停止中の時間・時刻サブメニューの時刻項目は時刻パネルを開く")
    func directTimePanel() throws {
        _ = NSApplication.shared
        let fixture = AppFixture()
        let controller = menu(settings(fixture.model))
        var receivedMode: StartPanelInput.Mode?
        controller.makeInputPanel = { mode, _ in receivedMode = mode; return NSPanel() }
        defer { controller.stop() }
        let submenu = try #require(item("menu.startFor", in: controller.menu).submenu)
        let entry = try item("menu.startUntil", in: submenu)
        #expect(entry.submenu == nil)
        #expect(entry.title == "時刻を指定…")
        submenu.performActionForItem(at: submenu.index(of: entry))
        #expect(receivedMode == .time && controller.inputPanel != nil)
        #expect(!fixture.model.status.isBlocking)
    }

    @Test("SPEC-MENU-002 時間条件なしの開始は保存したタイマーと時刻を使わずバッテリー条件を保つ")
    func startWithoutTimeLimit() throws {
        let fixture = AppFixture()
        fixture.model.launch()
        let model = settings(fixture.model)
        model.change(\.timerEnabled, to: true)
        model.change(\.specifiedTimeEnabled, to: true)
        let before = fixture.model.settings
        let controller = menu(model)
        let entry = try item("menu.startNoTimeLimit", in: controller.menu)
        controller.menu.performActionForItem(at: controller.menu.index(of: entry))
        #expect(fixture.model.status.isBlocking)
        #expect(fixture.model.status.session?.timeLimit == nil)
        #expect(fixture.model.status.batteryCondition != nil)
        #expect(fixture.model.settings == before)
    }

    private func settings(_ app: AppModel) -> SettingsModel {
        SettingsModel(app: app, helper: .init(
            state: { .installed }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
    }

    private func menu(_ settings: SettingsModel) -> MenuBarController {
        let controller = MenuBarController(settings: settings, isOnACPower: { false })
        controller.configureShortcut = { _ in }
        controller.refresh()
        return controller
    }

    private func item(_ id: String, in menu: NSMenu) throws -> NSMenuItem {
        try #require(menu.items.first { $0.identifier?.rawValue == id })
    }
}
