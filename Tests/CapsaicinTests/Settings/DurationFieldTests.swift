import AppKit
import CapsaicinCore
import Observation
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct DurationFieldTests {
    @Test("SPEC-UI-005 時間は60分、分は5分ずつ増減して繰り上げ・繰り下げる")
    func stepsAndCarry() throws {
        var input = try DurationInput(#require(TimerDuration(minutes: 58)))
        input.step(5)
        #expect(input.hours == "1" && input.minutes == "3")
        input.step(-5)
        #expect(input.hours == "0")
        #expect(input.minutes == "58")
        input.step(60)
        #expect(input.hours == "1" && input.minutes == "58")
        input.step(-60)
        #expect(input.hours == "0")
        #expect(input.minutes == "58")
    }

    @Test("SPEC-UI-005 Stepperと矢印キーの増減は範囲の端で止まる")
    func bounds() throws {
        var input = try DurationInput(#require(TimerDuration(minutes: 23 * 60 + 30)))
        input.step(60)
        #expect(input.hours == "24" && input.minutes == "0")
        input.step(60)
        input.step(5)
        #expect(input.value?.minutes == 1440)
        input = try DurationInput(#require(TimerDuration(minutes: 3)))
        input.step(-5)
        #expect(input.hours == "0" && input.minutes == "1")
        input.step(-60)
        input.step(-5)
        #expect(input.value?.minutes == 1)
    }

    @Test("SPEC-UI-005 数値欄は1分単位で入力でき、不正な入力を別の値に直さない",
          arguments: [("0", "0"), ("24", "1"), ("1", "60"), ("-1", "1"), ("abc", "0"), ("", "1"),
                      ("9999999999999999999999999", "0")])
    func invalidInput(pair: (String, String)) throws {
        var input = try DurationInput(#require(TimerDuration(minutes: 61)))
        input.hours = pair.0
        input.minutes = pair.1
        #expect(input.value == nil)
        input.step(5)
        #expect(input.hours == pair.0 && input.minutes == pair.1)
        input.hours = "1"
        input.minutes = "17"
        #expect(input.value?.minutes == 77)
    }

    @Test("SPEC-UI-005 SPEC-UI-007 標準の数値欄とStepperを各2個使い、フォーカス中の矢印で増減する")
    func nativeControlsAndKeys() async throws {
        let draft = DurationDraft()
        @Bindable var state = draft
        let window = host(DurationField(input: $state.input))
        defer { window.close() }
        await layout(window)
        let content = try #require(window.contentView)
        let fields = descendants(NSTextField.self, in: content).filter(\.isEditable)
        #expect(fields.count == 2)
        #expect(descendants(NSStepper.self, in: content).count == 2)
        let hours = try #require(fields.first)
        let minutes = try #require(fields.last)
        #expect(window.makeFirstResponder(minutes))
        window.sendEvent(arrow(increasing: true, window: window))
        await layout(window)
        #expect(draft.input.hours == "1" && draft.input.minutes == "3")
        window.sendEvent(arrow(increasing: false, window: window))
        await layout(window)
        #expect(draft.input.hours == "0")
        #expect(draft.input.minutes == "58")
        #expect(window.makeFirstResponder(hours))
        window.sendEvent(arrow(increasing: true, window: window))
        await layout(window)
        #expect(draft.input.hours == "1" && draft.input.minutes == "58")
        window.sendEvent(arrow(increasing: false, window: window))
        await layout(window)
        #expect(draft.input.hours == "0")
        #expect(draft.input.minutes == "58")
    }

    @Test("SPEC-UI-005 SPEC-SET-002 設定の入力欄は不正な文字列を保ち、最後の有効な保存値を変えない")
    func settingsInvalidDraft() async throws {
        var saved = try #require(TimerDuration(minutes: 60))
        var writes: [TimerDuration] = []
        let window = host(SettingsDurationField(value: Binding(get: { saved }, set: { saved = $0; writes.append($0) })))
        defer { window.close() }
        await layout(window)
        let content = try #require(window.contentView)
        let hours = try #require(descendants(NSTextField.self, in: content).first { $0.isEditable })
        #expect(window.makeFirstResponder(hours))
        let editor = try #require(hours.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText("abc", replacementRange: editor.selectedRange())
        await layout(window)
        #expect(saved.minutes == 60 && writes.isEmpty)
        #expect(editor.string == "abc")
        editor.selectAll(nil)
        editor.insertText("2", replacementRange: editor.selectedRange())
        await layout(window)
        #expect(saved.minutes == 120 && writes.map(\.minutes) == [120])
    }

    private func host(_ view: some View) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        window.contentView = host
        return window
    }

    private func layout(_ window: NSWindow) async {
        for _ in 0 ..< 3 {
            window.contentView?.layoutSubtreeIfNeeded()
            await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        }
    }

    private func descendants<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(type, in: $0) }
    }

    private func arrow(increasing: Bool, window: NSWindow) -> NSEvent {
        let character = String(UnicodeScalar(increasing ? NSUpArrowFunctionKey : NSDownArrowFunctionKey)!)
        return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                windowNumber: window.windowNumber, context: nil, characters: character,
                                charactersIgnoringModifiers: character, isARepeat: false,
                                keyCode: increasing ? 126 : 125)!
    }
}

@MainActor
@Observable
private final class DurationDraft {
    var input = DurationInput(TimerDuration(minutes: 58)!)
}
