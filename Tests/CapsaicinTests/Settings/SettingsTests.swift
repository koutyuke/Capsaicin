import AppKit
import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinPlatform
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct SettingsTests {
    @Test("SPEC-SET-005 表示規則はCoreに従い、含意・前提・ヘルパー不足を区別する")
    func sleepRows() throws {
        var settings = CapsaicinCore.Settings()
        settings.blocksIdleSleep = false
        settings.blocksDisplaySleep = true
        settings.blocksManualSleep = true
        let capabilities = MachineCapabilities(hasLid: true, hasInternalBattery: true, canBlockLidSleepAlone: true)
        let rows = SettingsSleepRow.rows(settings: settings, capabilities: capabilities, helper: .installed)
        let idle = try #require(rows.first)
        #expect(idle.state == .implied([.displaySleep, .manualSleep]))
        #expect(idle.isOn && !idle.isEnabled && !idle.dimsLabel)
        #expect(idle.help.contains(SettingsSection.sleep.text("implied.byDisplay")))
        #expect(idle.help.contains(SettingsSection.sleep.text("implied.byManual")))
        #expect(!settings.blocksIdleSleep)
        settings.blocksDisplaySleep = false
        let missing = SettingsSleepRow.rows(settings: settings, capabilities: capabilities, helper: .partial)
        #expect(missing[0].state == .editable(isOn: false))
        #expect(missing[2].state == .onWithoutHelper)
        #expect(missing[2].isEnabled)
        #expect(missing.last?.dimsLabel == true)
        #expect(missing.last?.isOn == true)
    }

    @Test("SPEC-SET-005 SPEC-SET-006 変種とハードウェアだけで行を選ぶ", arguments: [true, false], [true, false])
    func variants(variantA: Bool, laptop: Bool) {
        let settings = CapsaicinCore.Settings()
        let capabilities = MachineCapabilities(
            hasLid: laptop,
            hasInternalBattery: laptop,
            canBlockLidSleepAlone: variantA,
        )
        let rows = SettingsSleepRow.rows(settings: settings, capabilities: capabilities, helper: .notInstalled)
        #expect(rows.count == (laptop ? (variantA ? 5 : 4) : 3))
        #expect(rows[2].key == (!variantA && laptop ? "manualAndLid" : "manual"))
        let release = SettingsReleasePresentation(settings: settings, capabilities: capabilities)
        #expect(release.showsBattery == laptop)
        #expect(!release.timerEnabled && !release.timeEnabled && release.batteryEnabled)
    }

    @Test("SPEC-HLP-001 設置中は保存も含意も変えず、成功後だけオンにする",
          arguments: [HelperInstallationState.notInstalled, .partial])
    func installation(state: HelperInstallationState) async throws {
        let fixture = AppFixture()
        var installed = state
        var completed = false
        let model = SettingsModel(
            app: fixture.model,
            helper: SettingsHelperActions(state: { installed }, perform: { operation in
                #expect(operation == (state == .partial ? .repair : .install))
                #expect(!fixture.model.settings.blocksManualSleep)
                installed = .installed
                return .success
            }, completed: { _, _ in completed = true }),
        )
        model.confirm = { _, fromSetting in
            #expect(fromSetting && model.pendingManual && model.isBusy)
            #expect(!fixture.model.settings.blocksManualSleep)
            #expect(model.sleepRows[0].state == .editable(isOn: true))
            return true
        }
        try await model.changeSleep(#require(model.sleepRows.first { $0.key == "manual" }), to: true)
        #expect(completed && fixture.model.settings.blocksManualSleep)
        #expect(model.sleepRows[0].state == .implied([.manualSleep]))
        #expect(!model.pendingManual && !model.isBusy)
    }

    @Test("SPEC-HLP-001 確認取り消し・認証取り消し・失敗は保存しない", arguments: [0, 1, 2])
    func installationCancellation(outcome: Int) async throws {
        let fixture = AppFixture()
        var errors = 0
        var performed = false
        let model = SettingsModel(
            app: fixture.model,
            helper: SettingsHelperActions(state: { .notInstalled }, perform: { _ in
                performed = true
                return outcome == 1 ? .cancelled : .failure(
                    operation: .install,
                    details: "test",
                    needsSleepDisabledReadback: false,
                )
            }, completed: { _, _ in }),
        )
        model.confirm = { _, _ in outcome != 0 }
        model.showError = { _, _ in errors += 1 }
        try await model.changeSleep(#require(model.sleepRows.first { $0.key == "manual" }), to: true)
        #expect(!fixture.model.settings.blocksManualSleep && fixture.savedSettings.isEmpty)
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
        let fixture = AppFixture()
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

    @Test("SPEC-SET-001 前回のセクションと固定サイズ、標準タイトルバーを使う")
    func window() throws {
        _ = NSApplication.shared
        let defaults = try #require(UserDefaults(suiteName: "SettingsTests-" + UUID().uuidString))
        let selection = SettingsSelection(defaults: defaults)
        #expect(selection.section == .general)
        selection.section = .led
        #expect(SettingsSelection(defaults: defaults).section == .led)
        defaults.removeObject(forKey: "settingsSection")
        let model = makeModel()
        let controller = SettingsWindowController(
            model: model,
            hotkey: HotkeyController(save: { _ in true }),
            defaults: defaults,
        )
        let window = try #require(controller.window)
        #expect(window.frame.size == NSSize(width: 720, height: 500))
        #expect(window.styleMask.contains(.titled) && !window.styleMask.contains(.resizable))
        #expect(window.standardWindowButton(.miniaturizeButton)?.isEnabled == false)
        window.close()
    }

    @Test("SPEC-UI-005 SPEC-UI-011 全セクションをアプリ起動なしでライト・ダークに描画する")
    func render() async throws {
        _ = NSApplication.shared
        let app = try appBundle()
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/settings")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let defaults = try #require(UserDefaults(suiteName: "SettingsRender-" + UUID().uuidString))
        let selection = SettingsSelection(defaults: defaults)
        defer { defaults.removeObject(forKey: "settingsSection") }
        for section in SettingsSection.allCases {
            #expect(section.title != "title")
            selection.section = section
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let view = NSHostingView(rootView: SettingsView(
                    model: makeModel(),
                    hotkey: HotkeyController(save: { _ in true }),
                    selection: selection,
                    bundle: app,
                ).environment(\.colorScheme, name == "light" ? .light : .dark)
                    .environment(\.controlActiveState, .key))
                view.sizingOptions = []
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 472),
                                      styleMask: [.titled, .closable, .miniaturizable], backing: .buffered,
                                      defer: false)
                window.isReleasedWhenClosed = false
                window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
                window.appearance = NSAppearance(named: appearance)
                window.contentView = view
                view.layoutSubtreeIfNeeded()
                window.setFrame(NSRect(x: 0, y: 0, width: 720, height: 500), display: false)
                window.title = section.title
                await Task.yield()
                view.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
                let frame = try #require(view.superview)
                let bitmap = try #require(frame.bitmapImageRepForCachingDisplay(in: frame.bounds))
                window.appearance?.performAsCurrentDrawingAppearance {
                    frame.cacheDisplay(in: frame.bounds, to: bitmap)
                }
                let data = try #require(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: output.appendingPathComponent("\(section.rawValue)-\(name).png"))
                #expect(bitmap.pixelsWide >= 720 && bitmap.pixelsHigh >= 500)
                window.close()
            }
        }
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

    private func appBundle() throws -> Bundle {
        let product = Bundle(for: SettingsTestResources.self).bundleURL.deletingLastPathComponent()
        return try #require(Bundle(url: product.appendingPathComponent("Capsaicin.app")))
    }

    private func makeModel() -> SettingsModel {
        let system = FakeSystem()
        let app = AppModel(controller: BlockingController(settings: CapsaicinCore.Settings(),
                                                          capabilities: MachineCapabilities(
                                                              hasLid: true,
                                                              hasInternalBattery: true,
                                                              canBlockLidSleepAlone: true,
                                                          ),
                                                          ports: system.ports), saveSettings: { _ in })
        app.launchAgentStatus = .ready
        return SettingsModel(
            app: app,
            helper: SettingsHelperActions(state: { .installed }, perform: { _ in .cancelled }, completed: { _, _ in }),
        )
    }
}

private final class SettingsTestResources: NSObject {}
