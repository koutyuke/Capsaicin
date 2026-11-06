import AppKit
import KeyboardShortcuts
import Observation
import SwiftUI

@MainActor
@Observable
final class HotkeyController {
    static let name = KeyboardShortcuts.Name("toggleSleepBlocking")
    private(set) var shortcut: KeyboardShortcuts.Shortcut?
    private(set) var hasError = false
    private let save: (KeyboardShortcuts.Shortcut?) -> Bool

    init(shortcut: KeyboardShortcuts.Shortcut? = nil,
         save: @escaping (KeyboardShortcuts.Shortcut?) -> Bool)
    {
        self.shortcut = shortcut
        self.save = save
    }

    static func live(toggle: @escaping @MainActor () -> Void) -> HotkeyController {
        KeyboardShortcuts.onKeyUp(for: name) { toggle() }
        return Self(shortcut: KeyboardShortcuts.getShortcut(for: name)) { candidate in
            let previous = KeyboardShortcuts.getShortcut(for: name)
            KeyboardShortcuts.setShortcut(candidate, for: name)
            guard candidate == nil || KeyboardShortcuts.isEnabled(for: name) else {
                KeyboardShortcuts.setShortcut(previous, for: name)
                return false
            }
            return true
        }
    }

    static func stop() {
        KeyboardShortcuts.removeHandler(for: name)
    }

    @discardableResult
    func assign(_ candidate: KeyboardShortcuts.Shortcut?) -> Bool {
        if let candidate, candidate.key == .capsLock ||
            candidate.modifiers.isDisjoint(with: [.command, .control, .option]) ||
            candidate.isTakenBySystem || (candidate != shortcut && Self.conflictsWithMenu(
                candidate,
                menu: NSApp?.mainMenu,
            ))
        {
            hasError = true
            return false
        }
        guard save(candidate) else {
            hasError = true
            return false
        }
        shortcut = candidate
        hasError = false
        return true
    }

    private static func conflictsWithMenu(_ shortcut: KeyboardShortcuts.Shortcut, menu: NSMenu?) -> Bool {
        menu?.items.contains { item in
            var modifiers = item.keyEquivalentModifierMask
            if item.keyEquivalent.lowercased() != item.keyEquivalent {
                modifiers.insert(.shift)
            }
            return (item.keyEquivalent.lowercased() == shortcut.nsMenuItemKeyEquivalent &&
                modifiers == shortcut.modifiers) || conflictsWithMenu(shortcut, menu: item.submenu)
        } ?? false
    }
}

struct HotkeyRecorder: NSViewRepresentable {
    let controller: HotkeyController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        let coordinator = context.coordinator
        let recorder = KeyboardShortcuts.RecorderCocoa(shortcut: controller.shortcut) { candidate in
            // 標準記録欄が記録を終え、グローバル登録を再開してから成否を確かめる。
            Task { @MainActor in
                await Task.yield()
                coordinator.controller.assign(candidate)
                coordinator.recorder?.shortcut = coordinator.controller.shortcut
            }
        }
        // ライブラリ既定の競合アラートを出さず、直前の値と行内のエラーで知らせる。
        recorder.conflictPolicy = .allowAll
        recorder.placeholderString = SettingsSection.controls.text("hotkey.placeholder")
        recorder.setAccessibilityLabel(SettingsSection.controls.text("hotkey.label"))
        coordinator.recorder = recorder
        return recorder
    }

    func updateNSView(_ recorder: KeyboardShortcuts.RecorderCocoa, context _: Context) {
        recorder.shortcut = controller.shortcut
    }

    @MainActor
    final class Coordinator {
        let controller: HotkeyController
        weak var recorder: KeyboardShortcuts.RecorderCocoa?
        init(controller: HotkeyController) {
            self.controller = controller
        }
    }
}
