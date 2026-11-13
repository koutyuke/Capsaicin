import AppKit
import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinPlatform
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct SettingsTests {
    @Test("SPEC-SET-005 閉じたときの動作を子の行なしの1行で表示する")
    func unifiedLidRow() {
        let rows = SettingsSleepRow.rows(settings: CapsaicinCore.Settings(),
                                         capabilities: MachineCapabilities(hasLid: true, hasInternalBattery: true),
                                         helper: .installed, brightnessUnavailable: false)
        #expect(rows.map(\.key) == ["display", "lidClose"])
    }

    @Test("SPEC-SET-005 保存値を表示し、ヘルパー不足でも操作でき、説明の先頭に注意を出す")
    func sleepRows() throws {
        var settings = CapsaicinCore.Settings()
        settings.blocksDisplaySleep = false
        settings.blocksManualSleep = true
        let capabilities = MachineCapabilities(hasLid: true, hasInternalBattery: true)
        let rows = SettingsSleepRow.rows(settings: settings, capabilities: capabilities, helper: .installed,
                                         brightnessUnavailable: false)
        #expect(rows.map(\.key) == ["display", "lidClose"])
        #expect(rows.map(\.symbol) == ["display", "laptopcomputer"])
        let display = try #require(rows.first)
        #expect(display.state == .editable(isOn: false))
        #expect(!display.isOn)
        settings.lidCloseDisplay = .keepOn
        let missing = SettingsSleepRow.rows(settings: settings, capabilities: capabilities, helper: .partial,
                                            brightnessUnavailable: false)
        #expect(missing[0].state == .editable(isOn: false))
        #expect(missing[1].state == .onWithoutHelper)
        #expect(missing[1].isOn)
        #expect(missing[1].help == SettingsSection.sleep.text("helperNotReady")
            + SettingsSection.sleep.text("lidClose.help"))
    }

    @Test("SPEC-SET-005 SPEC-SET-006 蓋のある Mac はポップアップ、ない Mac はスイッチの行になる", arguments: [true, false])
    func hardware(laptop: Bool) {
        let settings = CapsaicinCore.Settings()
        let capabilities = MachineCapabilities(hasLid: laptop, hasInternalBattery: laptop)
        let rows = SettingsSleepRow.rows(settings: settings, capabilities: capabilities, helper: .notInstalled,
                                         brightnessUnavailable: false)
        #expect(rows.map(\.key) == ["display", laptop ? "lidClose" : "manual"])
        #expect(rows[1].symbol == (laptop ? "laptopcomputer" : "powersleep"))
        #expect(rows[1].setting == (laptop ? nil : \.blocksManualSleep))
        #expect(rows[1].help == SettingsSection.sleep.text(laptop ? "lidClose.help" : "manual.help"))
        let release = SettingsReleasePresentation(settings: settings, capabilities: capabilities)
        #expect(release.showsBattery == laptop)
        #expect(!release.timerEnabled && !release.timeEnabled && release.batteryEnabled)
    }

    @Test("SPEC-SET-005 SPEC-HLP-001 設置中は選択を表示して保存せず、成功後だけ2値を1回で保存する",
          arguments: [HelperInstallationState.notInstalled, .partial],
          [SettingsLidCloseChoice.turnOff, .zeroBrightness, .keepOn])
    func installation(state: HelperInstallationState, choice: SettingsLidCloseChoice) async {
        let fixture = AppFixture()
        var installed = state
        var completed = false
        let model = SettingsModel(
            app: fixture.model,
            helper: SettingsHelperActions(state: { installed }, perform: { operation in
                #expect(operation == (state == .partial ? .repair : .install))
                #expect(!fixture.model.settings.blocksManualSleep)
                #expect(fixture.savedSettings.isEmpty)
                installed = .installed
                return .success
            }, completed: { _, _ in completed = true }),
        )
        model.confirm = { _, fromSetting in
            #expect(fromSetting && model.pendingManual && model.isBusy)
            #expect(model.lidCloseChoice == choice)
            #expect(!fixture.model.settings.blocksManualSleep)
            #expect(model.sleepRows[0].state == .editable(isOn: true))
            await model.changeLidClose(to: .sleep)
            #expect(model.lidCloseChoice == choice)
            model.change(\.timerEnabled, to: true)
            fixture.savedSettings.removeAll()
            return true
        }
        await model.changeLidClose(to: choice)
        #expect(completed && fixture.model.settings.blocksManualSleep)
        #expect(model.sleepRows[1].state == .editable(isOn: true))
        #expect(model.lidCloseChoice == choice)
        #expect(fixture.model.settings.lidCloseDisplay.rawValue == choice.rawValue)
        #expect(fixture.model.settings.timerEnabled)
        #expect(fixture.savedSettings == [fixture.model.settings])
        #expect(!model.pendingManual && !model.isBusy)
    }

    @Test("SPEC-SET-005 SPEC-HLP-001 確認取り消し・認証取り消し・失敗は2値を保存せずスリープに戻す",
          arguments: [0, 1, 2], [HelperInstallationState.notInstalled, .partial])
    func installationCancellation(outcome: Int, state: HelperInstallationState) async {
        let fixture = AppFixture()
        var errors = 0
        var performed = false
        let model = SettingsModel(
            app: fixture.model,
            helper: SettingsHelperActions(state: { state }, perform: { operation in
                #expect(operation == (state == .partial ? .repair : .install))
                performed = true
                return outcome == 1 ? .cancelled : .failure(
                    operation: operation,
                    details: "test",
                    needsSleepDisabledReadback: false,
                )
            }, completed: { _, _ in }),
        )
        model.confirm = { _, _ in outcome != 0 }
        model.showError = { _, _ in errors += 1 }
        let before = fixture.model.settings
        await model.changeLidClose(to: .keepOn)
        #expect(!fixture.model.settings.blocksManualSleep && fixture.savedSettings.isEmpty)
        #expect(fixture.model.settings == before)
        #expect(model.lidCloseChoice == .sleep)
        #expect(!model.pendingManual && !model.isBusy)
        #expect(performed == (outcome != 0))
        #expect(errors == (outcome == 2 ? 1 : 0))
    }

    @Test("SPEC-HLP-004 セクションからの設置では設定を変えず、削除結果を所有の処理に渡す")
    func management() async {
        let fixture = AppFixture()
        var operations: [HelperManagementOperation] = []
        let model = SettingsModel(
            app: fixture.model,
            helper: SettingsHelperActions(state: { .installed }, perform: { _ in
                .success
            }, completed: { operation, _ in operations.append(operation) }),
        )
        model.confirm = { _, fromSetting in #expect(!fromSetting); return true }
        await model.manage(.install)
        await model.manage(.repair)
        await model.manage(.remove)
        #expect(operations == [.install, .repair, .remove])
        #expect(fixture.savedSettings.isEmpty)
    }

    @Test("SPEC-BLK-009 反映が戻されたら表示も戻し、エラーを1回通知する")
    func rollback() {
        let fixture = AppFixture(displayBlocked: false)
        fixture.model.launch()
        fixture.model.requestStart(from: .menu)
        fixture.system.failing = [.createAssertion(.preventUserIdleDisplaySleep)]
        let model = SettingsModel(
            app: fixture.model,
            helper: SettingsHelperActions(state: { .installed }, perform: { _ in .cancelled }, completed: { _, _ in }),
        )
        var errors = 0
        model.showError = { _, _ in errors += 1 }
        model.change(\.blocksDisplaySleep, to: true)
        #expect(!model.app.settings.blocksDisplaySleep)
        #expect(fixture.savedSettings.isEmpty && errors == 1)
    }

    @Test("SPEC-SET-001 前回のセクションと固定サイズ、標準タイトルバーを使い、フルスクリーンの上にも開ける")
    func window() throws {
        _ = NSApplication.shared
        let defaults = try #require(UserDefaults(suiteName: "SettingsTests-" + UUID().uuidString))
        let selection = SettingsSelection(defaults: defaults)
        #expect(selection.section == .general)
        selection.section = .led
        #expect(SettingsSelection(defaults: defaults).section == .led)
        defaults.set("sleep", forKey: "settingsSection")
        #expect(SettingsSelection(defaults: defaults).section == .sleep)
        defaults.set("release", forKey: "settingsSection")
        #expect(SettingsSelection(defaults: defaults).section == .general)
        defaults.removeObject(forKey: "settingsSection")
        let model = makeModel()
        let controller = SettingsWindowController(
            model: model,
            hotkey: HotkeyController(save: { _ in true }),
            quit: {},
            defaults: defaults,
        )
        let window = try #require(controller.window)
        #expect(window.frame.size == NSSize(width: 720, height: 500))
        #expect(window.styleMask.contains(.titled) && !window.styleMask.contains(.resizable))
        #expect(window.styleMask.contains(.fullSizeContentView))
        #expect(window.titleVisibility == .visible)
        #expect(window.toolbar != nil)
        #expect(window.toolbarStyle == .unified)
        // ツールバーのラベルの行を持たせず、上端を Xcode の設定ウインドウと同じ 52 pt にする。
        #expect(window.frame.height - window.contentLayoutRect.height == 52)
        #expect(window.standardWindowButton(.miniaturizeButton)?.isEnabled == false)
        #expect(window.standardWindowButton(.zoomButton)?.isEnabled == false)
        #expect(window.title == SettingsSection.general.title)
        // 別の Space に表示中の画面を引っ越させず、その Space へ移れるようにする。
        #expect(window.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(window.collectionBehavior.isDisjoint(with: [.moveToActiveSpace, .canJoinAllSpaces]))
        window.close()
    }

    @Test("SPEC-SET-001 SPEC-UI-005 SPEC-UI-011 配置と矢印移動を確かめ、全セクションをアプリ起動なしで描画する")
    func render() async throws {
        _ = NSApplication.shared
        let app = try appBundle()
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/settings")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let defaults = try #require(UserDefaults(suiteName: "SettingsRender-" + UUID().uuidString))
        let selection = SettingsSelection(defaults: defaults)
        defer { defaults.removeObject(forKey: "settingsSection") }
        var quits = 0
        #expect(SettingsSection.allCases.map(\.rawValue) == ["general", "sleep", "led", "controls", "helper", "about"])
        for section in SettingsSection.allCases {
            #expect(section.title != "title")
            selection.section = section
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let window = SettingsWindowController.makeWindow(rootView: SettingsView(
                    model: makeModel(),
                    hotkey: HotkeyController(save: { _ in true }),
                    selection: selection,
                    quit: { quits += 1 },
                    bundle: app,
                ).environment(\.colorScheme, name == "light" ? .light : .dark)
                    .environment(\.accessibilityEnabled, true)
                    .environment(\.controlActiveState, .key), selection: selection)
                defer { window.close() }
                window.appearance = NSAppearance(named: appearance)
                await layout(window)
                try saveRendering(window, to: output.appendingPathComponent("\(section.rawValue)-\(name).png"))
                try checkRendering(window, section: section, app: app)
                if section == .general, name == "light" {
                    try await checkSidebar(window, selection: selection)
                }
                if section == .sleep {
                    try await saveBottom(window, to: output.appendingPathComponent("sleep-\(name)-bottom.png"))
                }
            }
        }
        #expect(quits == 2)
    }

    @Test("SPEC-UI-011 DEC-KEY-002 セクションのカタログと依存ライセンスを配布物に含める")
    func resources() throws {
        let app = try appBundle()
        for section in SettingsSection.allCases {
            let table = "Settings" + section.rawValue.capitalized
            #expect(app.url(forResource: table, withExtension: "strings", subdirectory: "ja.lproj") != nil)
            #expect(app.localizedString(forKey: "title", value: nil, table: table) == section.title)
        }
        let license = try #require(app.url(forResource: "KeyboardShortcuts-LICENSE", withExtension: "txt"))
        #expect(try String(contentsOf: license, encoding: .utf8).contains("MIT License"))
    }
}

