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
                let view = try #require(window.contentView)
                await layout(window)
                try saveRendering(window, to: output.appendingPathComponent("\(section.rawValue)-\(name).png"))
                #expect(window.frame.size == NSSize(width: 720, height: 500))
                #expect(window.title == section.title)
                try checkToolbarTitle(window)
                // 見出しのあるセクション（解除の条件、操作）は、見出しが先に来るので除く。
                if [.general, .sleep, .led, .helper].contains(section) {
                    try checkFormTop(window)
                }
                #expect(try checkSidebarBottom(window).accessibilityPerformPress?() == true)
                if section == .general, name == "light" {
                    try await checkSidebar(window, selection: selection)
                }
                if section == .release {
                    for scroll in descendants(NSScrollView.self, in: view) where scroll.frame.width > 200 {
                        let document = try #require(scroll.documentView)
                        #expect(document.bounds.height + scroll.contentInsets.top + scroll.contentInsets.bottom
                            <= scroll.contentSize.height + 1)
                    }
                }
            }
        }
        #expect(quits == SettingsSection.allCases.count * 2)
    }

    @Test("SPEC-SET-001 空き行は終了ボタンを除く領域と実測した7行の高さに追従し、小さい領域ではゼロにする")
    func sidebarSpacing() {
        let rows = SidebarRows()
        let table = NSTableView(frame: NSRect(x: 0, y: 0, width: 200, height: 500))
        table.dataSource = rows
        table.intercellSpacing = .zero
        table.reloadData()
        let scroll = NSScrollView(frame: table.frame)
        scroll.documentView = table
        let spacer = SettingsSidebarSpacer.SpacerView()
        table.addSubview(spacer)
        spacer.availableHeight = 390
        for height: CGFloat in [24, 32, 40] {
            table.rowHeight = height
            spacer.updateHeight()
            #expect(spacer.intrinsicContentSize.height == 390 - 7 * height)
        }
        spacer.availableHeight = 100
        spacer.updateHeight()
        #expect(spacer.intrinsicContentSize.height == 0)
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

private extension SettingsTests {
    private func saveRendering(_ window: NSWindow, to url: URL) throws {
        let frame = try #require(window.contentView?.superview)
        let bitmap = try #require(frame.bitmapImageRepForCachingDisplay(in: frame.bounds))
        window.appearance?.performAsCurrentDrawingAppearance {
            frame.cacheDisplay(in: frame.bounds, to: bitmap)
        }
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url)
        #expect(bitmap.pixelsWide >= 720 && bitmap.pixelsHigh >= 500)
    }

    private func checkSidebar(_ window: NSWindow, selection: SettingsSelection) async throws {
        let content = try #require(window.contentView)
        let lists = descendants(NSOutlineView.self, in: content)
        #expect(lists.count == 1)
        let list = try #require(lists.first)
        #expect(list.numberOfRows == SettingsSection.allCases.count + 1)
        #expect(list.bounds.width == 200)
        try checkSidebarBottom(window)
        #expect(list.rect(ofRow: 5).height > list.rect(ofRow: 0).height)
        #expect(window.makeFirstResponder(list))
        for section in SettingsSection.allCases.dropFirst() {
            list.keyDown(with: arrow(NSDownArrowFunctionKey, keyCode: 125, window: window))
            await layout(window)
            #expect(selection.section == section)
            #expect(window.title == section.title)
            try checkToolbarTitle(window)
        }
        for section in SettingsSection.allCases.reversed().dropFirst() {
            list.keyDown(with: arrow(NSUpArrowFunctionKey, keyCode: 126, window: window))
            await layout(window)
            #expect(selection.section == section)
            #expect(window.title == section.title)
            try checkToolbarTitle(window)
        }
        #expect(window.toolbar?.items.isEmpty == true)
        #expect(content.bounds.size == NSSize(width: 720, height: 500))
        let originalFrame = window.frame
        window.setFrame(NSRect(origin: originalFrame.origin, size: NSSize(width: 720, height: 560)), display: false)
        await layout(window)
        try checkSidebarBottom(window)
        window.setFrame(originalFrame, display: false)
        await layout(window)
        try checkSidebarBottom(window)
    }

    private func accessibilityDescendants(_ element: AnyObject) -> [AnyObject] {
        [element] + (element.accessibilityChildren?() as? [AnyObject] ?? [])
            .flatMap { accessibilityDescendants($0) }
    }

    /// 最後の行とボタンの間、ボタンと下端の間をどちらも 10 pt にし、ボタンをサイドバーの中央に置く。
    @discardableResult
    private func checkSidebarBottom(_ window: NSWindow) throws -> AnyObject {
        let content = try #require(window.contentView)
        let list = try #require(descendants(NSOutlineView.self, in: content).first)
        let title = try MenuContent.text("menu.quit", bundle: appBundle())
        #expect(title != "menu.quit")
        let quit = try #require(accessibilityDescendants(content).first {
            $0.accessibilityRole?() == .button && $0.accessibilityLabel?() == title
        })
        let row = window.convertToScreen(list.convert(list.rect(ofRow: list.numberOfRows - 1), to: nil))
        let frame = try #require(quit.accessibilityFrame?())
        #expect(abs(row.minY - frame.maxY - 10) <= 1)
        let local = window.convertFromScreen(frame)
        #expect(abs(local.midX - 100) <= 1 && abs(local.minY - 10) <= 1)
        return quit
    }

    private func checkToolbarTitle(_ window: NSWindow) throws {
        let frame = try #require(window.contentView?.superview)
        let close = try #require(window.standardWindowButton(.closeButton))
        let title = try #require(descendants(NSTextField.self, in: frame).first { $0.stringValue == window.title })
        let closeFrame = close.convert(close.bounds, to: frame)
        let titleFrame = title.convert(title.bounds, to: frame)
        #expect(abs(closeFrame.midY - titleFrame.midY) <= 1)
        #expect(titleFrame.minX > 200)
        #expect(title.font?.pointSize == 15)
        #expect(abs(frame.bounds.maxY - closeFrame.midY - 26) <= 1)
    }

    private func checkFormTop(_ window: NSWindow) throws {
        let content = try #require(window.contentView)
        let scroll = try #require(descendants(NSScrollView.self, in: content).first { $0.frame.width > 200 })
        func frames(_ view: NSView) -> [NSRect] {
            [view.convert(view.bounds, to: nil)] + view.subviews.flatMap(frames)
        }
        let document = try #require(scroll.documentView)
        let groupTop = try #require(frames(document).filter { abs($0.minX - 220) <= 1 }.map(\.maxY).max())
        #expect(abs(window.contentLayoutRect.maxY - groupTop - 12) <= 1)
    }

    private func appBundle() throws -> Bundle {
        let product = Bundle(for: SettingsTestResources.self).bundleURL.deletingLastPathComponent()
        return try #require(Bundle(url: product.appendingPathComponent("Capsaicin.app")))
    }

    private func layout(_ window: NSWindow) async {
        for _ in 0 ..< 3 {
            window.contentView?.layoutSubtreeIfNeeded()
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        window.display()
    }

    private func descendants<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(type, in: $0) }
    }

    private func arrow(_ code: Int, keyCode: UInt16, window: NSWindow) -> NSEvent {
        let character = String(UnicodeScalar(code)!)
        return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                windowNumber: window.windowNumber, context: nil, characters: String(character),
                                charactersIgnoringModifiers: String(character), isARepeat: false, keyCode: keyCode)!
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

private final class SidebarRows: NSObject, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        SettingsSection.allCases.count + 1
    }
}
