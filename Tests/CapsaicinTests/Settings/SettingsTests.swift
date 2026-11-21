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

    @Test("SPEC-SET-005 保存値を表示し、ヘルパー不足でも標準を選べ、説明の先頭に注意を出す")
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
        // 項目名は「許可」なので、止めていない保存値でスイッチはオンになる。
        #expect(display.isOn)
        settings.lidCloseDisplay = .keepOn
        let missing = SettingsSleepRow.rows(settings: settings, capabilities: capabilities, helper: .requiresApproval,
                                            brightnessUnavailable: false)
        #expect(missing[0].state == .editable(isOn: false))
        #expect(missing[1].state == .onWithoutHelper)
        #expect(missing[1].isOn)
        #expect(missing[1].help.hasPrefix(SettingsSection.sleep.text("helperInactive")))
        #expect(missing[1].canSelect(.sleep) && !missing[1].canSelect(.keepOn))
    }

    @Test("SPEC-SET-005 SPEC-SET-006 ディスプレイを開閉できる Mac はポップアップ、それ以外はスイッチの行になる", arguments: [true, false])
    func hardware(laptop: Bool) {
        let settings = CapsaicinCore.Settings()
        let capabilities = MachineCapabilities(hasLid: laptop, hasInternalBattery: laptop)
        let rows = SettingsSleepRow.rows(settings: settings, capabilities: capabilities, helper: .installed,
                                         brightnessUnavailable: false)
        #expect(rows.map(\.key) == ["display", laptop ? "lidClose" : "manual"])
        #expect(rows[1].symbol == (laptop ? "laptopcomputer" : "powersleep"))
        #expect(rows[1].setting == (laptop ? nil : \.blocksManualSleep))
        #expect(rows[1].help == (laptop ? "" : SettingsSection.sleep.text("manual.help")))
        let release = SettingsReleasePresentation(settings: settings, capabilities: capabilities)
        #expect(release.showsBattery == laptop)
        #expect(!release.timerEnabled && !release.timeEnabled && release.batteryEnabled)
    }

    @Test("SPEC-HLP-001 確認取り消し・登録取り消し・失敗では保存値を変えず、失敗時だけエラーを出す",
          arguments: [0, 1, 2])
    func installationCancellation(outcome: Int) async {
        let fixture = AppFixture()
        var errors = 0
        var performed = false
        let model = SettingsModel(
            app: fixture.model,
            helper: SettingsHelperActions(state: { .notInstalled }, perform: { operation in
                #expect(operation == .install)
                performed = true
                return outcome == 1 ? .cancelled : .failure(
                    operation: operation,
                    details: "test",
                    needsSleepDisabledReadback: false,
                )
            }, completed: { _, _ in }),
        )
        model.confirm = { _ in outcome != 0 }
        model.showError = { _, _ in errors += 1 }
        let before = fixture.model.settings
        await model.manage(.install)
        #expect(!fixture.model.settings.blocksManualSleep && fixture.savedSettings.isEmpty)
        #expect(fixture.model.settings == before)
        #expect(model.lidCloseChoice == .sleep)
        #expect(!model.isBusy)
        #expect(performed == (outcome != 0))
        #expect(errors == (outcome == 2 ? 1 : 0))
    }

    @Test("SPEC-HLP-001 SPEC-HLP-004 設置では設定を変えず、設置と削除の成功を所有の処理に渡す")
    func management() async {
        let fixture = AppFixture()
        var state = HelperInstallationState.notInstalled
        var operations: [HelperManagementOperation] = []
        let model = SettingsModel(
            app: fixture.model,
            helper: SettingsHelperActions(state: { state }, perform: { operation in
                state = operation == .install ? .installed : .notInstalled
                return .success
            }, completed: { operation, _ in operations.append(operation) }),
        )
        model.confirm = { _ in true }
        await model.manage(.install)
        await model.manage(.remove)
        #expect(operations == [.install, .remove])
        #expect(fixture.savedSettings.isEmpty)
    }

    @Test("SPEC-BLK-009 反映が戻されたら表示も戻し、エラーを1回通知する")
    func rollback() {
        let fixture = AppFixture(displayBlocked: false)
        fixture.model.finishLaunching()
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
        selection.section = .feedback
        #expect(SettingsSelection(defaults: defaults).section == .feedback)
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
        #expect(SettingsSection.allCases.map(\.rawValue) == [
            "general",
            "sleep",
            "feedback",
            "controls",
            "helper",
            "about",
        ])
        for section in SettingsSection.allCases {
            #expect(section.title != "title")
            selection.section = section
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let window = SettingsWindowController.makeWindow(rootView: SettingsView(
                    model: makeModel(),
                    hotkey: HotkeyController(save: { _ in true }),
                    selection: selection,
                    quit: {},
                    bundle: app,
                ).environment(\.colorScheme, name == "light" ? .light : .dark)
                    .environment(\.accessibilityEnabled, true)
                    .environment(\.controlActiveState, .key), selection: selection)
                defer { window.close() }
                window.appearance = NSAppearance(named: appearance)
                await layout(window)
                try saveRendering(window, to: output.appendingPathComponent("\(section.rawValue)-\(name).png"))
                if section == .about {
                    try await saveBottom(window, to: output.appendingPathComponent("about-\(name)-bottom.png"))
                }
                try checkRendering(window, section: section, app: app)
                if section == .general, name == "light" {
                    try await checkSidebar(window, selection: selection)
                }
                if section == .sleep {
                    try await saveBottom(window, to: output.appendingPathComponent("sleep-\(name)-bottom.png"))
                }
            }
        }
    }

    @Test("SPEC-UI-011 DEC-KEY-002 セクションのカタログと依存ライセンスを配布物に含める")
    func resources() throws {
        let app = try appBundle()
        for section in SettingsSection.allCases {
            let table = "Settings" + section.rawValue.capitalized
            for language in ["en", "ja"] {
                #expect(app.url(forResource: table, withExtension: "strings", subdirectory: "\(language).lproj") != nil)
            }
            #expect(app.localizedString(forKey: "title", value: nil, table: table) == section.title)
        }
        let license = try #require(app.url(forResource: "KeyboardShortcuts-LICENSE", withExtension: "txt"))
        #expect(try String(contentsOf: license, encoding: .utf8).contains("MIT License"))
    }
}

