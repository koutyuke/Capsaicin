import AppKit
import CapsaicinPlatform
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    let model: SettingsModel
    private let selection: SettingsSelection

    init(model: SettingsModel, hotkey: HotkeyController, defaults: UserDefaults = .standard) {
        self.model = model
        selection = SettingsSelection(defaults: defaults)
        let window = Self.makeWindow(
            rootView: SettingsView(model: model, hotkey: hotkey, selection: selection),
            selection: selection,
        )
        super.init(window: window)
        window.center()
        model.confirm = { [weak self] operation, fromSetting in
            guard let self, let window = self.window else { return false }
            let key = SettingsModel.operationKey(operation)
            var title = key + ".title"
            if fromSetting, operation == .install {
                title = self.model.sleepRows.contains { $0.key == "manualAndLid" }
                    ? "helperInstall.manualAndLid.title" : "helperInstall.setting.title"
            }
            let alert = alert(title: SettingsSection.helper.text(title),
                              message: SettingsSection.helper.text(key + ".message"))
            alert.addButton(withTitle: SettingsSection.helper.text(key + ".confirm"))
            alert.addButton(withTitle: SettingsSection.helper.text("cancel"))
            return await alert.beginSheetModal(for: window) == .alertFirstButtonReturn
        }
        model.showError = { [weak self] title, message in
            guard let self, let window = self.window else { return }
            let alert = alert(title: title, message: message)
            alert.addButton(withTitle: SettingsSection.helper.text("ok"))
            // 重なったシートは AppKit が順に表示する。
            alert.beginSheetModal(for: window)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func makeWindow(rootView: some View, selection: SettingsSelection) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let toolbar = NSToolbar()
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        let host = NSHostingView(rootView: rootView)
        host.sizingOptions = []
        window.contentView = host
        // ツールバーと内容を配置してから、枠を含む寸法を決める。
        host.layoutSubtreeIfNeeded()
        window.setFrame(NSRect(x: 0, y: 0, width: 720, height: 500), display: false)
        window.title = selection.section.title
        selection.didSelect = { [weak window] in window?.title = $0.title }
        return window
    }

    func open() {
        model.refreshHelper()
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func alert(title: String, message: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        return alert
    }
}

@MainActor
@Observable
final class SettingsSelection {
    var section: SettingsSection {
        didSet {
            defaults.set(section.rawValue, forKey: "settingsSection")
            didSelect?(section)
        }
    }

    @ObservationIgnored var didSelect: ((SettingsSection) -> Void)?
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        section = defaults.string(forKey: "settingsSection").flatMap(SettingsSection.init(rawValue:)) ?? .general
    }
}
