import AppKit
import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinPlatform
import Testing

@MainActor
struct MenuBarTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "ja_JP")
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    @Test("SPEC-MENU-001 SPEC-MENU-002 停止中は開始・時間指定・クイック設定・設定・終了を並べる")
    func stopped() {
        let fixture = makeFixture()
        fixture.model.launch()
        let rows = rows(fixture)
        #expect(rows.map(\.id) == ["menu.header.idle", "menu.start", "separator.start", "menu.startNoTimeLimit",
                                   "menu.startFor", "separator.sleep", "menu.quickSettings",
                                   "separator.footer", "menu.settings", "menu.quit"])
        #expect(rows[1].subtitle == "オフにするまで")
        #expect(rows[1].command == .start(nil))
        #expect(rows[3].command == .start(.noTimeLimit))
        #expect(rows[4].children.map(\.command) == [nil] + [15, 30, 60, 120, 240, 480]
            .map { .start(.timer(TimerDuration(minutes: $0)!)) }
            + [.durationPanel, nil, .timePanel])
        #expect(rows.allSatisfy { !$0.isChecked })
        var settings = fixture.model.settings
        settings.batteryConditionEnabled = false
        fixture.model.changeSettings(settings)
        #expect(self.rows(fixture)[1].subtitle == "オフにするまで")
    }

    @Test("SPEC-MENU-001 SPEC-MENU-004 抑止中は状態・オフ・時間変更・クイック設定を並べ、電源の変化を反映する")
    func active() throws {
        let fixture = makeFixture()
        fixture.model.launch()
        try fixture.model.requestStart(from: .menu, override: .timer(#require(TimerDuration(minutes: 90))))
        let initial = rows(fixture)
        #expect(initial.map(\.id) == ["menu.header.active", "menu.status.until", "menu.status.battery",
                                      "menu.stop", "menu.changeTime", "separator.sleep", "menu.quickSettings",
                                      "separator.footer", "menu.settings", "menu.quit"])
        #expect(initial[1].title == "1:30まで（残り1時間30分）")
        #expect(rows(fixture, now: Date(timeIntervalSince1970: 120))[1].title == "1:30まで（残り1時間28分）")
        fixture.system.powerState = PowerState(batteryLevel: 80, isOnACPower: true)
        #expect(rows(fixture)[2].title == "電源アダプタ接続中（残量低下でも継続）")
        #expect(initial[2].title == "バッテリー残量20%未満でオフ")
        #expect(initial[3].command == .stop)
        #expect(initial[4].children.map(\.command) == [nil] + [15, 30, 60, 120, 240, 480]
            .map { .start(.timer(TimerDuration(minutes: $0)!)) }
            + [.durationPanel, nil, .timePanel, nil, .start(.noTimeLimit)])
    }

    @Test("SPEC-MENU-004 制御の向きとヘルパーの修復を区別する", arguments: [MisalignmentDirection.leftApplied, .notApplied])
    func helperWarning(direction: MisalignmentDirection) {
        let status = BlockingStatus(session: nil, batteryCondition: nil,
                                    misalignments: [.systemSleepDisabled: direction], isRecordUnsaved: false)
        let rows = MenuContent.make(status: status, settings: Settings(), isOnACPower: false, hasInternalBattery: true,
                                    sleepRows: [],
                                    now: Date(timeIntervalSince1970: 0), calendar: calendar, bundle: bundle())
        #expect(rows[1].title == (direction == .leftApplied ? "スリープを止める設定が残っています" : "一部のスリープを防止できていません"))
        #expect(rows[1].subtitle == "設定の「ヘルパー」で修復できます")
    }

    @Test("SPEC-MENU-003 時間は1分から24時間、設定がオフなら初期値を使う")
    func durationInput() throws {
        var settings = Settings()
        settings.timerDuration = try #require(TimerDuration(minutes: 125))
        var input = StartPanelInput(mode: .duration, settings: settings, now: .distantPast, calendar: calendar)
        #expect(input.duration.hours == "1" && input.duration.minutes == "0")
        settings.timerEnabled = true
        input = StartPanelInput(mode: .duration, settings: settings, now: .distantPast, calendar: calendar)
        #expect(input.duration.hours == "2" && input.duration.minutes == "5")
        for (hours, minutes, valid) in [("0", "0", false), ("24", "1", false), ("0", "1", true),
                                        ("24", "0", true), ("1", "60", false), ("abc", "0", false)]
        {
            input.duration.hours = hours
            input.duration.minutes = minutes
            #expect((input.startOverride(calendar: calendar) != nil) == valid)
        }
    }

    @Test("SPEC-MENU-003 指定時刻の初期値と翌日判定は Core と同じ規則を使う")
    func timeInput() throws {
        let now = Date(timeIntervalSince1970: 23 * 3600)
        var settings = Settings()
        settings.specifiedTime = try #require(TimeOfDay(hour: 23, minute: 30))
        var input = StartPanelInput(mode: .time, settings: settings, now: now, calendar: calendar)
        #expect(input.isNextDay(now: now, calendar: calendar))
        settings.specifiedTimeEnabled = true
        input = StartPanelInput(mode: .time, settings: settings, now: now, calendar: calendar)
        #expect(!input.isNextDay(now: now, calendar: calendar))
        #expect(input.startOverride(calendar: calendar) == .specifiedTime(settings.specifiedTime))
    }

    @Test("SPEC-HUD-001 メニューとホットキー、自動解除だけを HUD に渡す",
          arguments: [RequestOrigin.menu, .hotkey, .cli])
    func hudOrigins(origin: RequestOrigin) {
        #expect(MenuHUDRouting.shouldPresent(.started(.user(origin))) == (origin != .cli))
        #expect(MenuHUDRouting.shouldPresent(.timeLimitReplaced(origin)) == (origin == .menu))
        #expect(MenuHUDRouting.shouldPresent(.startRejected(.user(origin), .recordNotSaved)) == (origin != .cli))
        #expect(MenuHUDRouting.shouldPresent(.released(.user(origin))) == (origin != .cli))
        #expect(MenuHUDRouting.shouldPresent(.released(.timeLimit(.timer))))
        #expect(MenuHUDRouting.shouldPresent(.released(.timeLimit(.specifiedTime))))
        #expect(MenuHUDRouting.shouldPresent(.released(.batteryBelowThreshold)))
        #expect(!MenuHUDRouting.shouldPresent(.warningsChanged))
        #expect(!MenuHUDRouting.shouldPresent(.released(.quit)))
        #expect(!MenuHUDRouting.shouldPresent(.started(.resume)))
        #expect(!MenuHUDRouting.shouldPresent(.startRejected(.resume, .recordNotSaved)))
    }

    @Test("SPEC-MENU-001 SPEC-MENU-004 NSMenu の項目を保ったまま更新し、割り当て済みのキーだけを示す")
    func nativeMenu() throws {
        let fixture = makeFixture()
        fixture.model.launch()
        let controller = MenuBarController(settings: settingsModel(fixture), isOnACPower: { false })
        controller.configureShortcut = { item in
            item.keyEquivalent = "c"
            item.keyEquivalentModifierMask = [.control, .option, .command]
        }
        controller.refresh()
        let start = try #require(controller.menu.items.first { $0.identifier?.rawValue == "menu.start" })
        #expect(start.keyEquivalent == "c")
        #expect(start.keyEquivalentModifierMask == [.control, .option, .command])
        #expect(start.isEnabled)
        #expect(start.view == nil)
        controller.configureShortcut = { _ in }
        controller.refresh()
        #expect(controller.menu.items[1] === start)
        #expect(start.keyEquivalent.isEmpty)
        fixture.model.requestStart(from: .menu)
        controller.refresh()
        let status = try #require(controller.menu.items.first { $0.identifier?.rawValue == "menu.status.battery" })
        #expect(!status.isEnabled)
        #expect(status.view == nil)
        #expect(controller.menu.items.suffix(2).map(\.keyEquivalent) == [",", "q"])
    }

    @Test("SPEC-MENU-005 抑止の状態に合わせてボタンの画像を替え、15 pt Regular のテンプレートを保つ")
    func statusIcon() throws {
        _ = NSApplication.shared
        let fixture = makeFixture()
        fixture.model.launch()
        let controller = MenuBarController(settings: settingsModel(fixture), isOnACPower: { false })
        controller.configureShortcut = { _ in }
        defer { controller.stop() }
        controller.start()
        let button = try #require(controller.statusItem?.button)
        let symbolBundle = Bundle(for: MenuBarController.self)
        func image(_ name: String) throws -> Data {
            let image = try #require(NSImage(symbolName: name, bundle: symbolBundle, variableValue: 0)?
                .withSymbolConfiguration(.init(pointSize: 15, weight: .regular)))
            return try #require(image.tiffRepresentation)
        }
        let idle = try image("custom.capsaicin.led")
        let active = try image("custom.capsaicin.led.fill")
        #expect(idle != active)
        #expect(button.image?.tiffRepresentation == idle)
        #expect(button.image?.isTemplate == true)
        fixture.model.requestStart(from: .menu)
        #expect(fixture.model.status.isBlocking)
        controller.refresh()
        #expect(button.image?.tiffRepresentation == active)
        #expect(button.image?.isTemplate == true)
        fixture.model.requestStop(from: .menu)
        #expect(!fixture.model.status.isBlocking)
        controller.refresh()
        #expect(button.image?.tiffRepresentation == idle)
        #expect(button.image?.isTemplate == true)
    }

    @Test("SPEC-MENU-006 起動時と設定変更時に、同じアイコンの表示だけを切り替える", arguments: [true, false])
    func visibility(initiallyVisible: Bool) throws {
        _ = NSApplication.shared
        let fixture = makeFixture()
        fixture.model.launch()
        var settings = fixture.model.settings
        settings.showsMenuBarIcon = initiallyVisible
        fixture.model.changeSettings(settings)
        let controller = MenuBarController(settings: settingsModel(fixture), isOnACPower: { false })
        controller.configureShortcut = { _ in }
        fixture.model.onStatusChange = { _ in controller.refresh() }
        defer {
            fixture.model.onStatusChange = nil
            controller.stop()
        }
        controller.start()
        let item = try #require(controller.statusItem)
        #expect(item.isVisible == initiallyVisible)
        for visible in [!initiallyVisible, initiallyVisible] {
            settings.showsMenuBarIcon = visible
            fixture.model.changeSettings(settings)
            #expect(controller.statusItem === item)
            #expect(item.isVisible == visible)
        }
    }

    @Test("SPEC-HUD-002 指定時刻で解除した出来事には直前のセッションを添える")
    func previousSession() throws {
        let fixture = makeFixture()
        fixture.model.launch()
        try fixture.model.requestStart(from: .menu, override: .specifiedTime(#require(TimeOfDay(hour: 4, minute: 0))))
        let session = fixture.model.status.session
        var previous: BlockingSession?
        fixture.model.onEvent = { event, oldSession in
            if case .released = event {
                previous = oldSession
            }
        }
        fixture.system.advance(by: 4 * 3600)
        fixture.model.timePassed()
        #expect(previous == session)
        #expect(previous != nil)
        #expect(!fixture.model.status.isBlocking)
    }

    private func rows(_ fixture: AppFixture, now: Date = Date(timeIntervalSince1970: 0)) -> [MenuEntry] {
        MenuContent.make(status: fixture.model.status, settings: fixture.model.settings,
                         isOnACPower: fixture.system.powerState.isOnACPower,
                         hasInternalBattery: fixture.model.capabilities.hasInternalBattery,
                         sleepRows: settingsModel(fixture).sleepRows,
                         now: now, calendar: calendar, bundle: bundle())
    }

    private func makeFixture() -> AppFixture {
        let fixture = AppFixture()
        fixture.system.now = Date(timeIntervalSince1970: 0)
        fixture.system.calendar = calendar
        return fixture
    }

    private func settingsModel(_ fixture: AppFixture) -> SettingsModel {
        SettingsModel(app: fixture.model, helper: SettingsHelperActions(
            state: { .installed }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
    }

    private func bundle() -> Bundle {
        let products = Bundle(for: MenuCatalogLocator.self).bundleURL.deletingLastPathComponent()
        return Bundle(url: products.appending(path: "Capsaicin.app"))!
    }
}

extension MenuBarTests {
    @Test("SPEC-UI-011 SPEC-MENU-002 SPEC-MENU-003 メニューとパネルの文言をString Catalogから読む")
    func redesignResources() {
        let expected = [
            "menu.startFor": "時間・時刻を指定してオン",
            "menu.changeTime": "オフにする時刻を変更",
            "menu.header.fromNow": "今から",
            "menu.startFor.custom": "時間を入力…",
            "menu.startUntil": "時刻を指定…",
            "menu.noTimeLimit": "時間指定なし",
            "menu.startNoTimeLimit": "時間指定なしでオン",
            "menu.quickSettings": "クイック設定",
            "menu.quickSettings.batteryDisabled": "バッテリー残量ではオフにしない",
            "menu.sleep.lidClose.a11y": "%1$@、%2$@",
            "menu.start.subtitle.timer": "%@後にオフ",
            "menu.start.subtitle.until": "%@にオフ",
            "menu.start.subtitle.nextDay": "明日%@にオフ",
            "menu.start.subtitle.none": "オフにするまで",
            "menu.battery": "バッテリー残量%d%%未満でオフにする",
            "menu.battery.subtitle": "電源アダプタ接続中は除く",
            "panel.duration.title": "時間を指定してオン",
            "panel.time.title": "時刻を指定してオン",
            "panel.changeTime.title": "オフにする時刻を変更",
            "panel.start": "オンにする",
            "panel.change": "変更",
            "panel.duration.until": "%@にオフ",
        ]
        for (key, value) in expected {
            #expect(MenuContent.text(key, bundle: bundle()) == value)
        }
        #expect(MenuContent.text("menu.startAt", bundle: bundle()) == "menu.startAt")
    }

    @Test("SPEC-MENU-001 SPEC-MENU-004 SPEC-LED-005 警告は状態の先頭に残し、キー配列の案内は表示しない")
    func warnings() {
        let fixture = makeFixture()
        fixture.model.launch()
        fixture.model.requestStart(from: .menu)
        fixture.system.failing = [.setLEDLit(false), .saveRecord]
        fixture.model.requestStop(from: .menu)
        fixture.model.hasVirtualKeyboard = true
        let rows = rows(fixture)
        #expect(rows.prefix(3).map(\.id) == [
            "menu.header.idle",
            "menu.warning.unalignedLed.title",
            "menu.warning.stateSaveFailed.title",
        ])
        #expect(!rows.contains { $0.id.contains("virtualKeyboard") })
        #expect(rows[1].isWarning)
        #expect(rows[1].command == nil)
        fixture.model.hasVirtualKeyboard = false
        #expect(!self.rows(fixture).contains { $0.id == "menu.virtualKeyboard.title" })
    }

    @Test("SPEC-LED-005 設定の案内もキー配列を変更するアプリと LED への影響を示す")
    func virtualKeyboardSettingsNotice() {
        let bundle = bundle()
        #expect(bundle.localizedString(forKey: "virtualKeyboard.label", value: nil, table: "SettingsLed")
            == "キー配列を変更するアプリが動作中")
        #expect(bundle.localizedString(forKey: "virtualKeyboard.help", value: nil, table: "SettingsLed")
            == "そのアプリがCaps LockのLEDを制御している場合、スリープ防止中もLEDが点灯しないことがあります。")
    }
}

private final class MenuCatalogLocator: NSObject {}