extension SettingsTests {
    @Test("SPEC-HLP-004 SPEC-HLP-006 SPEC-SET-005 4状態とエラーの文言を英日で持ち、古い状態と修復のキーを残さない",
          arguments: ["en", "ja"])
    func helperResources(language: String) throws {
        let bundle = try localizedAppBundle(language)
        let helperKeys = [
            "status.notInstalled", "status.requiresApproval", "status.usable", "status.unavailable",
            "openSystemSettings.button", "intro.message", "status.requiresApproval.help", "helperInstall.message",
            "helperInstall.title", "error.helperInstall.message", "helperRemove.message", "helperRemove.manual.message",
            "error.helperTranslocated.title", "error.helperTranslocated.message",
            "error.helperRestore.title", "error.helperRestore.message",
        ]
        for key in helperKeys {
            let text = bundle.localizedString(forKey: key, value: nil, table: "SettingsHelper")
            #expect(!text.isEmpty && text != key)
            #expect(!text.localizedCaseInsensitiveContains("password") && !text.contains("パスワード"))
        }
        for key in ["status.partial", "status.installed", "helperRepair.button", "helperRepair.confirm",
                    "helperRepair.title", "helperRepair.message", "error.helperRepair.title",
                    "error.helperRepair.message"]
        {
            #expect(bundle.localizedString(forKey: key, value: nil, table: "SettingsHelper") == key)
        }
        for key in ["helperInactive", "helperInactive.a11y", "lidClose.helperRequired", "manual.helperRequired"] {
            #expect(bundle.localizedString(forKey: key, value: nil, table: "SettingsSleep") != key)
        }
        for key in [
            "helperNotReady",
            "helperNotEnabled",
            "helperNotInstalled",
            "helperRequiresApproval",
            "helperApprovalPending",
            "helperUnavailable",
            "helperRequired",
            "helperSettings.link",
        ].flatMap({ [$0, $0 + ".a11y"] }) {
            #expect(bundle.localizedString(forKey: key, value: nil, table: "SettingsSleep") == key)
        }
    }

    @Test("SPEC-SET-002 SPEC-SYS-004 統合した条件の文言を同じテーブルから引き、ディスプレイの表記をそろえる")
    func sleepResources() throws {
        let app = try appBundle()
        let japanese = try localizedAppBundle("ja")
        #expect(SettingsSection.sleep.title == app.localizedString(forKey: "title", value: nil, table: "SettingsSleep"))
        for key in ["behavior.group.title", "release.group.title", "timer.label", "timer.duration.label",
                    "timer.duration.a11y", "hours", "minutes", "time.label", "time.help", "time.value.label",
                    "battery.label", "battery.threshold.label", "battery.threshold.value",
                    "battery.ignoreOnAdapter.label",
                    "lidClose.label", "lidClose.sleep", "lidClose.turnOff", "lidClose.zeroBrightness",
                    "lidClose.keepOn",
                    "brightnessUnavailable", "brightnessUnavailable.a11y"]
        {
            #expect(japanese.localizedString(forKey: key, value: nil, table: "SettingsSleep") != key)
            #expect(SettingsSection.sleep.text(key) == app.localizedString(
                forKey: key,
                value: nil,
                table: "SettingsSleep",
            ))
        }
        for key in ["manualAndLid.label", "manualAndLid.help", "lidDisplay.label", "lidDisplay.help",
                    "lidDisplay.turnOff", "lidDisplay.keepOn", "timer.duration.help", "time.value.help",
                    "battery.help", "battery.threshold.help", "battery.ignoreOnAdapter.help", "lidClose.help"]
        {
            #expect(SettingsSection.sleep.text(key) == key)
        }
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
        return SettingsModel(
            app: app,
            helper: SettingsHelperActions(state: { .installed }, perform: { _ in .cancelled }, completed: { _, _ in }),
        )
    }
}
