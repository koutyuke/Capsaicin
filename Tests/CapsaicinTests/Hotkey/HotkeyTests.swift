import AppKit
import KeyboardShortcuts
import Testing

@MainActor
@Suite(.serialized)
struct HotkeyTests {
    @Test("SPEC-KEY-002 登録失敗は直前の値を保ち、消去でエラーを消す")
    func assignment() {
        let previous = KeyboardShortcuts.Shortcut(.c, modifiers: [.control, .option, .command])
        var saved = previous as KeyboardShortcuts.Shortcut?
        let controller = HotkeyController(shortcut: previous) { candidate in
            guard candidate == nil || candidate == previous else { return false }
            saved = candidate
            return true
        }
        #expect(!controller.assign(KeyboardShortcuts.Shortcut(.d, modifiers: [.control, .option, .command])))
        #expect(controller.hasError && controller.shortcut == previous && saved == previous)
        #expect(controller.assign(nil))
        #expect(!controller.hasError && controller.shortcut == nil && saved == nil)
    }

    @Test("SPEC-KEY-002 DEC-KEY-001 修飾キーなしとCaps Lockは保存しない")
    func invalidKeys() {
        let controller = HotkeyController { _ in Issue.record("不正なキーを保存しない"); return true }
        for shortcut in [KeyboardShortcuts.Shortcut(.c), KeyboardShortcuts.Shortcut(.c, modifiers: [.shift]),
                         KeyboardShortcuts.Shortcut(.capsLock, modifiers: [.command])]
        {
            #expect(!controller.assign(shortcut))
        }
        #expect(controller.shortcut == nil && controller.hasError)
    }

    @Test("SPEC-KEY-002 メニューとの重複を行内のエラーにし、同じ割り当ての再記録は許す")
    func menuConflict() {
        _ = NSApplication.shared
        let previous = NSApp.mainMenu
        defer { NSApp.mainMenu = previous }
        let menu = NSMenu()
        let item = NSMenuItem(title: "Test", action: nil, keyEquivalent: "C")
        item.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(item)
        NSApp.mainMenu = menu
        let shortcut = KeyboardShortcuts.Shortcut(.c, modifiers: [.shift, .control, .option, .command])
        let controller = HotkeyController { _ in true }
        #expect(!controller.assign(shortcut))
        #expect(controller.hasError && controller.shortcut == nil)
        let existing = HotkeyController(shortcut: shortcut) { _ in true }
        #expect(existing.assign(shortcut))
    }
}
