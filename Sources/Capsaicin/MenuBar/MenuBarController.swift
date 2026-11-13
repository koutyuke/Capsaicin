import AppKit
import CapsaicinCore
import KeyboardShortcuts

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let settings: SettingsModel
    private let isOnACPower: () -> Bool
    var openSettings: () -> Void = {}
    var quit: () -> Void = {}
    var configureShortcut: (NSMenuItem) -> Void = { $0.setShortcut(for: HotkeyController.name) }
    var makeInputPanel: (StartPanelInput.Mode, AppModel) -> NSPanel = { StartPanel.make(mode: $0, model: $1) }
    private(set) var statusItem: NSStatusItem?
    let menu = NSMenu()
    private(set) var inputPanel: NSPanel?
    private var panelWasBlocking = false
    private var commands: [String: MenuCommand] = [:]
    private var restoresHotkey = false

    init(settings: SettingsModel, isOnACPower: @escaping () -> Bool) {
        self.settings = settings
        model = settings.app
        self.isOnACPower = isOnACPower
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
    }

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = model.settings.showsMenuBarIcon
        item.menu = menu
        statusItem = item
        refresh()
    }

    func stop() {
        inputPanel?.close()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    func menuWillOpen(_: NSMenu) {
        // メニューとグローバル登録による二重の切り替えを避ける。
        restoresHotkey = KeyboardShortcuts.isEnabled(for: HotkeyController.name)
        if restoresHotkey {
            KeyboardShortcuts.disable(HotkeyController.name)
        }
        settings.refreshHelper()
        refresh()
    }

    func menuDidClose(_: NSMenu) {
        if restoresHotkey {
            KeyboardShortcuts.enable(HotkeyController.name)
        }
        restoresHotkey = false
    }

    func refresh() {
        statusItem?.isVisible = model.settings.showsMenuBarIcon
        let symbol = model.status.isBlocking ? "custom.capsaicin.led.fill" : "custom.capsaicin.led"
        // シンボルは設定画面の文字に合わせて描いてあり、既定の 13 pt ではメニューバーで小さく見えるため、ここだけ大きくする。
        let image = NSImage(symbolName: symbol, bundle: Bundle(for: Self.self), variableValue: 0)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular))
        image?.isTemplate = true
        // 置き換えの動きは付けない。ほかのディスプレイのメニューバーに前の状態が残るため（DEC-MENU-003）。
        statusItem?.button?.image = image
        statusItem?.button?.setAccessibilityLabel(MenuContent.text(model.status.isBlocking
                ? "statusItem.active.a11y" : "statusItem.idle.a11y"))
        if model.status.isBlocking != panelWasBlocking {
            inputPanel?.close()
            inputPanel = nil
        }
        let rows = MenuContent.make(status: model.status, settings: model.settings,
                                    isOnACPower: isOnACPower(),
                                    hasInternalBattery: model.capabilities.hasInternalBattery,
                                    sleepRows: settings.sleepRows)
        update(menu, rows: rows)
    }

    private func update(_ menu: NSMenu, rows: [MenuEntry]) {
        // 同じ構成なら項目を残し、選択中の行を動かさずに時刻と電源の表示を更新する。
        if menu.items.map({ $0.identifier?.rawValue }) != rows.map({ Optional($0.id) }) {
            menu.removeAllItems()
            for row in rows {
                let item = row.id.hasPrefix("separator.") ? NSMenuItem.separator() :
                    (row.id.hasPrefix("menu.header.") ? NSMenuItem.sectionHeader(title: row.title) : NSMenuItem())
                item.identifier = NSUserInterfaceItemIdentifier(row.id)
                menu.addItem(item)
            }
        }
        for (item, row) in zip(menu.items, rows) where !item.isSeparatorItem {
            item.title = row.title
            item.subtitle = row.subtitle
            item.isEnabled = row.command != nil || !row.children.isEmpty
            item.target = self
            item.action = row.command == nil ? nil : #selector(performCommand(_:))
            item.state = row.isChecked ? .on : .off
            commands[row.id] = row.command
            item.image = nil
            item.setAccessibilityLabel(nil)
            if row.isWarning {
                item.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?
                    .withSymbolConfiguration(.init(paletteColors: [.systemOrange]))
                item.setAccessibilityLabel(String(format: MenuContent.text("menu.warning.a11y"), row.title))
            }
            if row.id == "menu.status.until" || row.id == "menu.status.battery" {
                let font = NSFont.preferredFont(forTextStyle: .body)
                let descriptor = font.fontDescriptor.addingAttributes([.featureSettings: [[
                    NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                    NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
                ]]])
                item.attributedTitle = NSAttributedString(string: row.title, attributes: [
                    .font: NSFont(descriptor: descriptor, size: 0) ?? font,
                ])
            }
            if row.id == "menu.start" || row.id == "menu.stop" {
                item.keyEquivalent = ""
                item.keyEquivalentModifierMask = []
                configureShortcut(item)
            }
            if row.command == .settings || row.command == .quit {
                item.keyEquivalent = row.command == .settings ? "," : "q"
                item.keyEquivalentModifierMask = .command
            }
            if !row.children.isEmpty {
                let submenu = item.submenu ?? NSMenu()
                submenu.autoenablesItems = false
                item.submenu = submenu
                update(submenu, rows: row.children)
            }
        }
    }

    @objc private func performCommand(_ sender: NSMenuItem) {
        guard let id = sender.identifier?.rawValue, let command = commands[id] else { return }
        switch command {
        case let .start(value): model.requestStart(from: .menu, override: value)
        case .stop: model.requestStop(from: .menu)
        case .durationPanel, .timePanel:
            inputPanel?.close()
            panelWasBlocking = model.status.isBlocking
            inputPanel = makeInputPanel(command == .durationPanel ? .duration : .time, model)
        case let .toggleSleep(key):
            guard let row = settings.sleepRows.first(where: { $0.key == key }) else { return }
            Task { await settings.changeSleep(row, to: !row.isOn); refresh() }
        case let .lidClose(choice):
            Task { await settings.changeLidClose(to: choice); refresh() }
        case .toggleBattery:
            settings.change(\.batteryConditionEnabled, to: !model.settings.batteryConditionEnabled)
            refresh()
        case .settings: openSettings()
        case .quit: quit()
        }
    }
}