extension SettingsTests {
    @Test("SPEC-SET-002 SPEC-SYS-004 統合した条件の文言を同じテーブルから引き、ディスプレイの表記をそろえる")
    func sleepResources() {
        #expect(SettingsSection.sleep.title == "スリープ")
        for key in ["behavior.group.title", "release.group.title", "timer.label", "timer.duration.label",
                    "timer.duration.a11y", "hours", "minutes", "time.label", "time.help", "time.value.label",
                    "battery.label", "battery.threshold.label", "battery.threshold.value",
                    "battery.ignoreOnAdapter.label",
                    "lidClose.label", "lidClose.sleep", "lidClose.turnOff", "lidClose.zeroBrightness",
                    "lidClose.keepOn",
                    "lidClose.help", "brightnessUnavailable", "brightnessUnavailable.a11y"]
        {
            #expect(SettingsSection.sleep.text(key) != key)
        }
        for key in ["manualAndLid.label", "manualAndLid.help", "lidDisplay.label", "lidDisplay.help",
                    "lidDisplay.turnOff", "lidDisplay.keepOn", "timer.duration.help", "time.value.help",
                    "battery.help", "battery.threshold.help", "battery.ignoreOnAdapter.help"]
        {
            #expect(SettingsSection.sleep.text(key) == key)
        }
        #expect(SettingsSection.helper.text("helperInstall.lidClose.title")
            == "ディスプレイを閉じてもスリープさせないには、ヘルパーのインストールが必要です")
        #expect(SettingsSection.helper.text("helperInstall.manualAndLid.title") == "helperInstall.manualAndLid.title")
    }
}

extension SettingsTests {
    func makeModel(hasLid: Bool = true, hasBattery: Bool = true, conditionsEnabled: Bool? = nil) -> SettingsModel {
        let system = FakeSystem()
        var settings = CapsaicinCore.Settings()
        if let conditionsEnabled {
            settings.timerEnabled = conditionsEnabled
            settings.specifiedTimeEnabled = conditionsEnabled
            settings.batteryConditionEnabled = conditionsEnabled
        }
        let app = AppModel(controller: BlockingController(settings: settings,
                                                          capabilities: MachineCapabilities(
                                                              hasLid: hasLid,
                                                              hasInternalBattery: hasBattery,
                                                          ),
                                                          ports: system.ports), saveSettings: { _ in })
        app.launchAgentStatus = .ready
        return SettingsModel(
            app: app,
            helper: SettingsHelperActions(state: { .installed }, perform: { _ in .cancelled }, completed: { _, _ in }),
        )
    }
}
