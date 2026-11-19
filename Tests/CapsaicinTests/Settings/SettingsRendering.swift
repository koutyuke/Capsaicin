import AppKit
import CapsaicinPlatform
import SwiftUI
import Testing

@MainActor
private protocol SettingsRowContents {
    var rowContents: Any { get }
}

extension SettingsRow: SettingsRowContents {
    fileprivate var rowContents: Any {
        content()
    }
}

extension SettingsTests {
    @Test("SPEC-HLP-004 ヘルパーの4状態で2行を保ち、状態と管理の操作を出し分ける",
          arguments: [HelperInstallationState.notInstalled, .requiresApproval, .installed, .unavailable])
    func helperRows(state: HelperInstallationState) throws {
        let fixture = AppFixture()
        let model = SettingsModel(app: fixture.model, helper: .init(state: { state }, perform: { _ in .cancelled },
                                                                    completed: { _, _ in }))
        let defaults = try #require(UserDefaults(suiteName: "HelperRows-" + UUID().uuidString))
        let view = SettingsView(model: model, hotkey: HotkeyController(save: { _ in true }),
                                selection: SettingsSelection(defaults: defaults), quit: {}).helper
        #expect(rowHelpValues(view) == [SettingsSection.helper.text("status.help"), ""])
        func strings(_ value: Any) -> [String] {
            if let text = value as? String {
                return [text]
            }
            if let row = value as? any SettingsRowContents {
                return strings(row.rowContents)
            }
            return Mirror(reflecting: value).children.flatMap { strings($0.value) }
        }
        let values = strings(view)
        let key = switch state {
        case .notInstalled: "status.notInstalled"
        case .requiresApproval: "status.requiresApproval"
        case .installed: "status.usable"
        case .unavailable: "status.unavailable"
        }
        #expect(values.contains(SettingsSection.helper.text(key)))
        #expect(values.contains(SettingsSection.helper.text("helperInstall.button")) == (state == .notInstalled))
        #expect(values
            .contains(SettingsSection.helper.text("openSystemSettings.button")) == (state == .requiresApproval))
        #expect(values.contains(SettingsSection.helper.text("helperRemove.button"))
            == (state == .requiresApproval || state == .installed))
    }

    @Test("SPEC-SET-002 SPEC-SET-006 バッテリーは独立した見出しを持ち、内蔵バッテリーがなければグループごと出さない",
          arguments: [false, true], [false, true])
    func batteryGroup(hasBattery: Bool, enabled: Bool) throws {
        let defaults = try #require(UserDefaults(suiteName: "SettingsBattery-" + UUID().uuidString))
        let view = SettingsView(
            model: makeModel(hasBattery: hasBattery, conditionsEnabled: enabled),
            hotkey: HotkeyController(save: { _ in true }), selection: SettingsSelection(defaults: defaults), quit: {},
        )
        // 説明文の検査と同じく、Form に渡す値を調べる。プロセス内では仮想 AX ノードを列挙できない。
        func strings(_ value: Any) -> [String] {
            if let text = value as? String {
                return [text]
            }
            return Mirror(reflecting: value).children.flatMap { strings($0.value) }
        }
        let values = strings(view.release)
        #expect(values.contains(SettingsSection.sleep.text("battery.group.title")) == hasBattery)
        #expect(values.contains(SettingsSection.sleep.text("battery.label")) == hasBattery)
        #expect(values.contains(SettingsSection.sleep.text("battery.threshold.label")) == hasBattery)
        #expect(values.contains(SettingsSection.sleep.text("battery.ignoreOnAdapter.label")) == hasBattery)
        #expect(rowHelpValues(view.release).count == (hasBattery ? 7 : 4))
    }

    @Test("SPEC-UI-004 LED の独自シンボルをコードのバンドルから読み込める",
          arguments: ["custom.capsaicin.led", "custom.capsaicin.led.fill"])
    func customSymbols(name: String) throws {
        let bundle = Bundle(for: SettingsWindowController.self)
        let image = try #require(NSImage(symbolName: name, bundle: bundle, variableValue: 0))
        #expect(image.size.width > 0 && image.size.height > 0)
        #expect(SettingsSection.feedback.symbol == "custom.capsaicin.led")
        #expect(Image(symbol: name, bundle: bundle) == Image(name, bundle: bundle))
        let rendered = try #require(ImageRenderer(content: Image(symbol: name, bundle: bundle).font(.body)).cgImage)
        #expect(rendered.width > 0 && rendered.height > 0)
    }

    @Test("SPEC-UI-004 設定と HUD の標準シンボルは SF Symbols として読み込む",
          arguments: ["gearshape", "xmark.octagon.fill", "exclamationmark.triangle.fill"])
    func systemSymbols(name: String) throws {
        let image = Image(symbol: name, bundle: Bundle(for: SettingsWindowController.self))
        #expect(image == Image(systemName: name))
        let rendered = try #require(ImageRenderer(content: image.font(.title3)).cgImage)
        #expect(rendered.width > 0 && rendered.height > 0)
    }

    @Test("SPEC-SET-005 SPEC-UI-005 説明文は項目名で足りない行だけに置き、親がオフでも増やさない",
          arguments: [false, true], [false, true])
    func sleepInfoButtons(hasLid: Bool, conditionsEnabled: Bool) throws {
        let defaults = try #require(UserDefaults(suiteName: "SettingsInfo-" + UUID().uuidString))
        let selection = SettingsSelection(defaults: defaults)
        selection.section = .sleep
        defer { defaults.removeObject(forKey: "settingsSection") }
        let model = makeModel(hasLid: hasLid, conditionsEnabled: conditionsEnabled)
        let view = SettingsView(
            model: model,
            hotkey: HotkeyController(save: { _ in true }), selection: selection, quit: {},
        )
        #expect(model.sleepRows.filter { !$0.help.isEmpty }.map(\.key) == (hasLid ? ["display"] : [
            "display",
            "manual",
        ]))
        // Form の仮想アクセシビリティノードはプロセス内テストでは列挙できないため、描画に渡す行を調べる。
        let help = rowHelpValues(view.release)
        #expect(help.count == 7)
        #expect(help.filter { !$0.isEmpty } == [SettingsSection.sleep.text("time.help")])
    }

    @Test("SPEC-SET-001 空き行は表の行と余白を含めて見える高さちょうどに広がり、小さい領域ではゼロにする")
    func sidebarSpacing() {
        let rows = SidebarRows()
        let table = NSTableView(frame: NSRect(x: 0, y: 0, width: 200, height: 390))
        table.dataSource = rows
        table.delegate = rows
        table.intercellSpacing = .zero
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 390))
        scroll.documentView = table
        table.reloadData()
        let spacer = SettingsSidebarSpacer.SpacerView()
        table.addSubview(spacer)
        // アプリでは空き行の高さが行の高さになり、表が並べ直されてからもう一度計算する。その繰り返しをまねる。
        func settle(available: CGFloat) {
            spacer.availableHeight = available
            for _ in 0 ..< 4 {
                spacer.updateHeight()
                rows.spacer = spacer.intrinsicContentSize.height
                table.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< table.numberOfRows))
                table.tile()
            }
        }
        for height: CGFloat in [24, 32, 40] {
            rows.height = height
            settle(available: 390)
            #expect(abs(table.frame.height - 390) <= 0.5)
            #expect(rows.spacer > 390 - 7 * height)
            // 最後の行の下には既定の余白を残す。
            #expect(table.rect(ofRow: table.numberOfRows - 1).maxY < 390)
        }
        settle(available: 100)
        #expect(spacer.intrinsicContentSize.height == 0)
    }

    func checkRendering(_ window: NSWindow, section: SettingsSection, app: Bundle) throws {
        let view = try #require(window.contentView)
        #expect(window.frame.size == NSSize(width: 720, height: 500))
        #expect(window.title == section.title)
        try checkToolbarTitle(window)
        // 見出しのあるセクション（スリープ、フィードバック、操作）は、見出しが先に来るので除く。
        if [.general, .helper].contains(section) {
            try checkFormTop(window)
        }
        try checkSidebarBottom(window)
        let title = MenuContent.text("menu.quit", bundle: app)
        #expect(title != "menu.quit")
        let quit = accessibilityDescendants(view).first {
            $0.accessibilityRole?() == .button && $0.accessibilityLabel?() == title
        }
        if section != .about {
            #expect(quit == nil)
        }
        if section == .general {
            for scroll in descendants(NSScrollView.self, in: view) where scroll.frame.width > 200 {
                let document = try #require(scroll.documentView)
                #expect(document.bounds.height + scroll.contentInsets.top + scroll.contentInsets.bottom
                    <= scroll.contentSize.height + 1)
            }
        }
    }

    @Test("SPEC-SET-004 フッターの終了ボタンはメニューと同じ文言と終了処理を使う")
    func aboutQuit() async throws {
        _ = NSApplication.shared
        let app = try appBundle()
        let defaults = try #require(UserDefaults(suiteName: "AboutQuit-" + UUID().uuidString))
        let selection = SettingsSelection(defaults: defaults)
        var quits = 0
        // Form の仮想 AX ノードはプロセス内では列挙できないため、同じフッターを単独で描画する。
        let footer = SettingsAboutContent(updater: UpdateModel(), quit: { quits += 1 }, bundle: app).footer
        let window = SettingsWindowController.makeWindow(rootView: footer.environment(\.accessibilityEnabled, true),
                                                         selection: selection)
        defer { window.close() }
        await layout(window)
        let view = try #require(window.contentView)
        let button = try #require(accessibilityDescendants(view).first {
            $0.accessibilityRole?() == .button && $0.accessibilityLabel?() == MenuContent.text("menu.quit", bundle: app)
        })
        #expect(button.accessibilityPerformPress?() == true)
        #expect(quits == 1)
    }

    func saveRendering(_ window: NSWindow, to url: URL) throws {
        let frame = try #require(window.contentView?.superview)
        let bitmap = try #require(frame.bitmapImageRepForCachingDisplay(in: frame.bounds))
        window.appearance?.performAsCurrentDrawingAppearance {
            frame.cacheDisplay(in: frame.bounds, to: bitmap)
        }
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url)
        #expect(bitmap.pixelsWide >= 720 && bitmap.pixelsHigh >= 500)
    }

    func saveBottom(_ window: NSWindow, to url: URL) async throws {
        let view = try #require(window.contentView)
        let scroll = try #require(descendants(NSScrollView.self, in: view).first { $0.frame.width > 200 })
        let document = try #require(scroll.documentView)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: document.bounds.maxY - scroll.contentSize.height))
        scroll.reflectScrolledClipView(scroll.contentView)
        await layout(window)
        try saveRendering(window, to: url)
    }

    func checkSidebar(_ window: NSWindow, selection: SettingsSelection) async throws {
        let content = try #require(window.contentView)
        let lists = descendants(NSOutlineView.self, in: content)
        #expect(lists.count == 1)
        let list = try #require(lists.first)
        #expect(list.numberOfRows == SettingsSection.allCases.count + 1)
        #expect(list.bounds.width == 200)
        try checkSidebarBottom(window)
        #expect(list.rect(ofRow: 4).height > list.rect(ofRow: 0).height)
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

    func appBundle() throws -> Bundle {
        let product = Bundle(for: SettingsTestResources.self).bundleURL.deletingLastPathComponent()
        return try #require(Bundle(url: product.appendingPathComponent("Capsaicin.app")))
    }

    func layout(_ window: NSWindow) async {
        for _ in 0 ..< 3 {
            window.contentView?.layoutSubtreeIfNeeded()
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        window.display()
    }

    func accessibilityDescendants(_ element: AnyObject) -> [AnyObject] {
        [element] + (element.accessibilityChildren?() as? [AnyObject] ?? [])
            .flatMap { accessibilityDescendants($0) }
    }

    private func rowHelpValues(_ view: Any) -> [String] {
        let mirror = Mirror(reflecting: view)
        if String(describing: type(of: view)).hasPrefix("SettingsRow<") {
            return mirror.children.compactMap { $0.label == "help" ? $0.value as? String : nil }
        }
        return mirror.children.flatMap { rowHelpValues($0.value) }
    }

    /// 最後の2行をスクロール領域の下端に寄せ、システム既定の下余白は残す。内容は見える高さちょうどで、スクロールしない。
    private func checkSidebarBottom(_ window: NSWindow) throws {
        let content = try #require(window.contentView)
        let list = try #require(descendants(NSOutlineView.self, in: content).first)
        let scroll = try #require(list.enclosingScrollView)
        #expect(abs(scroll.convert(scroll.bounds, to: content).minY - content.bounds.minY) <= 1)
        let helper = list.rect(ofRow: list.numberOfRows - 2)
        let about = list.rect(ofRow: list.numberOfRows - 1)
        #expect(abs(helper.maxY - about.minY) <= 1)
        let visibleHeight = scroll.documentVisibleRect.height - scroll.contentInsets.top - scroll.contentInsets.bottom
        let document = try #require(scroll.documentView)
        #expect(abs(document.frame.height - visibleHeight) <= 0.5)
        #expect(about.maxY < document.frame.height)
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

    private func descendants<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(type, in: $0) }
    }

    private func arrow(_ code: Int, keyCode: UInt16, window: NSWindow) -> NSEvent {
        let character = String(UnicodeScalar(code)!)
        return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                windowNumber: window.windowNumber, context: nil, characters: String(character),
                                charactersIgnoringModifiers: String(character), isARepeat: false, keyCode: keyCode)!
    }
}

private final class SettingsTestResources: NSObject {}

private final class SidebarRows: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var height: CGFloat = 24
    var spacer: CGFloat = 0

    func numberOfRows(in _: NSTableView) -> Int {
        SettingsSection.allCases.count + 1
    }

    func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        row == 4 ? max(spacer, 1) : height
    }
}
