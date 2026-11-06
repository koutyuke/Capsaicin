import AppKit
import CapsaicinCore
import CapsaicinCoreTesting
import Testing

@MainActor
struct MenuBarTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "ja_JP")
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    @Test("SPEC-MENU-001 SPEC-MENU-002 停止中は開始・時間・時刻・設定・終了を並べる")
    func stopped() {
        let fixture = makeFixture()
        fixture.model.launch()
        let rows = rows(fixture)
        #expect(rows.map(\.id) == ["menu.header.idle", "menu.start", "menu.startFor", "menu.startUntil",
                                   "separator.footer", "menu.settings", "menu.quit"])
        #expect(rows[1].subtitle == nil)
        #expect(rows[2].children.map(\.command) == [15, 30, 60, 120, 240, 480]
            .map { .start(.timer(TimerDuration(minutes: $0)!)) }
            + [nil, .durationPanel])
        var settings = fixture.model.settings
        settings.batteryConditionEnabled = false
        fixture.model.changeSettings(settings)
        #expect(self.rows(fixture)[1].subtitle == "手動でオフにするまで")
    }

    @Test("SPEC-MENU-004 抑止中は時刻と残り分を示し、電源の変化を反映する")
    func active() throws {
        let fixture = makeFixture()
        fixture.model.launch()
        try fixture.model.requestStart(from: .menu, override: .timer(#require(TimerDuration(minutes: 90))))
        let initial = rows(fixture)
        #expect(initial.map(\.id) == ["menu.header.active", "menu.status.until", "menu.status.battery",
                                      "menu.stop", "separator.footer", "menu.settings", "menu.quit"])
        #expect(initial[1].title == "1:30まで（残り1時間30分）")
        #expect(rows(fixture, now: Date(timeIntervalSince1970: 120))[1].title == "1:30まで（残り1時間28分）")
        fixture.system.powerState = PowerState(batteryLevel: 80, isOnACPower: true)
        #expect(rows(fixture)[2].title == "電源アダプタ接続中（残量低下でも継続）")
        #expect(initial[2].title == "バッテリー残量20%未満でオフ")
    }

    @Test("SPEC-MENU-001 SPEC-MENU-004 警告は状態の先頭、Karabiner の案内は末尾に置く")
    func warnings() {
        let fixture = makeFixture()
        fixture.model.launch()
        fixture.model.requestStart(from: .menu)
        fixture.system.failing = [.setLEDLit(false), .saveRecord]
        fixture.model.requestStop(from: .menu)
        fixture.model.isKarabinerRunning = true
        let rows = rows(fixture)
        #expect(rows.prefix(3).map(\.id) == [
            "menu.header.idle",
            "menu.warning.unalignedLed.title",
            "menu.warning.stateSaveFailed.title",
        ])
        #expect(rows.suffix(5).map(\.id) == [
            "separator.karabiner",
            "menu.karabiner.title",
            "separator.footer",
            "menu.settings",
            "menu.quit",
        ])
        #expect(rows[1].isWarning)
        #expect(rows[1].command == nil)
        #expect(rows[rows.count - 4].subtitle == "LEDが消灯する場合があります")
    }

    @Test("SPEC-MENU-004 制御の向きとヘルパーの修復を区別する", arguments: [MisalignmentDirection.leftApplied, .notApplied])
    func helperWarning(direction: MisalignmentDirection) {
        let status = BlockingStatus(session: nil, batteryCondition: nil,
                                    misalignments: [.systemSleepDisabled: direction], isRecordUnsaved: false)
        let rows = MenuContent.make(status: status, settings: Settings(), isOnACPower: false, karabiner: false,
                                    now: Date(timeIntervalSince1970: 0), calendar: calendar, bundle: bundle())
        #expect(rows[1].title == (direction == .leftApplied ? "スリープを止める設定が残っています" : "一部のスリープを防止できていません"))
        #expect(rows[1].subtitle == "設定の「ヘルパー」で修復できます")
    }

    @Test("SPEC-MENU-003 時間は1分から24時間、設定がオフなら初期値を使う")
    func durationInput() throws {
        var settings = Settings()
        settings.timerDuration = try #require(TimerDuration(minutes: 125))
        var input = StartPanelInput(mode: .duration, settings: settings, now: .distantPast, calendar: calendar)
        #expect(input.hours == "1" && input.minutes == "0")
        settings.timerEnabled = true
        input = StartPanelInput(mode: .duration, settings: settings, now: .distantPast, calendar: calendar)
        #expect(input.hours == "2" && input.minutes == "5")
        for (hours, minutes, valid) in [("0", "0", false), ("24", "1", false), ("0", "1", true),
                                        ("24", "0", true), ("1", "60", false), ("abc", "0", false)]
        {
            input.hours = hours
            input.minutes = minutes
            #expect((input.startOverride(calendar: calendar) != nil) == valid)
        }
        input.hours = "1"
        input.minutes = "0"
        input.stepMinutes(5)
        #expect(input.hours == "1" && input.minutes == "5")
        input.stepMinutes(-5)
        #expect(input.hours == "1" && input.minutes == "0")
        input.hours = "24"
        input.stepMinutes(5)
        #expect(input.hours == "24" && input.minutes == "0")
        input.hours = "0"
        input.minutes = "1"
        input.stepMinutes(-5)
        #expect(input.hours == "0" && input.minutes == "1")
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
        let controller = MenuBarController(model: fixture.model, isOnACPower: { false })
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
                         karabiner: fixture.model.isKarabinerRunning,
                         now: now, calendar: calendar, bundle: bundle())
    }

    private func makeFixture() -> AppFixture {
        let fixture = AppFixture()
        fixture.system.now = Date(timeIntervalSince1970: 0)
        fixture.system.calendar = calendar
        return fixture
    }

    private func bundle() -> Bundle {
        let products = Bundle(for: MenuCatalogLocator.self).bundleURL.deletingLastPathComponent()
        return Bundle(url: products.appending(path: "Capsaicin.app"))!
    }
}

private final class MenuCatalogLocator: NSObject {}
